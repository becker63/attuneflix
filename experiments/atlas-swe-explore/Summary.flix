import java.lang.System

def main(): Unit \ IO = {
    let input = System.getProperty("attune.input_observations");
    let output = System.getProperty("attune.output_summary");
    let observations = ScientificTable.read(input, Atlas.Signature.Table.observations());
    match Atlas.Signature.Summary.summarize(observations) {
        case Err(error) => bug!(error)
        case Ok(rows) => {
            let written = ScientificTable.write(output, Atlas.Signature.Summary.schema(), rows);
            println("ATLAS_SUMMARY input_rows=${Vector.length(observations)} output_rows=${Vector.length(written)}")
        }
    }
}
