/// Compact, regenerable summaries over the immutable Atlas observation table.
/// Raw observations remain the scientific evidence. This module owns the
/// declared reductions used by reports; Java only moves typed columns through
/// Arrow/Parquet.
pub mod Atlas.Signature.Summary {
    use ScientificTable.Value
    use ScientificTable.Columns.{text, optionalText, optionalInt32, int64, float64}

    type alias Datum = {
        signatureProtocol  = String,
        atlasProtocol      = String,
        repository         = String,
        baseRevision       = String,
        sourceTreeIdentity = String,
        factIdentity       = String,
        snapshotId         = String,
        seedDomain         = String,
        depth              = Int32,
        lastAtom           = String,
        outputCardinality  = Float64,
        expansionRatio     = Option[Float64],
        reachFraction      = Float64,
        extinct            = Bool,
        firstExtinction    = Option[Int32],
        semanticStateId    = String,
        sameAsInput        = Bool
    }

    type alias Group = {
        scope      = String,
        seedDomain = String,
        depth      = Option[Int32],
        lastAtom   = Option[String]
    }

    type alias Metric = {name = String, value = Float64, sampleCount = Int32}

    pub def schema(): ScientificTable.Schema = {
        format = "attune-atlas-signature-summary-v1",
        columns = Vector#{
            text("signature_protocol"), text("atlas_protocol"), text("repository"),
            text("base_revision"), text("source_tree_identity"), text("fact_identity"),
            text("snapshot_id"), text("scope"), text("seed_domain"),
            optionalInt32("depth"), optionalText("last_atom"), text("metric"),
            float64("value"), int64("sample_count")
        }
    }

    /// Produce domain, domain/depth, and domain/depth/direction groups. Empty
    /// impossible type combinations are omitted rather than reported as zero.
    pub def summarize(rows: Vector[ScientificTable.Row]): Result[String, Vector[ScientificTable.Row]] =
        Vector.traverse(decode, rows)
            |> Result.map(data -> Vector.flatMap(group -> summarizeGroup(data, group), groups(data)))

    def groups(data: Vector[Datum]): Vector[Group] = {
        let domains = Vector#{"file", "symbol"};
        let atoms = Vector#{"defines", "defined_in", "imports", "imported_by", "calls", "callers"};
        let domainGroups = Vector.map(domain -> {
            scope = "seed_domain", seedDomain = domain, depth = None, lastAtom = None
        }, domains);
        let depthGroups = Vector.flatMap(domain -> Vector.map(depth -> {
            scope = "seed_domain_depth", seedDomain = domain,
            depth = Some(depth), lastAtom = None
        }, Vector.range(1, 8)), domains);
        let directionGroups = Vector.flatMap(domain ->
            Vector.flatMap(depth -> Vector.map(atom -> {
                scope = "seed_domain_depth_direction", seedDomain = domain,
                depth = Some(depth), lastAtom = Some(atom)
            }, atoms), Vector.range(1, 8)), domains);
        Vector.flatten(Vector#{domainGroups, depthGroups, directionGroups})
            |> Vector.filter(group -> not Vector.isEmpty(Vector.filter(row -> matches(group, row), data)))
    }

    def summarizeGroup(data: Vector[Datum], group: Group): Vector[ScientificTable.Row] = {
        let selected = Vector.filter(row -> matches(group, row), data);
        let first = Vector.get(0, selected);
        Vector.map(metric -> row(first, group, metric), metrics(selected))
    }

    def metrics(data: Vector[Datum]): Vector[Metric] = {
        let count = Vector.length(data);
        let outputs = Vector.map(row -> row#outputCardinality, data);
        let expansions = Vector.filterMap(row -> row#expansionRatio, data);
        let reaches = Vector.map(row -> row#reachFraction, data);
        let multiplicities = stateMultiplicities(data);
        Vector#{
            metric("observation_count", Int32.toFloat64(count), count),
            fraction("extinct_fraction", row -> row#extinct, data),
            fraction("survival_fraction", row -> not row#extinct, data),
            firstExtinctionMetric(1, data), firstExtinctionMetric(2, data),
            firstExtinctionMetric(3, data), firstExtinctionMetric(4, data),
            firstExtinctionMetric(5, data), firstExtinctionMetric(6, data),
            firstExtinctionMetric(7, data),
            distribution("output_cardinality_p50", outputs, 50),
            distribution("output_cardinality_p90", outputs, 90),
            distribution("output_cardinality_p99", outputs, 99),
            distribution("expansion_ratio_p50", expansions, 50),
            distribution("expansion_ratio_p90", expansions, 90),
            distribution("expansion_ratio_p99", expansions, 99),
            fractionOption("contracting_fraction", value -> value < 1.0, data),
            fractionOption("unchanged_fraction", value -> value == 1.0, data),
            fractionOption("expanding_fraction", value -> value > 1.0, data),
            distribution("reach_fraction_p50", reaches, 50),
            distribution("reach_fraction_p90", reaches, 90),
            distribution("reach_fraction_p99", reaches, 99),
            fraction("reach_ge_0_25_fraction", row -> row#reachFraction >= 0.25, data),
            fraction("reach_ge_0_50_fraction", row -> row#reachFraction >= 0.50, data),
            fraction("reach_ge_0_90_fraction", row -> row#reachFraction >= 0.90, data),
            metric("unique_semantic_states", Int32.toFloat64(Vector.length(multiplicities)), count),
            metric("logical_per_unique_state",
                ScientificTable.ratio(count, Vector.length(multiplicities)), count),
            distribution("state_multiplicity_p50", multiplicities, 50),
            distribution("state_multiplicity_p90", multiplicities, 90),
            distribution("state_multiplicity_p99", multiplicities, 99),
            metric("state_multiplicity_max", ScientificTable.maximum(multiplicities), Vector.length(multiplicities)),
            fraction("same_as_input_fraction", row -> row#sameAsInput, data)
        }
    }

    def firstExtinctionMetric(depth: Int32, data: Vector[Datum]): Metric =
        fraction("first_extinction_depth_${depth}_fraction", row -> row#firstExtinction == Some(depth), data)

    def stateMultiplicities(data: Vector[Datum]): Vector[Float64] =
        Vector.foldLeft((counts, row) ->
            Map.insertWith((left, right) -> left + right, row#semanticStateId, 1, counts),
            Map.empty(), data)
        |> Map.toVector
        |> Vector.map(match (_, count) -> Int32.toFloat64(count))

    def distribution(name: String, values: Vector[Float64], percentile: Int32): Metric =
        metric(name, quantile(values, percentile), Vector.length(values))

    def fraction(name: String, predicate: Datum -> Bool, data: Vector[Datum]): Metric =
        metric(name, ScientificTable.ratio(Vector.count(predicate, data), Vector.length(data)), Vector.length(data))

    def fractionOption(name: String, predicate: Float64 -> Bool, data: Vector[Datum]): Metric = {
        let values = Vector.filterMap(row -> row#expansionRatio, data);
        metric(name, ScientificTable.ratio(Vector.count(predicate, values), Vector.length(values)), Vector.length(values))
    }

    def metric(name: String, value: Float64, sampleCount: Int32): Metric =
        {name = name, value = value, sampleCount = sampleCount}

    def quantile(values: Vector[Float64], percentile: Int32): Float64 = {
        let sorted = mergeSort(values);
        if (Vector.isEmpty(sorted)) 0.0
        else Vector.get((Vector.length(sorted) - 1) * percentile / 100, sorted)
    }

    /// Flix's standard Vector quicksort can recurse linearly on already sorted
    /// large scientific columns. This bottom-up meaning is ordinary exact
    /// ordering with logarithmic recursive depth and a tail-recursive merge.
    def mergeSort(values: Vector[Float64]): Vector[Float64] = {
        let length = Vector.length(values);
        if (length <= 1) values
        else {
            let middle = length / 2;
            merge(
                mergeSort(Vector.slice(start = 0, end = middle, values)),
                mergeSort(Vector.slice(start = middle, end = length, values)),
                0, 0, Nil
            ) |> List.toVector
        }
    }

    def merge(left: Vector[Float64], right: Vector[Float64], leftIndex: Int32,
              rightIndex: Int32, reverse: List[Float64]): List[Float64] =
        if (leftIndex >= Vector.length(left) and rightIndex >= Vector.length(right))
            List.reverse(reverse)
        else if (rightIndex >= Vector.length(right) or
                 (leftIndex < Vector.length(left) and Vector.get(leftIndex, left) <= Vector.get(rightIndex, right)))
            merge(left, right, leftIndex + 1, rightIndex, Vector.get(leftIndex, left) :: reverse)
        else
            merge(left, right, leftIndex, rightIndex + 1, Vector.get(rightIndex, right) :: reverse)

    def matches(group: Group, row: Datum): Bool =
        group#seedDomain == row#seedDomain and
        optionMatches(group#depth, row#depth) and optionMatches(group#lastAtom, row#lastAtom)

    def optionMatches(expected: Option[a], actual: a): Bool with Eq[a] = match expected {
        case None => true
        case Some(value) => value == actual
    }

    def row(identity: Datum, group: Group, metric0: Metric): ScientificTable.Row = Map#{
        "signature_protocol" => Value.Text(identity#signatureProtocol),
        "atlas_protocol" => Value.Text(identity#atlasProtocol),
        "repository" => Value.Text(identity#repository),
        "base_revision" => Value.Text(identity#baseRevision),
        "source_tree_identity" => Value.Text(identity#sourceTreeIdentity),
        "fact_identity" => Value.Text(identity#factIdentity),
        "snapshot_id" => Value.Text(identity#snapshotId),
        "scope" => Value.Text(group#scope),
        "seed_domain" => Value.Text(group#seedDomain),
        "depth" => ScientificTable.optionalInt32Value(group#depth),
        "last_atom" => ScientificTable.optionalTextValue(group#lastAtom),
        "metric" => Value.Text(metric0#name),
        "value" => Value.Float64(metric0#value),
        "sample_count" => Value.Int64(Int32.toInt64(metric0#sampleCount))
    }

    def decode(row0: ScientificTable.Row): Result[String, Datum] = forM (
        signatureProtocol <- ScientificTable.text(row0, "signature_protocol");
        atlasProtocol <- ScientificTable.text(row0, "atlas_protocol");
        repository <- ScientificTable.text(row0, "repository");
        baseRevision <- ScientificTable.text(row0, "base_revision");
        sourceTreeIdentity <- ScientificTable.text(row0, "source_tree_identity");
        factIdentity <- ScientificTable.text(row0, "fact_identity");
        snapshotId <- ScientificTable.text(row0, "snapshot_id");
        seedDomain <- ScientificTable.text(row0, "seed_domain");
        depth <- ScientificTable.int32(row0, "depth");
        lastAtom <- ScientificTable.text(row0, "last_atom");
        outputCardinality <- ScientificTable.number(row0, "output_cardinality");
        expansionRatio <- ScientificTable.optionalFloat64(row0, "expansion_ratio");
        reachFraction <- ScientificTable.number(row0, "reach_fraction");
        extinct <- ScientificTable.boolean(row0, "extinct");
        firstExtinction <- ScientificTable.optionalInt32(row0, "first_extinction_depth");
        semanticStateId <- ScientificTable.text(row0, "semantic_state_id");
        sameAsInput <- ScientificTable.boolean(row0, "same_as_input")
    ) yield {
        signatureProtocol = signatureProtocol, atlasProtocol = atlasProtocol,
        repository = repository, baseRevision = baseRevision,
        sourceTreeIdentity = sourceTreeIdentity, factIdentity = factIdentity,
        snapshotId = snapshotId, seedDomain = seedDomain, depth = depth,
        lastAtom = lastAtom, outputCardinality = outputCardinality,
        expansionRatio = expansionRatio, reachFraction = reachFraction,
        extinct = extinct, firstExtinction = firstExtinction,
        semanticStateId = semanticStateId, sameAsInput = sameAsInput
    }
}
