import type { RelationAdjacency, ViewerGraph } from "../src/graph.ts";
import { RELATION_ORDER } from "../src/relation.ts";

/** A plain, JSON-comparable view of a graph, for determinism checks. */
export function graphSnapshot(graph: ViewerGraph): unknown {
  const adjacency: Record<string, unknown> = {};
  for (const relation of RELATION_ORDER) {
    const adj: RelationAdjacency = graph.adjacency[relation];
    adjacency[relation] = {
      out: { offsets: [...adj.out.offsets], points: [...adj.out.points], links: [...adj.out.links] },
      in: { offsets: [...adj.in.offsets], points: [...adj.in.points], links: [...adj.in.links] },
    };
  }
  return {
    pointIds: [...graph.pointIds],
    pointDomains: [...graph.pointDomains],
    pointEntityIds: [...graph.pointEntityIds],
    pointLabels: [...graph.pointLabels],
    pointPaths: [...graph.pointPaths],
    pointNames: [...graph.pointNames],
    pointStartBytes: [...graph.pointStartBytes],
    pointEndBytes: [...graph.pointEndBytes],
    linkRelations: [...graph.linkRelations],
    linkRows: [...graph.linkRows],
    linkSourceDomains: [...graph.linkSourceDomains],
    linkSourceIds: [...graph.linkSourceIds],
    linkTargetDomains: [...graph.linkTargetDomains],
    linkTargetIds: [...graph.linkTargetIds],
    linkSourceIndices: [...graph.linkSourceIndices],
    linkTargetIndices: [...graph.linkTargetIndices],
    relationCounts: graph.relationCounts,
    adjacency,
    provenance: graph.provenance,
  };
}
