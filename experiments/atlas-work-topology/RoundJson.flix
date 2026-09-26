/// Stable JSON rendering for the Round 1 candidate measurement
/// (PREREGISTRATION.md §9, §10; VAL-HC1-002, VAL-HC1-003).
///
/// The instrument owns the numbers; this module owns only their deterministic
/// rendering, so the committed artifacts can be re-derived and compared
/// byte-for-byte by a law test.
mod RoundJson {
    use Util.Json
    use Util.Json.Json.{JArray, JBool, JObject, JString}
    use Util.Json.ToJson

    pub def str(value: String): Json = JString(value)
    pub def int(value: Int32): Json = ToJson.toJson(value)
    pub def real(value: Float64): Json = ToJson.toJson(value)
    pub def bool(value: Bool): Json = JBool(value)
    pub def arr(items: Vector[Json]): Json = JArray(items)
    pub def obj(fields: Vector[(String, Json)]): Json = JObject(Vector.toMap(fields))

    // ---- the round identity map (§9, O6) ----

    pub def identityJson(
        revision: String,
        controlRevision: String,
        admittedFiles: Int32,
        round0: RoundIdentity.Round
    ): String =
        obj(Vector#{
            ("protocol", str(RoundIdentity.protocol())),
            ("revision", str(revision)),
            ("control_revision", str(controlRevision)),
            ("control_basis_files", int(Vector.length(round0#entries))),
            ("admitted_files", int(admittedFiles)),
            ("counts", obj(Vector.map(match (movement, count) -> (movement, int(count)),
                Vector.append(RoundIdentity.counts(round0), Vector#{("new", Vector.length(round0#newPaths))})))),
            ("entries", arr(Vector.map(identityEntry, round0#entries))),
            ("new_paths", arr(Vector.map(str, round0#newPaths))),
            ("collisions", arr(Vector.map(str, round0#collisions))),
            ("dropped", arr(Vector.map(str, round0#dropped)))
        }) |> Json.toCompactString

    def identityEntry(entry: RoundIdentity.Entry): Json =
        obj(Vector#{
            ("logical_id", str(entry#logicalId)),
            ("control_path", str(entry#controlPath)),
            ("current_path", str(entry#currentPath)),
            ("control_region", str(entry#controlRegion)),
            ("current_region", str(entry#currentRegion)),
            ("control_cell", str(entry#controlCell)),
            ("ownership_cell", str(entry#ownershipCell)),
            ("movement", str(entry#movement))
        })

    // ---- the round static work-topology (§4, §5, §6) ----

    pub def topologyJson(
        revision: String,
        controlRevision: String,
        admittedFiles: Int32,
        round0: RoundIdentity.Round,
        world: Repository.World,
        mapping: RoundTopology.Mapping
    ): String = {
        let edges = RoundTopology.regionEdges(world, mapping);
        let cross = Vector.count(match (f, t) -> f != t, edges);
        obj(Vector#{
            ("protocol", str(topologyProtocol())),
            ("region_protocol", str(ControlTopology.regionProtocol())),
            ("cell_protocol", str(cellAmendment())),
            ("signature_protocol", str(ControlSignature.signatureProtocol())),
            ("revision", str(revision)),
            ("control_revision", str(controlRevision)),
            ("context", obj(Vector#{
                ("control_basis_files", int(Vector.length(round0#entries))),
                ("admitted_files", int(admittedFiles)),
                ("counts", obj(Vector.map(match (movement, count) -> (movement, int(count)),
                    Vector.append(RoundIdentity.counts(round0),
                        Vector#{("new", Vector.length(round0#newPaths))}))))
            })),
            ("basis", obj(Vector#{
                ("use_edges", int(Vector.length(edges))),
                ("cross_region_edges", int(cross)),
                ("cross_region_edge_ratio", real(ScientificTable.ratio(cross, Vector.length(edges)))),
                ("other_edges", int(Vector.count(match (f, t) -> f == "other" or t == "other", edges)))
            })),
            ("regions", regionsJson(world, mapping, edges)),
            ("cuts", cutsJson(world, mapping, edges)),
            ("cell_cut_4", cellCutJson(RoundTopology.cellCut(world, mapping))),
            ("hotspots", hotspotsJson(world, mapping)),
            ("coherence", coherenceJson(world, mapping)),
            ("atlas", atlasJson(world, mapping))
        }) |> Json.toCompactString
    }

    pub def topologyProtocol(): String = "attuneflix-round-topology-v1"
    pub def cellAmendment(): String = "attuneflix-cells-v1-round1"

    def regionsJson(world: Repository.World, mapping: RoundTopology.Mapping, edges: Vector[(String, String)]): Json = {
        let nonEmpty = RoundTopology.nonEmptyRegions(world, mapping);
        obj(Vector#{
            ("non_empty", int(Vector.length(nonEmpty))),
            ("independently_testable", int(Vector.length(RoundTopology.independentlyTestableRegions(world, mapping)))),
            ("rows", arr(Vector.map(region0 -> obj(Vector#{
                ("region", str(region0)),
                ("files", int(Vector.length(RoundTopology.regionFiles(world, mapping, region0)))),
                ("internal_edges", int(ControlTopology.internalEdges(edges, region0))),
                ("outgoing_edges", int(ControlTopology.outgoingEdges(edges, region0))),
                ("coherence", real(ControlTopology.coherence(edges, region0))),
                ("independently_testable", bool(ControlTopology.independentlyTestable(edges, region0)))
            }), nonEmpty)))
        })
    }

    def cutsJson(world: Repository.World, mapping: RoundTopology.Mapping, edges: Vector[(String, String)]): Json =
        arr(Vector.map(k -> {
            let groups = RoundTopology.regionGroups(world, mapping, k);
            obj(Vector#{
                ("k", int(k)),
                ("cross_edges", int(Vector.count(match (f, t) -> ControlTopology.crosses(groups, f, t), edges))),
                ("fraction", real(ScientificTable.ratio(
                    Vector.count(match (f, t) -> ControlTopology.crosses(groups, f, t), edges), Vector.length(edges)))),
                ("groups", arr(Vector.map(match (name, members0) -> obj(Vector#{
                    ("name", str(name)),
                    ("regions", arr(Vector.map(str, Vector.sort(Set.toVector(members0)))))
                }), groups)))
            })
        }, ControlTopology.cutDepths()))

    def cellCutJson(cut: ControlTopology.CellCut): Json =
        obj(Vector#{
            ("shared_edges", int(cut#shared)),
            ("considered_edges", int(cut#considered)),
            ("fraction", real(cut#fraction)),
            ("excluded_kernel_edges", int(cut#kernelEdges)),
            ("excluded_law_edges", int(cut#lawEdges)),
            ("excluded_other_edges", int(cut#otherEdges))
        })

    def hotspotsJson(world: Repository.World, mapping: RoundTopology.Mapping): Json = {
        let hotspots = RoundTopology.hotspotFiles(world, mapping);
        obj(Vector#{
            ("shared_hotspots", int(Vector.length(hotspots))),
            ("max_hotspot_pressure", int(RoundTopology.maxHotspotPressure(world, mapping))),
            ("files", arr(Vector.map(match (path, regions0, pressure) -> obj(Vector#{
                ("path", str(path)),
                ("importing_regions", arr(Vector.map(str, regions0))),
                ("pressure", int(pressure))
            }), hotspots)))
        })
    }

    def coherenceJson(world: Repository.World, mapping: RoundTopology.Mapping): Json = {
        let (region0, value) = RoundTopology.minCoherence(world, mapping);
        obj(Vector#{
            ("min", real(value)),
            ("min_region", str(region0))
        })
    }

    def atlasJson(world: Repository.World, mapping: RoundTopology.Mapping): Json = {
        let blasts = RoundTopology.fileBlasts(world);
        let overlaps0 = RoundTopology.overlaps(world, mapping);
        let high = Vector.filter(overlap -> overlap#jaccard >= 0.5, overlaps0);
        obj(Vector#{
            ("family", str(ControlTopology.atlasFamily())),
            ("blast", obj(Vector#{
                ("median", int(ControlTopology.percentile(blasts, 50))),
                ("p90", int(ControlTopology.percentile(blasts, 90))),
                ("sample_count", int(Vector.length(blasts)))
            })),
            ("max_region_blast", real(RoundTopology.maxRegionBlast(world, mapping))),
            ("region_pair_jaccard", obj(Vector#{
                ("max", real(Vector.foldLeft((best, overlap) ->
                    if (overlap#jaccard > best) overlap#jaccard else best, 0.0, overlaps0))),
                ("high_overlap_pairs", int(Vector.length(high))),
                ("pairs", arr(Vector.map(overlap -> obj(Vector#{
                    ("left", str(overlap#left)),
                    ("right", str(overlap#right)),
                    ("jaccard", real(overlap#jaccard))
                }), high)))
            }))
        })
    }

    // ---- the signature-preservation oracle (§10) ----

    /// Frozen basis edges re-admitted at the candidate paths do not reproduce,
    /// and the candidate edges they predict instead (§6.2 identity layer).
    def basisEdgeDriftJson(
        world: Repository.World,
        candidateWorld: Repository.World,
        round0: RoundIdentity.Round
    ): Json = {
        let translated = RoundOracle.translatedEdgePaths(world, RoundIdentity.mapping(round0));
        let (lost, gained) = RoundOracle.basisEdgeDrift(candidateWorld, translated);
        obj(Vector#{
            ("translated_control_edges", int(Set.size(translated))),
            ("lost_edges", arr(Vector.map(pairJson, lost))),
            ("gained_edges", arr(Vector.map(pairJson, gained)))
        })
    }

    def pairJson(pair: (String, String)): Json = match pair {
        case (source, target) => arr(Vector#{str(source), str(target)})
    }

    pub def oracleJson(
        revision: String,
        controlRevision: String,
        controlSources: Vector[AcquisitionFacts.Source],
        controlFacts: Vector[AcquisitionFacts.FactRow],
        world: Repository.World,
        candidateWorld: Repository.World,
        round0: RoundIdentity.Round,
        control: ControlSignature.Landmarks,
        candidate: ControlSignature.Landmarks
    ): String = {
        let landmarkComparisons = RoundOracle.landmarkComparisons(control, candidate);
        let comparisons = Vector.append(landmarkComparisons, Vector#{RoundOracle.reachComparison(control, candidate)});
        let identityVerdicts = RoundOracle.identityVerdicts(round0);
        let modified = RoundOracle.modifiedPaths(round0);
        obj(Vector#{
            ("protocol", str(RoundOracle.protocol())),
            ("signature_protocol", str(ControlSignature.signatureProtocol())),
            ("atlas_protocol", str(ControlSignature.atlasProtocol())),
            ("revision", str(revision)),
            ("control_revision", str(controlRevision)),
            ("grammar", obj(Vector#{
                ("routes", obj(Vector.map(match (domain, count) -> (domain, int(count)), RoundOracle.grammarRoutes()))),
                ("depths", arr(Vector.map(match (depth, count) -> obj(Vector#{
                    ("depth", int(depth)), ("routes", int(count))
                }), RoundOracle.grammarDepths())))
            })),
            ("landmarks", obj(Vector#{
                ("control", landmarksJson(control)),
                ("candidate", landmarksJson(candidate))
            })),
            ("basis_graph", obj(Vector#{
                ("control_files", int(Vector.length(world#files))),
                ("candidate_files", int(Vector.length(candidateWorld#files))),
                ("control_symbols", int(Vector.length(world#symbols))),
                ("candidate_symbols", int(Vector.length(candidateWorld#symbols))),
                ("control_use_edges", int(Set.size(world#imports))),
                ("candidate_use_edges", int(Set.size(candidateWorld#imports))),
                ("control_defines", int(Set.size(world#defines))),
                ("candidate_defines", int(Set.size(candidateWorld#defines))),
                ("control_calls", int(Set.size(world#calls))),
                ("candidate_calls", int(Set.size(candidateWorld#calls))),
                ("control_unresolved_imports", int(world#unresolvedImports)),
                ("candidate_unresolved_imports", int(candidateWorld#unresolvedImports))
            })),
            ("basis_edge_drift", basisEdgeDriftJson(world, candidateWorld, round0)),
            ("comparisons", arr(Vector.map(comparisonJson, comparisons))),            ("reach_curve", arr(Vector.map(match (depth, c, v) -> obj(Vector#{
                ("depth", int(depth)), ("control", real(c)), ("candidate", real(v))
            }), RoundOracle.reachCurve(control, candidate)))),
            ("identity_verdicts", obj(Vector.map(match (rule, ok) -> (rule, bool(ok)), identityVerdicts))),
            ("modified_paths", arr(Vector.map(str, modified))),
            ("modified_basis_edges", int(RoundOracle.incidentEdges(world, modified))),
            ("control_basis_files", int(Vector.length(controlSources))),
            ("control_basis_facts", int(Vector.length(controlFacts))),
            ("signature_ok", bool(Vector.forAll(comparison -> comparison#ok, comparisons)))
        }) |> Json.toCompactString
    }

    def landmarksJson(value: ControlSignature.Landmarks): Json =
        obj(Vector#{
            ("mean_coverage", arr(Vector.map(real, value#meanCoverage))),
            ("depth7_reach", real(value#depth7Reach)),
            ("D50", int(value#d50)),
            ("D80", int(value#d80)),
            ("D90", int(value#d90)),
            ("D95", int(value#d95))
        })

    def comparisonJson(comparison: RoundOracle.Comparison): Json =
        obj(Vector#{
            ("metric", str(comparison#metric)),
            ("control", real(comparison#control)),
            ("candidate", real(comparison#candidate)),
            ("delta", real(comparison#delta)),
            ("threshold", real(comparison#threshold)),
            ("ok", bool(comparison#ok))
        })
}
