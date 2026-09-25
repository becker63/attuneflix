def main(): Unit \ IO = {
    let input = Experiment.property("attune.input_observations");
    let output = Experiment.property("attune.output_summary");
    let observations = ScientificTable.read(input, Atlas.Signature.Table.observations());
    match Atlas.Signature.Summary.summarize(observations) {
        case Err(error) => bug!(error)
        case Ok(rows) => {
            let written = ScientificTable.write(output, Atlas.Signature.Summary.schema(), rows);
            println("ATLAS_SUMMARY input_rows=${Vector.length(observations)} output_rows=${Vector.length(written)}")
        }
    }
}
