def main(): Unit \ {Fs.FileSystem, IO} = AnchorMain.execute()

/// A new derived action over one frozen typed world. The source Parquet files
/// are inputs, never outputs; no provider, acquisition, or source checkout runs.
mod AnchorMain {
    use Fs.FileSystem

    type alias Measured = {path = String, result = AnchorAnalysis.Scenario}

    pub def execute(): Unit \ {FileSystem, IO} = {
        let identity: Repository.Table.Identity = {
            repository = Experiment.property("attune.repository"),
            baseRevision = Experiment.property("attune.base_revision"),
            sourceTreeIdentity = Experiment.property("attune.source_tree_identity"),
            factIdentity = Experiment.property("attune.fact_identity"),
            snapshotId = Experiment.property("attune.snapshot_id")
        };
        let world = Repository.Table.read(
            Experiment.property("attune.world_metadata"),
            Experiment.property("attune.world_entities"),
            Experiment.property("attune.world_relations"), identity)
            |> Experiment.require;
        let target = Experiment.property("attune.anchor_path");
        if (not Vector.exists(path -> Anchor.contains(path, target), world#files))
            bug!("anchor is absent from admitted files: ${target}")
        else {
            let controls = Anchor.controls(world, target, 2);
            if (Vector.length(controls) != 2)
                bug!("counterfactual requires two deterministic sibling controls")
            else measure(world, identity, target, controls)
        }
    }

    def measure(world: Repository.World, identity: Repository.Table.Identity,
                target: String, controls: Vector[String]): Unit \ {FileSystem, IO} = {
        let seeds = Atlas.Signature.seeds(world);
        let baselineRuns = AnchorAnalysis.evaluate(world, seeds) |> Experiment.require;
        let baseline = AnchorAnalysis.scenario(world, world, "baseline", baselineRuns);
        let interventions = Vector.append(Vector#{target}, controls);
        let changed = Vector.traverse(path -> {
            let masked = Anchor.maskBoundary(world, path);
            AnchorAnalysis.evaluate(masked, seeds)
                |> Result.map(runs -> {
                    path = path,
                    result = AnchorAnalysis.scenario(world, masked, "masked", runs)
                })
        }, interventions) |> Experiment.require;
        let fileMasses = Anchor.masses(world, AnchorAnalysis.outputs(baselineRuns, Radii.Domain.File));
        let symbolMasses = Anchor.masses(world, AnchorAnalysis.outputs(baselineRuns, Radii.Domain.Symbol));
        let anchorRows = Vector.append(
            AnchorTable.anchorRows(identity#snapshotId, "file", world, fileMasses),
            AnchorTable.anchorRows(identity#snapshotId, "symbol", world, symbolMasses));
        let scenarioRows = Vector.append(
            AnchorTable.scenarioRows(identity#snapshotId, "", baseline),
            Vector.flatMap(row -> AnchorTable.scenarioRows(identity#snapshotId, row#path, row#result), changed));
        let writtenAnchors = ScientificTable.write(Experiment.property("attune.output_anchors"),
            AnchorTable.anchors(), anchorRows);
        let writtenScenarios = ScientificTable.write(Experiment.property("attune.output_scenarios"),
            AnchorTable.scenarios(), scenarioRows);
        if (writtenAnchors != anchorRows or writtenScenarios != scenarioRows)
            bug!("anchor tables failed exact typed round-trip")
        else {
            let report = report(Experiment.property("attune.baseline_commit"), identity,
                target, controls, baseline, changed, fileMasses, symbolMasses);
            match FileSystem.write(str = report, Experiment.property("attune.output_report")) {
                case Err(error) => bug!(ToString.toString(error))
                case Ok(_) => println("ATLAS_ANCHORS snapshot=${identity#snapshotId}" +
                    " anchor_rows=${Vector.length(anchorRows)}" +
                    " scenarios=${Vector.length(scenarioRows)}")
            }
        }
    }

    def report(baselineCommit: String, identity: Repository.Table.Identity,
               target: String, controls: Vector[String],
               baseline: AnchorAnalysis.Scenario, changed: Vector[Measured],
               fileMasses: Vector[Anchor.Mass], symbolMasses: Vector[Anchor.Mass]): String = {
        let fileMass = Vector.find(row -> row#anchorPath == target, fileMasses);
        let symbolMass = Vector.find(row -> row#anchorPath == target, symbolMasses);
        "# Structural anchor counterfactual (derived)\n\n" +
        "Baseline pushed code commit: `${baselineCommit}`.\n" +
        "Frozen snapshot: `${identity#snapshotId}` (`${identity#repository}` at `${identity#baseRevision}`).\n" +
        "Protocol: 16 frozen issue-blind singleton seeds, six directed atoms, depth seven; " +
        "same Atlas.Signature.compute for every row. Directory prefixes classify File/Symbol members " +
        "but never enter the Atlas state domain.\n\n" +
        "Target: `${target}`. Boundary mask removes admitted imports and calls with exactly one " +
        "endpoint under that prefix; internal edges, files, symbols, defines and parents remain.\n" +
        "Controls: the two sibling directories with positive crossing-edge volume nearest the " +
        "target's volume, ties by path: `${Vector.get(0, controls)}`, `${Vector.get(1, controls)}`.\n\n" +
        "## Anchor mass among non-empty states\n\n" +
        "| Domain | Distinct states containing target / live states | Unique mass | " +
        "Observations containing target / live observations | Weighted mass |\n" +
        "| --- | ---: | ---: | ---: | ---: |\n" +
        massLine("File", fileMass) + massLine("Symbol", symbolMass) + "\n" +
        "## Same signature protocol under boundary masks\n\n" +
        "| Intervention | Domain | Survival | p90 reach | Total recurrence | Live recurrence | " +
        "Unique live states | Extinct observations | Physical compression | Reuse | Masked edges |\n" +
        "| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |\n" +
        scenarioLines("baseline", baseline) +
        (Vector.map(row -> scenarioLines(row#path, row#result), changed) |> Vector.join("")) + "\n" +
        "## Absolute and relative deltas from baseline\n\n" +
        (Vector.map(row -> deltaSection(row#path, baseline, row#result), changed) |> Vector.join("")) +
        "## Interpretation limits\n\n" +
        "These are deterministic structural interventions, not observed task contention or a causal " +
        "claim about software quality. Total recurrence can move because extinction changes; compare " +
        "live recurrence and live-state counts separately. A boundary mask changes the admitted world, " +
        "not Babel source or the frozen snapshot. A region's visual prominence at depth 1–3 is " +
        "separate from its depth-seven state mass.\n"
    }

    def massLine(domain: String, candidate: Option[Anchor.Mass]): String = match candidate {
        case None => "| ${domain} | 0 / 0 | 0 | 0 / 0 | 0 |\n"
        case Some(mass) => "| ${domain} | ${mass#uniqueContaining} / ${mass#uniqueLiveStates} | " +
            "${mass#uniqueFraction} | ${mass#weightedContaining} / ${mass#liveObservations} | " +
            "${mass#weightedFraction} |\n"
    }

    def scenarioLines(name: String, scenario: AnchorAnalysis.Scenario): String =
        scenarioLine(name, "File", scenario#file, scenario) +
        scenarioLine(name, "Symbol", scenario#symbol, scenario)

    def scenarioLine(name: String, domain: String, values: AnchorAnalysis.Domain,
                     scenario: AnchorAnalysis.Scenario): String = {
        let data = values#decomposition;
        "| ${name} | ${domain} | ${ScientificTable.ratio(data#liveObservations, data#observations)} | " +
        "${values#reachP90} | ${data#totalRecurrence} | ${data#liveRecurrence} | " +
        "${data#uniqueLiveStates} | ${data#extinctObservations} / ${data#observations} | " +
        "${scenario#physicalCompression} | ${scenario#physicalReuse} | " +
            "${scenario#maskedImports} imports + ${scenario#maskedCalls} calls |\n"
    }

    def deltaSection(path: String, baseline: AnchorAnalysis.Scenario,
                     changed: AnchorAnalysis.Scenario): String =
        "### `${path}`\n\n| Metric | Baseline | Masked | Absolute Δ | Relative Δ |\n" +
        "| --- | ---: | ---: | ---: | ---: |\n" +
        domainDeltas("File", baseline#file, changed#file) +
        domainDeltas("Symbol", baseline#symbol, changed#symbol) +
        delta("physical compression", baseline#physicalCompression, changed#physicalCompression) +
        delta("physical reuse fraction", baseline#physicalReuse, changed#physicalReuse) + "\n"

    def domainDeltas(name: String, baseline: AnchorAnalysis.Domain,
                     changed: AnchorAnalysis.Domain): String = {
        let before = baseline#decomposition;
        let after = changed#decomposition;
        delta("${name} survival fraction",
            ScientificTable.ratio(before#liveObservations, before#observations),
            ScientificTable.ratio(after#liveObservations, after#observations)) +
        delta("${name} p90 reach", baseline#reachP90, changed#reachP90) +
        delta("${name} total recurrence", before#totalRecurrence, after#totalRecurrence) +
        delta("${name} live recurrence", before#liveRecurrence, after#liveRecurrence) +
        delta("${name} unique total states", Int32.toFloat64(before#uniqueStates),
            Int32.toFloat64(after#uniqueStates)) +
        delta("${name} unique live states", Int32.toFloat64(before#uniqueLiveStates),
            Int32.toFloat64(after#uniqueLiveStates)) +
        delta("${name} extinct observations", Int32.toFloat64(before#extinctObservations),
            Int32.toFloat64(after#extinctObservations))
    }

    def delta(name: String, before: Float64, after: Float64): String = {
        let difference = after - before;
        let relative = if (before == 0.0) "undefined (zero baseline)"
            else "${100.0 * difference / before}%";
        "| ${name} | ${before} | ${after} | ${difference} | ${relative} |\n"
    }
}
