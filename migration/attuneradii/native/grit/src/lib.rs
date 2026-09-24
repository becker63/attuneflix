use std::{
    cell::RefCell,
    collections::{BTreeMap, HashMap},
};

use marzano_core::{
    api::MatchResult,
    pattern_compiler::{CompilationResult, src_to_problem_libs},
    problem::Problem,
};
use marzano_language::target_language::{PatternLanguage, TargetLanguage};
use marzano_util::{rich_path::RichFile, runtime::ExecutionContext};
use pyo3::{exceptions::PyValueError, prelude::*};

type NativeSpan = (String, usize, usize);
type NativeLog = (String, usize, usize);
type NativeEvaluation = (bool, Vec<NativeSpan>, Vec<NativeLog>);

thread_local! {
    static PROBLEMS: RefCell<HashMap<String, Problem>> =
        RefCell::new(HashMap::new());
}

fn compile_problem(source: String) -> Result<Problem, String> {
    let language =
        TargetLanguage::try_from(PatternLanguage::TypeScript).map_err(|error| error.to_string())?;

    match src_to_problem_libs(source, &BTreeMap::new(), language, None, None, None, None) {
        Ok(CompilationResult { problem, .. }) => Ok(problem),

        Err(error) => Err(error.to_string()),
    }
}

fn match_range(path: &str, start_byte: u32, end_byte: u32) -> NativeSpan {
    (path.to_owned(), start_byte as usize, end_byte as usize)
}

fn execute(problem: &Problem, path: &str, content: &str) -> NativeEvaluation {
    let context = ExecutionContext::default();

    let inputs = vec![RichFile::new(path.to_owned(), content.to_owned())];

    let mut matched = false;
    let mut matches = Vec::new();
    let mut logs = Vec::new();

    for result in problem.execute_files(inputs, &context) {
        match result {
            MatchResult::Match(item) => {
                matched = true;

                for range in item.ranges {
                    matches.push(match_range(
                        &item.source_file,
                        range.start_byte,
                        range.end_byte,
                    ));
                }
            }

            MatchResult::AnalysisLog(diagnostic) => {
                if let Some(range) = diagnostic.range {
                    logs.push((
                        diagnostic.message,
                        range.start_byte as usize,
                        range.end_byte as usize,
                    ));
                }
            }

            MatchResult::Rewrite(item) => {
                matched = true;

                for range in item.original.ranges {
                    matches.push(match_range(
                        &item.original.source_file,
                        range.start_byte,
                        range.end_byte,
                    ));
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

    (matched, matches, logs)
}

fn run_cached(program: &str, path: &str, content: &str) -> Result<NativeEvaluation, String> {
    PROBLEMS.with(|problems| {
        if !problems.borrow().contains_key(program) {
            let problem = compile_problem(program.to_owned())?;

            problems.borrow_mut().insert(program.to_owned(), problem);
        }

        let borrowed = problems.borrow();

        let problem = borrowed
            .get(program)
            .ok_or_else(|| "compiled Grit program disappeared".to_owned())?;

        Ok(execute(problem, path, content))
    })
}

#[pyfunction]
fn run(program: &str, path: &str, content: &str) -> PyResult<NativeEvaluation> {
    run_cached(program, path, content).map_err(PyValueError::new_err)
}

#[pymodule]
fn _attune_grit(module: &Bound<'_, PyModule>) -> PyResult<()> {
    module.add_function(wrap_pyfunction!(run, module)?)?;

    Ok(())
}
