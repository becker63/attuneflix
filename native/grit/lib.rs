use std::{
    cell::RefCell,
    collections::{BTreeMap, HashMap},
    panic::{AssertUnwindSafe, catch_unwind},
    ptr,
    slice,
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

thread_local! {
    static PROBLEMS: RefCell<HashMap<(String, Vec<u8>), Problem>> =
        RefCell::new(HashMap::new());
}

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
    .unwrap_or_else(|_| br#"{"version":1,"error":{"kind":"host","message":"JSON encoding failed"}}"#.to_vec())
}

fn text(bytes: &[u8], name: &str) -> Result<String, Vec<u8>> {
    String::from_utf8(bytes.to_vec())
        .map_err(|error| failure("host", format!("{name} is not UTF-8: {error}")))
}

fn target(language: &str) -> Result<TargetLanguage, Vec<u8>> {
    let pattern = match language {
        "typescript" => PatternLanguage::TypeScript,
        _ => return Err(failure("unsupported-language", language)),
    };
    TargetLanguage::try_from(pattern)
        .map_err(|error| failure("host", error.to_string()))
}

fn compile(language: &str, program: &[u8]) -> Result<Problem, Vec<u8>> {
    let source = text(program, "program")?;
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

    serde_json::to_vec(&evaluation)
        .unwrap_or_else(|error| failure("host", error.to_string()))
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

    PROBLEMS.with(|problems| {
        if !problems.borrow().contains_key(&key) {
            let problem = match compile(&language, program) {
                Ok(value) => value,
                Err(error) => return error,
            };
            problems.borrow_mut().insert(key.clone(), problem);
        }
        let borrowed = problems.borrow();
        match borrowed.get(&key) {
            Some(problem) => execute(problem, path, source),
            None => failure("host", "compiled Grit program disappeared"),
        }
    })
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
        Err(_) => (ABI_HOST_ERROR, failure("host", "native panic caught at ABI boundary")),
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

    #[test]
    fn repeated_program_is_stable_and_compiled_once() {
        PROBLEMS.with(|problems| problems.borrow_mut().clear());
        let first = run(b"typescript", PROGRAM, b"src/example.ts", b"Boolean(verify(name));");
        let second = run(b"typescript", PROGRAM, b"src/example.ts", b"Boolean(verify(name));");
        assert_eq!(first, second);
        PROBLEMS.with(|problems| assert_eq!(problems.borrow().len(), 1));
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
}
