def main(): Unit \ IO = {
            let summaries0 = Experiment.paths("attune.input_summaries");
            let snapshots0 = Experiment.paths("attune.input_snapshots");
            let physical0 = Experiment.paths("attune.input_physical");
            if (Vector.length(summaries0) != Vector.length(snapshots0) or
                Vector.length(summaries0) != Vector.length(physical0))
                bug!("Atlas aggregate input lists differ in length")
            else {
            let tables = load(summaries0, snapshots0, physical0, 0, Nil, Nil, Nil);
            let summaries = List.reverse(tables#summaries) |> List.toVector |> Vector.flatten;
            let snapshots = List.reverse(tables#snapshots) |> List.toVector |> Vector.flatten;
            let physical = List.reverse(tables#physical) |> List.toVector |> Vector.flatten;
            let population = Population.Table.read(
                Experiment.property("attune.population_metadata"),
                Experiment.property("attune.population_cases")) |> Experiment.require;
            let _populationProof = validatePopulation(population#cases, snapshots) |> Experiment.require;
            let writtenSummaries = ScientificTable.write(
                Experiment.property("attune.output_summaries"),
                Atlas.Signature.Summary.schema(), summaries);
            let writtenSnapshots = ScientificTable.write(
                Experiment.property("attune.output_snapshots"),
                Atlas.Signature.Table.snapshots(), snapshots);
            let writtenPhysical = ScientificTable.write(
                Experiment.property("attune.output_physical"),
                Atlas.Signature.Table.physical(), physical);
            if (Vector.length(summaries0) != Vector.length(writtenSnapshots))
                bug!("Atlas aggregate must contain exactly one snapshot row per input shard")
            else println("ATLAS_AGGREGATE snapshots=${Vector.length(writtenSnapshots)}" +
                " summaries=${Vector.length(writtenSummaries)}" +
                " physical=${Vector.length(writtenPhysical)}")
            }
    }

def validatePopulation(
    cases: Vector[Population.Case],
    snapshots: Vector[ScientificTable.Row]
): Result[String, Unit] = {
    if (Vector.length(cases) != Vector.length(snapshots))
        Err("Atlas projection and typed population have different lengths")
    else Vector.zip(cases, snapshots)
        |> Vector.traverse(match (case0, snapshot) -> forM (
            repository <- ScientificTable.text(snapshot, "repository");
            revision <- ScientificTable.text(snapshot, "base_revision");
            _ <- if (repository == case0#repository) Ok(()) else Err("Atlas population repository drift");
            _ <- if (revision == case0#baseRevision) Ok(()) else Err("Atlas population revision drift")
        ) yield ())
        |> Result.map(_ -> ())
}

type alias Tables = {
    summaries = List[Vector[ScientificTable.Row]],
    snapshots = List[Vector[ScientificTable.Row]],
    physical  = List[Vector[ScientificTable.Row]]
}

def load(summaryPaths: Vector[String], snapshotPaths: Vector[String], physicalPaths: Vector[String],
         index: Int32, summaries: List[Vector[ScientificTable.Row]],
         snapshots: List[Vector[ScientificTable.Row]],
         physical: List[Vector[ScientificTable.Row]]): Tables \ IO =
    if (index >= Vector.length(summaryPaths)) {
        summaries = summaries, snapshots = snapshots, physical = physical
    } else {
        load(summaryPaths, snapshotPaths, physicalPaths, index + 1,
            ScientificTable.read(Vector.get(index, summaryPaths), Atlas.Signature.Summary.schema()) :: summaries,
            ScientificTable.read(Vector.get(index, snapshotPaths), Atlas.Signature.Table.snapshots()) :: snapshots,
            ScientificTable.read(Vector.get(index, physicalPaths), Atlas.Signature.Table.physical()) :: physical)
    }
