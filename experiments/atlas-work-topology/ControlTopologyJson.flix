/// The control work-topology document (PREREGISTRATION.md §6, §4, §5).
///
/// `ControlTopology` owns the measurement; this module owns only its stable
/// JSON rendering. The document keeps the three channels separate: `basis` and
/// `regions` are direct admitted-relation statistics, `atlas` is the depth-<=2
/// File-domain Atlas output union, and `cell_cut_4` is the §5 ownership-cell cut
/// reported apart from the §4 ten-region partition. The `other` residual bucket
/// is always present.
mod ControlTopologyJson {
    use Util.Json
    use Util.Json.Json.{JArray, JBool, JObject, JString}
    use Util.Json.ToJson

    pub def str(value: String): Json = JString(value)
    pub def int(value: Int32): Json = ToJson.toJson(value)
    pub def real(value: Float64): Json = ToJson.toJson(value)
    pub def arr(items: Vector[Json]): Json = JArray(items)
    pub def obj(fields: Vector[(String, Json)]): Json = JObject(Vector.toMap(fields))

    pub def json(revision: String, sources: Vector[AcquisitionFacts.Source], world: Repository.World): String = {
        let edges = ControlTopology.regionEdges(world);
        obj(Vector#{
            ("protocol", str(ControlTopology.topologyProtocol())),
            ("region_protocol", str(ControlTopology.regionProtocol())),
            ("cell_protocol", str(ControlTopology.cellProtocol())),
            ("revision", str(revision)),
            ("basis", basisJson(world, edges)),
            ("languages", languagesJson(sources)),
            ("regions", regionsJson(world, edges)),
            ("other", otherJson(world, edges)),
            ("cuts", cutsJson(world, edges)),
            ("cell_cut_4", cellCutJson(ControlTopology.cellCut(ControlTopology.cellEdges(world)))),
            ("hotspots", hotspotsJson(world)),
            ("coherence", coherenceJson(world, edges)),
            ("atlas", atlasJson(world))
        }) |> Json.toCompactString
    }

    pub def basisJson(world: Repository.World, edges: Vector[(String, String)]): Json = {
        let cross = Vector.count(match (f, t) -> f != t, edges);
        obj(Vector#{
            ("admitted_files", int(Vector.length(world#files))),
            ("symbols", int(Vector.length(world#symbols))),
            ("defines", int(Set.size(world#defines))),
            ("use_edges", int(Vector.length(edges))),
            ("calls", int(Set.size(world#calls))),
            ("parents", int(Set.size(world#parents))),
            ("unresolved_imports", int(world#unresolvedImports)),
            ("unresolved_calls", int(world#unresolvedCalls)),
            ("cross_region_edges", int(cross)),
            ("cross_region_edge_ratio", real(ScientificTable.ratio(cross, Vector.length(edges)))),
            ("other_edges", int(Vector.count(match (f, t) -> f == "other" or t == "other", edges))),
            ("other_internal_edges", int(Vector.count(match (f, t) -> f == "other" and t == "other", edges)))
        })
    }

    pub def languagesJson(sources: Vector[AcquisitionFacts.Source]): Json =
        arr(Vector.map(language -> obj(Vector#{
            ("language", str(language)),
            ("files", int(Vector.count(source -> source#language == language, sources)))
        }), ControlTopology.languageNames()))

    pub def regionsJson(world: Repository.World, edges: Vector[(String, String)]): Json = {
        let nonEmpty = ControlTopology.nonEmptyRegions(world);
        let independent = Vector.count(region0 -> ControlTopology.independentlyTestable(edges, region0), nonEmpty);
        obj(Vector#{
            ("non_empty", int(Vector.length(nonEmpty))),
            ("independently_testable", int(independent)),
            ("rows", arr(Vector.map(region0 -> obj(Vector#{
                ("region", str(region0)),
                ("files", int(Vector.length(ControlTopology.regionFiles(world, region0)))),
                ("internal_edges", int(ControlTopology.internalEdges(edges, region0))),
                ("outgoing_edges", int(ControlTopology.outgoingEdges(edges, region0))),
                ("coherence", real(ControlTopology.coherence(edges, region0))),
                ("independently_testable", JBool(ControlTopology.independentlyTestable(edges, region0)))
            }), nonEmpty)))
        })
    }

    pub def otherJson(world: Repository.World, edges: Vector[(String, String)]): Json = {
        let otherPaths = ControlTopology.regionFiles(world, "other");
        obj(Vector#{
            ("files", int(Vector.length(otherPaths))),
            ("paths", arr(Vector.map(str, otherPaths))),
            ("edges_touching_other", int(Vector.count(match (f, t) -> f == "other" or t == "other", edges))),
            ("edges_within_other", int(Vector.count(match (f, t) -> f == "other" and t == "other", edges))),
            ("by_region", arr(Vector.map(region0 -> obj(Vector#{
                ("region", str(region0)),
                ("edges_to_other", int(Vector.count(match (f, t) ->
                    (f == region0 and t == "other") or (f == "other" and t == region0), edges)))
            }), ControlTopology.nonEmptyRegions(world))))
        })
    }

    pub def cutsJson(world: Repository.World, edges: Vector[(String, String)]): Json =
        arr(Vector.map(k -> {
            let groups = ControlTopology.regionGroups(world, k);
            let cross = Vector.count(match (f, t) -> ControlTopology.crosses(groups, f, t), edges);
            obj(Vector#{
                ("k", int(k)),
                ("cross_edges", int(cross)),
                ("fraction", real(ScientificTable.ratio(cross, Vector.length(edges)))),
                ("groups", arr(Vector.map(match (name, members0) -> obj(Vector#{
                    ("name", str(name)),
                    ("regions", arr(Vector.map(str, Vector.sort(Set.toVector(members0)))))
                }), groups)))
            })
        }, ControlTopology.cutDepths()))

    pub def cellCutJson(cut: ControlTopology.CellCut): Json =
        obj(Vector#{
            ("shared_edges", int(cut#shared)),
            ("considered_edges", int(cut#considered)),
            ("fraction", real(cut#fraction)),
            ("excluded_kernel_edges", int(cut#kernelEdges)),
            ("excluded_law_edges", int(cut#lawEdges)),
            ("excluded_other_edges", int(cut#otherEdges))
        })

    pub def hotspotsJson(world: Repository.World): Json = {
        let hotspots = ControlTopology.hotspotFiles(world);
        obj(Vector#{
            ("shared_hotspots", int(Vector.length(hotspots))),
            ("max_hotspot_pressure", int(ControlTopology.maxHotspotPressure(world))),
            ("files", arr(Vector.map(match (path, regions0, pressure) -> obj(Vector#{
                ("path", str(path)),
                ("importing_regions", arr(Vector.map(str, regions0))),
                ("pressure", int(pressure))
            }), hotspots)))
        })
    }

    pub def coherenceJson(world: Repository.World, edges: Vector[(String, String)]): Json = {
        let (region0, value) = ControlTopology.minCoherence(world, edges);
        obj(Vector#{
            ("min", real(value)),
            ("min_region", str(region0))
        })
    }

    pub def atlasJson(world: Repository.World): Json = {
        let blasts = ControlTopology.fileBlasts(world);
        let overlaps0 = ControlTopology.overlaps(world);
        let high = Vector.filter(overlap -> overlap#jaccard >= 0.5, overlaps0);
        obj(Vector#{
            ("family", str(ControlTopology.atlasFamily())),
            ("blast", obj(Vector#{
                ("median", int(ControlTopology.percentile(blasts, 50))),
                ("p90", int(ControlTopology.percentile(blasts, 90))),
                ("sample_count", int(Vector.length(blasts)))
            })),
            ("max_region_blast", real(ControlTopology.maxRegionBlast(world))),
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
}
