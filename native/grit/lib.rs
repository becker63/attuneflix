use std::{
    collections::{BTreeMap, HashMap},
    panic::{AssertUnwindSafe, catch_unwind},
    ptr, slice,
    sync::{LazyLock, Mutex, MutexGuard},
};

use marzano_core::{
    api::MatchResult,
    pattern_compiler::{CompilationResult, src_to_problem_libs},
    problem::Problem,
};
use marzano_language::target_language::{PatternLanguage, TargetLanguage};
use marzano_util::{rich_path::RichFile, runtime::ExecutionContext};
use serde::Serialize;

const ABI_OK: i32 = 0;
const ABI_HOST_ERROR: i32 = 1;

type ProgramKey = (String, Vec<u8>);

static PROBLEMS: LazyLock<Mutex<HashMap<ProgramKey, Problem>>> =
    LazyLock::new(|| Mutex::new(HashMap::new()));

#[cfg(test)]
static COMPILE_COUNTS: LazyLock<Mutex<HashMap<ProgramKey, usize>>> =
    LazyLock::new(|| Mutex::new(HashMap::new()));

fn lock<T>(mutex: &Mutex<T>) -> MutexGuard<'_, T> {
    mutex
        .lock()
        .unwrap_or_else(|poisoned| poisoned.into_inner())
}

#[cfg(test)]
fn record_compile(key: &ProgramKey) {
    *lock(&COMPILE_COUNTS).entry(key.clone()).or_insert(0) += 1;
}

#[cfg(not(test))]
fn record_compile(_key: &ProgramKey) {}

#[derive(Serialize)]
struct Span {
    path: String,
    start_byte: usize,
    end_byte: usize,
}

#[derive(Serialize)]
struct Log {
    message: String,
    start_byte: usize,
    end_byte: usize,
}

#[derive(Serialize)]
struct Evaluation {
    version: u8,
    matched: bool,
    matches: Vec<Span>,
    logs: Vec<Log>,
    diagnostics: Vec<String>,
}

#[derive(Serialize)]
struct Failure<'a> {
    version: u8,
    error: Error<'a>,
}

#[derive(Serialize)]
struct Error<'a> {
    kind: &'a str,
    message: String,
}

fn failure(kind: &'static str, message: impl Into<String>) -> Vec<u8> {
    serde_json::to_vec(&Failure {
        version: 1,
        error: Error {
            kind,
            message: message.into(),
        },
    })
    .unwrap_or_else(|_| {
        br#"{"version":1,"error":{"kind":"host","message":"JSON encoding failed"}}"#.to_vec()
    })
}

fn text(bytes: &[u8], name: &str) -> Result<String, Vec<u8>> {
    String::from_utf8(bytes.to_vec())
        .map_err(|error| failure("host", format!("{name} is not UTF-8: {error}")))
}

fn target(language: &str) -> Result<TargetLanguage, Vec<u8>> {
    let pattern = match language {
        "typescript" => PatternLanguage::TypeScript,
        // The frozen Python/PyO3 oracle selected JSX grammar in the Grit
        // source while retaining Marzano's TypeScript target language.
        // Preserve that observable contract exactly.
        "tsx" => PatternLanguage::TypeScript,
        _ => return Err(failure("unsupported-language", language)),
    };
    TargetLanguage::try_from(pattern).map_err(|error| failure("host", error.to_string()))
}

fn compile(language: &str, program: &[u8]) -> Result<Problem, Vec<u8>> {
    let source = text(program, "program")?;
    let source = if language == "tsx" {
        source.replacen("language js(typescript)", "language js(jsx)", 1)
    } else {
        source
    };
    let language = target(language)?;
    match src_to_problem_libs(source, &BTreeMap::new(), language, None, None, None, None) {
        Ok(CompilationResult { problem, .. }) => Ok(problem),
        Err(error) => Err(failure("compile", error.to_string())),
    }
}

fn execute(problem: &Problem, path: String, source: String) -> Vec<u8> {
    let context = ExecutionContext::default();
    let inputs = vec![RichFile::new(path, source)];
    let mut evaluation = Evaluation {
        version: 1,
        matched: false,
        matches: Vec::new(),
        logs: Vec::new(),
        diagnostics: Vec::new(),
    };

    for result in problem.execute_files(inputs, &context) {
        match result {
            MatchResult::Match(item) => {
                evaluation.matched = true;
                for range in item.ranges {
                    evaluation.matches.push(Span {
                        path: item.source_file.clone(),
                        start_byte: range.start_byte as usize,
                        end_byte: range.end_byte as usize,
                    });
                }
            }
            MatchResult::AnalysisLog(diagnostic) => {
                if let Some(range) = diagnostic.range {
                    evaluation.logs.push(Log {
                        message: diagnostic.message,
                        start_byte: range.start_byte as usize,
                        end_byte: range.end_byte as usize,
                    });
                } else {
                    evaluation.diagnostics.push(diagnostic.message);
                }
            }
            MatchResult::Rewrite(item) => {
                evaluation.matched = true;
                for range in item.original.ranges {
                    evaluation.matches.push(Span {
                        path: item.original.source_file.clone(),
                        start_byte: range.start_byte as usize,
                        end_byte: range.end_byte as usize,
                    });
                }
            }
            MatchResult::CreateFile(_)
            | MatchResult::RemoveFile(_)
            | MatchResult::PatternInfo(_)
            | MatchResult::AllDone(_)
            | MatchResult::InputFile(_)
            | MatchResult::DoneFile(_) => {}
        }
    }

    serde_json::to_vec(&evaluation).unwrap_or_else(|error| failure("host", error.to_string()))
}

fn run(language: &[u8], program: &[u8], path: &[u8], source: &[u8]) -> Vec<u8> {
    let language = match text(language, "language") {
        Ok(value) => value,
        Err(error) => return error,
    };
    let path = match text(path, "path") {
        Ok(value) => value,
        Err(error) => return error,
    };
    let source = match text(source, "source") {
        Ok(value) => value,
        Err(error) => return error,
    };
    let key = (language.clone(), program.to_vec());

    let mut problems = lock(&PROBLEMS);
    if !problems.contains_key(&key) {
        let problem = match compile(&language, program) {
            Ok(value) => value,
            Err(error) => return error,
        };
        problems.insert(key.clone(), problem);
        record_compile(&key);
    }
    match problems.get(&key) {
        Some(problem) => execute(problem, path, source),
        None => failure("host", "compiled Grit program disappeared"),
    }
}

unsafe fn input<'a>(data: *const u8, len: usize) -> Result<&'a [u8], Vec<u8>> {
    if data.is_null() {
        if len == 0 {
            Ok(&[])
        } else {
            Err(failure("host", "null input with non-zero length"))
        }
    } else {
        // SAFETY: the ABI requires every non-null input to identify len readable bytes.
        Ok(unsafe { slice::from_raw_parts(data, len) })
    }
}

unsafe fn publish(bytes: Vec<u8>, out_data: *mut *mut u8, out_len: *mut usize) {
    let allocation = bytes.into_boxed_slice();
    let len = allocation.len();
    let data = Box::into_raw(allocation).cast::<u8>();
    // SAFETY: validated non-null by the ABI entry point.
    unsafe {
        ptr::write(out_data, data);
        ptr::write(out_len, len);
    }
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn attune_grit_run(
    language: *const u8,
    language_len: usize,
    program: *const u8,
    program_len: usize,
    path: *const u8,
    path_len: usize,
    source: *const u8,
    source_len: usize,
    out_data: *mut *mut u8,
    out_len: *mut usize,
) -> i32 {
    if out_data.is_null() || out_len.is_null() {
        return ABI_HOST_ERROR;
    }

    let outcome = catch_unwind(AssertUnwindSafe(|| {
        let language = unsafe { input(language, language_len) }?;
        let program = unsafe { input(program, program_len) }?;
        let path = unsafe { input(path, path_len) }?;
        let source = unsafe { input(source, source_len) }?;
        Ok::<Vec<u8>, Vec<u8>>(run(language, program, path, source))
    }));

    let (status, bytes) = match outcome {
        Ok(Ok(bytes)) => (ABI_OK, bytes),
        Ok(Err(bytes)) => (ABI_HOST_ERROR, bytes),
        Err(_) => (
            ABI_HOST_ERROR,
            failure("host", "native panic caught at ABI boundary"),
        ),
    };
    unsafe { publish(bytes, out_data, out_len) };
    status
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn attune_grit_buffer_free(data: *mut u8, len: usize) {
    if data.is_null() {
        return;
    }
    // SAFETY: the ABI requires the exact pointer/length pair returned by run.
    let allocation = ptr::slice_from_raw_parts_mut(data, len);
    unsafe { drop(Box::from_raw(allocation)) };
}

#[cfg(test)]
mod tests {
    use super::*;

    const PROGRAM: &[u8] = br#"engine marzano(0.1)
language js(typescript)

`$callee($...)` as $call where {
  $callee <: not r"^(import|require)$",
  log(message="call", variable=$callee)
}
"#;

    fn through_abi(language: &[u8], program: &[u8], path: &[u8], source: &[u8]) -> (i32, Vec<u8>) {
        let mut data = ptr::null_mut();
        let mut len = 0;
        let status = unsafe {
            attune_grit_run(
                language.as_ptr(),
                language.len(),
                program.as_ptr(),
                program.len(),
                path.as_ptr(),
                path.len(),
                source.as_ptr(),
                source.len(),
                &mut data,
                &mut len,
            )
        };
        assert!(!data.is_null());
        let owned = unsafe { slice::from_raw_parts(data, len) }.to_vec();
        unsafe { attune_grit_buffer_free(data, len) };
        (status, owned)
    }

    #[test]
    fn repeated_program_is_stable_and_compiled_once() {
        let cache_program = [PROGRAM, b"\n"].concat();
        let key = ("typescript".to_string(), cache_program.clone());
        lock(&PROBLEMS).remove(&key);
        lock(&COMPILE_COUNTS).remove(&key);
        let first = run(
            b"typescript",
            &cache_program,
            b"src/example.ts",
            b"Boolean(verify(name));",
        );
        let second = run(
            b"typescript",
            &cache_program,
            b"src/example.ts",
            b"Boolean(verify(name));",
        );
        assert_eq!(first, second);
        assert!(lock(&PROBLEMS).contains_key(&key));
        assert_eq!(lock(&COMPILE_COUNTS).get(&key), Some(&1));
        let value: serde_json::Value = serde_json::from_slice(&first).unwrap();
        assert_eq!(value["matched"], true);
        assert_eq!(value["matches"].as_array().unwrap().len(), 2);
        assert_eq!(value["logs"].as_array().unwrap().len(), 2);
    }

    #[test]
    fn invalid_program_is_a_classified_value() {
        let bytes = run(
            b"typescript",
            b"engine marzano(0.1)\nlanguage js(typescript)\nnot_a_node()",
            b"src/example.ts",
            b"",
        );
        let value: serde_json::Value = serde_json::from_slice(&bytes).unwrap();
        assert_eq!(value["error"]["kind"], "compile");
    }

    #[test]
    fn no_match_is_successful() {
        let bytes = run(b"typescript", PROGRAM, b"empty.ts", b"const value = 1;");
        let value: serde_json::Value = serde_json::from_slice(&bytes).unwrap();
        assert_eq!(value["matched"], false);
        assert_eq!(value["matches"].as_array().unwrap().len(), 0);
    }

    #[test]
    fn abi_preserves_nul_bytes_and_releases_every_output() {
        let source = b"const value = 'a\0b';\nverify(name);";
        for _ in 0..100 {
            let (status, bytes) = through_abi(b"typescript", PROGRAM, b"nul.ts", source);
            assert_eq!(status, ABI_OK);
            let value: serde_json::Value = serde_json::from_slice(&bytes).unwrap();
            assert_eq!(value["version"], 1);
        }
    }

    #[test]
    fn abi_classifies_bad_inputs_without_unwinding() {
        let mut data = ptr::null_mut();
        let mut len = 0;
        let status = unsafe {
            attune_grit_run(
                ptr::null(),
                1,
                PROGRAM.as_ptr(),
                PROGRAM.len(),
                b"x.ts".as_ptr(),
                4,
                ptr::null(),
                0,
                &mut data,
                &mut len,
            )
        };
        assert_eq!(status, ABI_HOST_ERROR);
        let bytes = unsafe { slice::from_raw_parts(data, len) }.to_vec();
        unsafe { attune_grit_buffer_free(data, len) };
        let value: serde_json::Value = serde_json::from_slice(&bytes).unwrap();
        assert_eq!(value["error"]["kind"], "host");
    }
}
