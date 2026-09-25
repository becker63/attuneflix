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
type InputKey = (String, String);
type CachedEvaluation = (String, Vec<u8>);

static PROBLEMS: LazyLock<Mutex<HashMap<ProgramKey, Problem>>> =
    LazyLock::new(|| Mutex::new(HashMap::new()));
static EVALUATIONS: LazyLock<Mutex<HashMap<ProgramKey, HashMap<String, CachedEvaluation>>>> =
    LazyLock::new(|| Mutex::new(HashMap::new()));

#[cfg(test)]
static COMPILE_COUNTS: LazyLock<Mutex<HashMap<ProgramKey, usize>>> =
    LazyLock::new(|| Mutex::new(HashMap::new()));
#[cfg(test)]
static EXECUTE_COUNTS: LazyLock<Mutex<HashMap<(ProgramKey, InputKey), usize>>> =
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

#[cfg(test)]
fn record_execute(program: &ProgramKey, input: &InputKey) {
    *lock(&EXECUTE_COUNTS)
        .entry((program.clone(), input.clone()))
        .or_insert(0) += 1;
}

#[cfg(not(test))]
fn record_execute(_program: &ProgramKey, _input: &InputKey) {}

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
        // The frozen Python/PyO3 oracle retained Marzano's TypeScript target
        // while selecting the concrete TypeScript or JSX grammar in source.
        // Keep that target contract during the behavior-preserving layout move.
        "javascript" | "jsx" | "typescript" | "tsx" => PatternLanguage::TypeScript,
        // Attune's additional admitted languages, all inside the frozen closure.
        "java" => PatternLanguage::Java,
        "flix" => PatternLanguage::Flix,
        "starlark" => PatternLanguage::Starlark,
        _ => return Err(failure("unsupported-language", language)),
    };
    TargetLanguage::try_from(pattern).map_err(|error| failure("host", error.to_string()))
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
    let input_key = (path.clone(), source.clone());

    if let Some(bytes) = lock(&EVALUATIONS)
        .get(&key)
        .and_then(|inputs| inputs.get(&path))
        .and_then(|(cached_source, bytes)| {
            if cached_source == &source {
                Some(bytes.clone())
            } else {
                None
            }
        })
    {
        return bytes;
    }

    let mut problems = lock(&PROBLEMS);
    if !problems.contains_key(&key) {
        let problem = match compile(&language, program) {
            Ok(value) => value,
            Err(error) => return error,
        };
        problems.insert(key.clone(), problem);
        record_compile(&key);
    }
    let bytes = match problems.get(&key) {
        Some(problem) => {
            record_execute(&key, &input_key);
            execute(problem, path, source)
        }
        None => failure("host", "compiled Grit program disappeared"),
    };
    drop(problems);
    lock(&EVALUATIONS)
        .entry(key)
        .or_default()
        .insert(input_key.0, (input_key.1, bytes.clone()));
    bytes
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

    /// The narrowest proof that one admitted language is a real Grit target
    /// language: the compiled engine, entered through the ABI, selects the
    /// language, compiles the pattern against that language's grammar, parses
    /// the source file, and returns exactly the range of the matched call.
    ///
    /// `declaration` is the GritQL `language` clause and `call` the exact source
    /// text the pattern must match, so the expected range is derived from the
    /// fixture instead of asserted as a magic offset.
    fn assert_seam(language: &str, declaration: &str, path: &str, source: &str, call: &str) {
        let program = format!(
            "engine marzano(0.1)\nlanguage {declaration}\n\n\
             `$callee($...)` where {{ log(message=\"call\", variable=$callee) }}\n"
        );
        let (status, bytes) = through_abi(
            language.as_bytes(),
            program.as_bytes(),
            path.as_bytes(),
            source.as_bytes(),
        );
        assert_eq!(status, ABI_OK, "{language}: {program}");
        let value: serde_json::Value = serde_json::from_slice(&bytes).unwrap();
        assert_eq!(value["matched"], true, "{language}: {value}");
        let matches = value["matches"].as_array().unwrap();
        assert_eq!(matches.len(), 1, "{language}: {value}");
        let span = &matches[0];
        assert_eq!(span["path"], path, "{language}: {value}");
        let start = span["start_byte"].as_u64().unwrap() as usize;
        let end = span["end_byte"].as_u64().unwrap() as usize;
        assert_eq!(start, source.find(call).unwrap(), "{language}: {value}");
        assert_eq!(end, start + call.len(), "{language}: {value}");
        assert_eq!(source.get(start..end).unwrap(), call, "{language}: {value}");
        assert_eq!(value["logs"].as_array().unwrap().len(), 1, "{language}: {value}");
        assert!(value["diagnostics"].as_array().unwrap().is_empty(), "{language}: {value}");
    }

    #[test]
    fn javascript_seam_runs_inside_the_native_engine() {
        assert_seam(
            "javascript",
            "js",
            "src/helper.js",
            "helper(1);\n",
            "helper(1)",
        );
    }

    #[test]
    fn typescript_seam_runs_inside_the_native_engine() {
        assert_seam(
            "typescript",
            "js(typescript)",
            "src/helper.ts",
            "helper(1);\n",
            "helper(1)",
        );
    }

    #[test]
    fn java_seam_runs_inside_the_native_engine() {
        assert_seam(
            "java",
            "java",
            "src/Helper.java",
            "class Helper {\n    void run() {\n        helper(1);\n    }\n}\n",
            "helper(1)",
        );
    }

    #[test]
    fn flix_seam_runs_inside_the_native_engine() {
        assert_seam(
            "flix",
            "flix",
            "src/Main.flix",
            "def main(): Int32 = helper(1)\n",
            "helper(1)",
        );
    }

    #[test]
    fn starlark_seam_runs_inside_the_native_engine() {
        assert_seam(
            "starlark",
            "starlark",
            "src/build.bzl",
            "def _impl(ctx):\n    return helper(1)\n",
            "helper(1)",
        );
    }

    /// The GritQL grammar patch that admits `language flix` and
    /// `language starlark` must not swallow identifiers that merely begin with
    /// those words: `flixy` and `starlarky` stay ordinary names, as pattern
    /// names and as the matched source text.
    #[test]
    fn language_keywords_do_not_swallow_identifiers() {
        for (language, keyword, path, source) in [
            (
                "flix",
                "flixy",
                "src/Main.flix",
                "def main(): Int32 = flixy(1)\n",
            ),
            (
                "starlark",
                "starlarky",
                "src/build.bzl",
                "def _impl(ctx):\n    return starlarky(1)\n",
            ),
        ] {
            let program = format!(
                "engine marzano(0.1)\nlanguage {language}\n\n\
                 pattern {keyword}() {{ `{keyword}($...)` }}\n\n{keyword}()\n"
            );
            let (status, bytes) = through_abi(
                language.as_bytes(),
                program.as_bytes(),
                path.as_bytes(),
                source.as_bytes(),
            );
            assert_eq!(status, ABI_OK);
            let value: serde_json::Value = serde_json::from_slice(&bytes).unwrap();
            assert_eq!(value["matched"], true, "{language}: {program}\n{value}");
            let matches = value["matches"].as_array().unwrap();
            assert_eq!(matches.len(), 1, "{language}: {value}");
            let start = matches[0]["start_byte"].as_u64().unwrap() as usize;
            let end = matches[0]["end_byte"].as_u64().unwrap() as usize;
            assert_eq!(
                source.get(start..end).unwrap(),
                format!("{keyword}(1)"),
                "{language}: {value}"
            );
        }
    }

    /// The admitted languages are addressable the way the Grit language system
    /// addresses them: by the name a program declares, and by the file kinds
    /// the repository admits.
    #[test]
    fn admitted_languages_dispatch_by_name_and_file_kind() {
        use marzano_language::target_language::PatternLanguage;

        for (name, language) in [
            ("javascript", PatternLanguage::JavaScript),
            ("js", PatternLanguage::Tsx),
            ("typescript", PatternLanguage::TypeScript),
            ("java", PatternLanguage::Java),
            ("flix", PatternLanguage::Flix),
            ("starlark", PatternLanguage::Starlark),
        ] {
            assert_eq!(
                PatternLanguage::from_string(name, None),
                Some(language),
                "language {name} is not declared to the Grit language system"
            );
        }

        // Bazel's build files are Starlark: `.bzl`, `.bazel` (`BUILD.bazel`),
        // and the extensionless `BUILD`/`WORKSPACE` names.
        for kind in [
            "bzl",
            "bazel",
            "star",
            "BUILD",
            "BUILD.bazel",
            "WORKSPACE",
            "WORKSPACE.bazel",
        ] {
            assert_eq!(
                PatternLanguage::from_extension(kind),
                Some(PatternLanguage::Starlark),
                "{kind} does not dispatch to Starlark"
            );
        }
        assert_eq!(
            PatternLanguage::from_extension("flix"),
            Some(PatternLanguage::Flix)
        );
        assert_eq!(
            PatternLanguage::from_extension("java"),
            Some(PatternLanguage::Java)
        );
        for extension in ["bzl", "bazel"] {
            assert!(
                PatternLanguage::Starlark.match_extension(extension),
                "Starlark does not own .{extension}"
            );
        }
        assert_eq!(PatternLanguage::Starlark.get_default_extension(), Some("bzl"));
        assert!(PatternLanguage::Flix.match_extension("flix"));
        assert!(PatternLanguage::Java.match_extension("java"));
    }

    #[test]
    fn repeated_exact_input_is_stable_compiled_once_and_executed_once() {
        let cache_program = [PROGRAM, b"\n"].concat();
        let key = ("typescript".to_string(), cache_program.clone());
        let input = (
            "src/example.ts".to_string(),
            "Boolean(verify(name));".to_string(),
        );
        lock(&PROBLEMS).remove(&key);
        lock(&EVALUATIONS).remove(&key);
        lock(&COMPILE_COUNTS).remove(&key);
        lock(&EXECUTE_COUNTS).remove(&(key.clone(), input.clone()));
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
        assert_eq!(
            lock(&EXECUTE_COUNTS).get(&(key.clone(), input.clone())),
            Some(&1)
        );
        let value: serde_json::Value = serde_json::from_slice(&first).unwrap();
        assert_eq!(value["matched"], true);
        assert_eq!(value["matches"].as_array().unwrap().len(), 2);
        assert_eq!(value["logs"].as_array().unwrap().len(), 2);

        let changed_source = "Boolean(other(name));".to_string();
        let changed = run(
            b"typescript",
            &cache_program,
            b"src/example.ts",
            changed_source.as_bytes(),
        );
        assert_ne!(first, changed);
        assert_eq!(
            lock(&EXECUTE_COUNTS).get(&(
                key.clone(),
                ("src/example.ts".to_string(), changed_source.clone()),
            )),
            Some(&1)
        );
        let evaluations = lock(&EVALUATIONS);
        let inputs = evaluations.get(&key).unwrap();
        assert_eq!(inputs.len(), 1);
        assert_eq!(inputs["src/example.ts"].0, changed_source);
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
