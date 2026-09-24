/// Canonical typed Parquet schemas for the Atlas census. These declarations
/// are the scientific data model; the Arrow boundary only realizes them.
pub mod Atlas.Signature.Table {
    use Util.Json
    use Util.Json.Json.{JArray, JBool, JNull, JString}
    use Util.Json.ToJson

    pub type alias SnapshotIdentity = {
        signatureProtocol  = String,
        atlasProtocol      = String,
        repository         = String,
        baseRevision       = String,
        sourceTreeIdentity = String,
        factIdentity       = String,
        snapshotId         = String
    }

    pub type alias SeedIdentity = {
        domain  = Radii.Domain,
        identity = String,
        ordinal = Int32
    }

    pub def observations(): ScientificTable.Schema = {
        format = "attune-atlas-signature-observations-v1",
        columns = Vector#{
            text("signature_protocol"), text("atlas_protocol"), text("repository"),
            text("base_revision"), text("source_tree_identity"), text("fact_identity"),
            text("snapshot_id"), text("seed_domain"), text("seed_identity"),
            int32("seed_ordinal"), text("route_id"), textList("route_atoms"),
            int32("depth"), text("first_atom"), text("last_atom"),
            text("terminal_domain"), int64("input_cardinality"),
            int64("output_cardinality"), int64("domain_cardinality"),
            optionalFloat64("expansion_ratio"), float64("reach_fraction"),
            boolean("extinct"), optionalInt32("first_extinction_depth"),
            text("semantic_state_id"), boolean("same_as_input")
        }
    }

    pub def snapshots(): ScientificTable.Schema = {
        format = "attune-atlas-signature-snapshots-v1",
        columns = Vector.append(identityColumns(), Vector#{
            int64("file_count"), int64("symbol_count"), int64("defines_count"),
            int64("imports_count"), int64("calls_count"), int64("parent_count"),
            int64("manifest_case_count")
        })
    }

    pub def physical(): ScientificTable.Schema = {
        format = "attune-atlas-signature-physical-v1",
        columns = Vector.append(identityColumns(), Vector#{
            text("seed_domain"), text("seed_identity"), int32("seed_ordinal"),
            int64("logical_routes"), int64("unique_semantic_states"),
            int64("physical_transition_requests"),
            int64("physical_transition_evaluations"),
            int64("physical_transition_reuses"),
            float64("logical_per_unique_state"),
            float64("logical_per_physical_evaluation"),
            int64("memo_cells"), optionalInt64("compiled_dag_nodes")
        })
    }

    pub def caseSnapshots(): ScientificTable.Schema = {
        format = "attune-atlas-case-snapshots-v1",
        columns = Vector#{
            text("signature_protocol"), int32("manifest_position"), text("case_id"),
            text("population"), text("split"), text("repository"),
            text("base_revision"), text("source_tree_identity"), text("fact_identity"),
            text("snapshot_id")
        }
    }

    /// Materialize one exact row per logical Atlas route. The route and state
    /// digests are scientific identities, not evaluator allocation IDs.
    pub def observationRows(
        snapshot: SnapshotIdentity,
        seed: SeedIdentity,
        signature: Atlas.Signature.Signature
    ): Vector[ScientificTable.Row] \ IO = {
        // Many logical routes intentionally converge on the same exact set.
        // Canonicalizing that large set once per unique semantic state keeps
        // persisted identity exact without repeatedly sorting identical IDs.
        let (_, reverseRows) = Vector.foldLeft((acc, observation) -> {
            let (stateIds, rows) = acc;
            match Map.get(observation#output, stateIds) {
                case Some(stateId0) =>
                    (stateIds, observationRow(snapshot, seed, observation, stateId0) :: rows)
                case None => {
                    let stateId0 = Atlas.Signature.stateId(observation#output);
                    (Map.insert(observation#output, stateId0, stateIds),
                        observationRow(snapshot, seed, observation, stateId0) :: rows)
                }
            }
        }, (Map.empty(), Nil), signature#observations);
        List.reverse(reverseRows) |> List.toVector
    }

    /// Physical work for this seed. Every transition-table miss inserts one
    /// memo cell, hence `memo_cells == physical_transition_evaluations` for
    /// this evaluator. There is no separate compiled Atlas DAG counter yet.
    pub def physicalRow(
        snapshot: SnapshotIdentity,
        seed: SeedIdentity,
        signature: Atlas.Signature.Signature
    ): ScientificTable.Row = {
        let evaluations = signature#physicalTransitions;
        let reuses = signature#transitionReuses;
        let logical = signature#logicalPrograms;
        let unique = signature#uniqueStates;
        Map#{
            "signature_protocol" => JString(snapshot#signatureProtocol),
            "atlas_protocol" => JString(snapshot#atlasProtocol),
            "repository" => JString(snapshot#repository),
            "base_revision" => JString(snapshot#baseRevision),
            "source_tree_identity" => JString(snapshot#sourceTreeIdentity),
            "fact_identity" => JString(snapshot#factIdentity),
            "snapshot_id" => JString(snapshot#snapshotId),
            "seed_domain" => JString(Atlas.Signature.domainName(seed#domain)),
            "seed_identity" => JString(seed#identity),
            "seed_ordinal" => ToJson.toJson(seed#ordinal),
            "logical_routes" => ToJson.toJson(logical),
            "unique_semantic_states" => ToJson.toJson(unique),
            "physical_transition_requests" => ToJson.toJson(evaluations + reuses),
            "physical_transition_evaluations" => ToJson.toJson(evaluations),
            "physical_transition_reuses" => ToJson.toJson(reuses),
            "logical_per_unique_state" => ToJson.toJson(ratio(logical, unique)),
            "logical_per_physical_evaluation" => ToJson.toJson(ratio(logical, evaluations)),
            "memo_cells" => ToJson.toJson(evaluations),
            "compiled_dag_nodes" => JNull
        }
    }

    pub def snapshotRow(
        snapshot: SnapshotIdentity,
        repository: Repository.World,
        manifestCaseCount: Int32
    ): ScientificTable.Row = Map#{
        "signature_protocol" => JString(snapshot#signatureProtocol),
        "atlas_protocol" => JString(snapshot#atlasProtocol),
        "repository" => JString(snapshot#repository),
        "base_revision" => JString(snapshot#baseRevision),
        "source_tree_identity" => JString(snapshot#sourceTreeIdentity),
        "fact_identity" => JString(snapshot#factIdentity),
        "snapshot_id" => JString(snapshot#snapshotId),
        "file_count" => ToJson.toJson(Vector.length(repository#files)),
        "symbol_count" => ToJson.toJson(Vector.length(repository#symbols)),
        "defines_count" => ToJson.toJson(Set.size(repository#defines)),
        "imports_count" => ToJson.toJson(Set.size(repository#imports)),
        "calls_count" => ToJson.toJson(Set.size(repository#calls)),
        "parent_count" => ToJson.toJson(Set.size(repository#parents)),
        "manifest_case_count" => ToJson.toJson(manifestCaseCount)
    }

    def observationRow(
        snapshot: SnapshotIdentity,
        seed: SeedIdentity,
        observation: Atlas.Signature.Observation,
        stateId0: String
    ): ScientificTable.Row \ IO = {
        let routeId = Atlas.Signature.routeId(observation#program);
        let atoms = Vector.map(Atlas.Signature.atomName, observation#program#steps);
        Map#{
            "signature_protocol" => JString(snapshot#signatureProtocol),
            "atlas_protocol" => JString(snapshot#atlasProtocol),
            "repository" => JString(snapshot#repository),
            "base_revision" => JString(snapshot#baseRevision),
            "source_tree_identity" => JString(snapshot#sourceTreeIdentity),
            "fact_identity" => JString(snapshot#factIdentity),
            "snapshot_id" => JString(snapshot#snapshotId),
            "seed_domain" => JString(Atlas.Signature.domainName(seed#domain)),
            "seed_identity" => JString(seed#identity),
            "seed_ordinal" => ToJson.toJson(seed#ordinal),
            "route_id" => JString(routeId),
            "route_atoms" => JArray(Vector.map(JString, atoms)),
            "depth" => ToJson.toJson(observation#depth),
            "first_atom" => JString(Vector.get(0, atoms)),
            "last_atom" => JString(Vector.get(Vector.length(atoms) - 1, atoms)),
            "terminal_domain" => JString(Atlas.Signature.domainName(
                Atlas.stateDomain(observation#output))),
            "input_cardinality" => ToJson.toJson(observation#inputCardinality),
            "output_cardinality" => ToJson.toJson(observation#outputCardinality),
            "domain_cardinality" => ToJson.toJson(observation#domainCardinality),
            "expansion_ratio" => optionalFloat(observation#expansionRatio),
            "reach_fraction" => ToJson.toJson(observation#reachFraction),
            "extinct" => JBool(observation#extinct),
            "first_extinction_depth" => optionalInt(observation#firstExtinctionDepth),
            "semantic_state_id" => JString(stateId0),
            "same_as_input" => JBool(observation#sameAsInput)
        }
    }

    def optionalFloat(value: Option[Float64]): Json = match value {
        case None => JNull
        case Some(number) => ToJson.toJson(number)
    }

    def optionalInt(value: Option[Int32]): Json = match value {
        case None => JNull
        case Some(number) => ToJson.toJson(number)
    }

    def ratio(numerator: Int32, denominator: Int32): Float64 =
        if (denominator == 0) 0.0
        else Int32.toFloat64(numerator) / Int32.toFloat64(denominator)

    def identityColumns(): Vector[ScientificTable.Column] = Vector#{
        text("signature_protocol"), text("atlas_protocol"), text("repository"),
        text("base_revision"), text("source_tree_identity"), text("fact_identity"),
        text("snapshot_id")
    }

    def text(name: String): ScientificTable.Column =
        {name = name, kind = ScientificTable.ColumnType.Text, nullable = false}

    def textList(name: String): ScientificTable.Column =
        {name = name, kind = ScientificTable.ColumnType.TextList, nullable = false}

    def int32(name: String): ScientificTable.Column =
        {name = name, kind = ScientificTable.ColumnType.Int32, nullable = false}

    def optionalInt32(name: String): ScientificTable.Column =
        {name = name, kind = ScientificTable.ColumnType.Int32, nullable = true}

    def int64(name: String): ScientificTable.Column =
        {name = name, kind = ScientificTable.ColumnType.Int64, nullable = false}

    def optionalInt64(name: String): ScientificTable.Column =
        {name = name, kind = ScientificTable.ColumnType.Int64, nullable = true}

    def float64(name: String): ScientificTable.Column =
        {name = name, kind = ScientificTable.ColumnType.Float64, nullable = false}

    def optionalFloat64(name: String): ScientificTable.Column =
        {name = name, kind = ScientificTable.ColumnType.Float64, nullable = true}

    def boolean(name: String): ScientificTable.Column =
        {name = name, kind = ScientificTable.ColumnType.Boolean, nullable = false}
}
