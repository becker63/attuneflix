/// Canonical typed Parquet schemas for the Atlas census. These declarations
/// are the scientific data model; the Arrow boundary only realizes them.
pub mod Atlas.Signature.Table {
    use ScientificTable.Value
    use ScientificTable.Columns.{text, optionalText, textList, int32, optionalInt32}
    use ScientificTable.Columns.{int64, optionalInt64, float64, optionalFloat64, boolean}

    pub type alias SnapshotIdentity = {
        signatureProtocol  = String,
        atlasProtocol      = String,
        repository         = String,
        baseRevision       = String,
        sourceTreeIdentity = String,
        factIdentity       = String,
        snapshotId         = String
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

    /// Materialize one exact row per logical Atlas route. The route and state
    /// digests are scientific identities, not evaluator allocation IDs.
    pub def observationRows(
        snapshot: SnapshotIdentity,
        seed: Atlas.Signature.Seed,
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
        seed: Atlas.Signature.Seed,
        signature: Atlas.Signature.Signature
    ): ScientificTable.Row = {
        let evaluations = signature#physicalTransitions;
        let reuses = signature#transitionReuses;
        let logical = signature#logicalPrograms;
        let unique = signature#uniqueStates;
        Map#{
            "signature_protocol" => Value.Text(snapshot#signatureProtocol),
            "atlas_protocol" => Value.Text(snapshot#atlasProtocol),
            "repository" => Value.Text(snapshot#repository),
            "base_revision" => Value.Text(snapshot#baseRevision),
            "source_tree_identity" => Value.Text(snapshot#sourceTreeIdentity),
            "fact_identity" => Value.Text(snapshot#factIdentity),
            "snapshot_id" => Value.Text(snapshot#snapshotId),
            "seed_domain" => Value.Text(Atlas.Signature.domainName(seed#domain)),
            "seed_identity" => Value.Text(seed#identity),
            "seed_ordinal" => Value.Int32(seed#ordinal),
            "logical_routes" => Value.Int64(Int32.toInt64(logical)),
            "unique_semantic_states" => Value.Int64(Int32.toInt64(unique)),
            "physical_transition_requests" => Value.Int64(Int32.toInt64(evaluations + reuses)),
            "physical_transition_evaluations" => Value.Int64(Int32.toInt64(evaluations)),
            "physical_transition_reuses" => Value.Int64(Int32.toInt64(reuses)),
            "logical_per_unique_state" => Value.Float64(ScientificTable.ratio(logical, unique)),
            "logical_per_physical_evaluation" => Value.Float64(ScientificTable.ratio(logical, evaluations)),
            "memo_cells" => Value.Int64(Int32.toInt64(evaluations)),
            "compiled_dag_nodes" => Value.Null
        }
    }

    pub def snapshotRow(
        snapshot: SnapshotIdentity,
        repository: Repository.World,
        manifestCaseCount: Int32
    ): ScientificTable.Row = Map#{
        "signature_protocol" => Value.Text(snapshot#signatureProtocol),
        "atlas_protocol" => Value.Text(snapshot#atlasProtocol),
        "repository" => Value.Text(snapshot#repository),
        "base_revision" => Value.Text(snapshot#baseRevision),
        "source_tree_identity" => Value.Text(snapshot#sourceTreeIdentity),
        "fact_identity" => Value.Text(snapshot#factIdentity),
        "snapshot_id" => Value.Text(snapshot#snapshotId),
        "file_count" => Value.Int64(Int32.toInt64(Vector.length(repository#files))),
        "symbol_count" => Value.Int64(Int32.toInt64(Vector.length(repository#symbols))),
        "defines_count" => Value.Int64(Int32.toInt64(Set.size(repository#defines))),
        "imports_count" => Value.Int64(Int32.toInt64(Set.size(repository#imports))),
        "calls_count" => Value.Int64(Int32.toInt64(Set.size(repository#calls))),
        "parent_count" => Value.Int64(Int32.toInt64(Set.size(repository#parents))),
        "manifest_case_count" => Value.Int64(Int32.toInt64(manifestCaseCount))
    }

    def observationRow(
        snapshot: SnapshotIdentity,
        seed: Atlas.Signature.Seed,
        observation: Atlas.Signature.Observation,
        stateId0: String
    ): ScientificTable.Row \ IO = {
        let routeId = Atlas.Signature.routeId(observation#program);
        let atoms = Vector.map(Atlas.Signature.atomName, observation#program#steps);
        Map#{
            "signature_protocol" => Value.Text(snapshot#signatureProtocol),
            "atlas_protocol" => Value.Text(snapshot#atlasProtocol),
            "repository" => Value.Text(snapshot#repository),
            "base_revision" => Value.Text(snapshot#baseRevision),
            "source_tree_identity" => Value.Text(snapshot#sourceTreeIdentity),
            "fact_identity" => Value.Text(snapshot#factIdentity),
            "snapshot_id" => Value.Text(snapshot#snapshotId),
            "seed_domain" => Value.Text(Atlas.Signature.domainName(seed#domain)),
            "seed_identity" => Value.Text(seed#identity),
            "seed_ordinal" => Value.Int32(seed#ordinal),
            "route_id" => Value.Text(routeId),
            "route_atoms" => Value.TextList(atoms),
            "depth" => Value.Int32(observation#depth),
            "first_atom" => Value.Text(Vector.get(0, atoms)),
            "last_atom" => Value.Text(Vector.get(Vector.length(atoms) - 1, atoms)),
            "terminal_domain" => Value.Text(Atlas.Signature.domainName(
                Atlas.stateDomain(observation#output))),
            "input_cardinality" => Value.Int64(Int32.toInt64(observation#inputCardinality)),
            "output_cardinality" => Value.Int64(Int32.toInt64(observation#outputCardinality)),
            "domain_cardinality" => Value.Int64(Int32.toInt64(observation#domainCardinality)),
            "expansion_ratio" => ScientificTable.optionalFloat64Value(observation#expansionRatio),
            "reach_fraction" => Value.Float64(observation#reachFraction),
            "extinct" => Value.Boolean(observation#extinct),
            "first_extinction_depth" => ScientificTable.optionalInt32Value(observation#firstExtinctionDepth),
            "semantic_state_id" => Value.Text(stateId0),
            "same_as_input" => Value.Boolean(observation#sameAsInput)
        }
    }

    def identityColumns(): Vector[ScientificTable.Column] = Vector#{
        text("signature_protocol"), text("atlas_protocol"), text("repository"),
        text("base_revision"), text("source_tree_identity"), text("fact_identity"),
        text("snapshot_id")
    }
}
