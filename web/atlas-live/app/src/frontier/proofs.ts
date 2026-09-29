/** On-demand witnesses for the derived Flix structural relations. Never graph edges. */
import { linkRelation, type Csr, type ViewerGraph } from "../../../projection/src/graph.ts";

export type LensRelation = "SameFile" | "ImportNeighbor" | "ImporterNeighbor" | "RepositoryAdjacent";
export const LENS_ORDER: readonly LensRelation[] = ["SameFile", "ImportNeighbor", "ImporterNeighbor", "RepositoryAdjacent"];

export interface ProofStep {
  readonly relation: "defines" | "imports" | "parent";
  readonly row: number;
  readonly sourceId: string;
  readonly source: string;
  readonly targetId: string;
  readonly target: string;
}

export interface LensProof {
  readonly relation: LensRelation;
  readonly sourceId: string;
  readonly source: string;
  readonly targetId: string;
  readonly target: string;
  /** Basis facts in the same order as the Flix rule body. */
  readonly steps: readonly ProofStep[];
}

function* links(csr: Csr, index: number): Iterable<number> {
  const end = csr.offsets[index + 1] ?? 0;
  for (let slot = csr.offsets[index] ?? 0; slot < end; slot++) {
    const link = csr.links[slot];
    if (link !== undefined) yield link;
  }
}

function humanName(graph: ViewerGraph, index: number): string {
  return graph.pointNames[index] ?? graph.pointPaths[index] ?? graph.pointLabels[index] ?? graph.pointIds[index] ?? "";
}

function step(graph: ViewerGraph, link: number): ProofStep {
  const sourceIndex = graph.linkSourceIndices[link];
  const targetIndex = graph.linkTargetIndices[link];
  const row = graph.linkRows[link];
  const relation = linkRelation(graph, link);
  if (sourceIndex === undefined || targetIndex === undefined || row === undefined || relation === "calls") {
    throw new Error(`invalid basis link for structural proof: ${link}`);
  }
  return {
    relation,
    row,
    sourceId: graph.pointIds[sourceIndex] ?? "",
    source: humanName(graph, sourceIndex),
    targetId: graph.pointIds[targetIndex] ?? "",
    target: humanName(graph, targetIndex),
  };
}

/** A deterministic, bounded list of exact witnesses starting at one selected point. */
export function deriveLensProofs(graph: ViewerGraph, sourceIndex: number, limitPerRelation = 8): readonly LensProof[] {
  if (sourceIndex < 0 || sourceIndex >= graph.pointCount || limitPerRelation <= 0) return [];
  const counts = new Map<LensRelation, number>(LENS_ORDER.map((kind) => [kind, 0]));
  const seen = new Set<string>();
  const out: LensProof[] = [];
  const add = (relation: LensRelation, targetIndex: number, evidence: readonly number[]): void => {
    if ((counts.get(relation) ?? 0) >= limitPerRelation) return;
    const targetId = graph.pointIds[targetIndex];
    const sourceId = graph.pointIds[sourceIndex];
    if (targetId === undefined || sourceId === undefined) return;
    const key = `${relation}:${targetId}`;
    if (seen.has(key)) return;
    seen.add(key);
    counts.set(relation, (counts.get(relation) ?? 0) + 1);
    out.push({
      relation,
      sourceId,
      source: humanName(graph, sourceIndex),
      targetId,
      target: humanName(graph, targetIndex),
      steps: evidence.map((link) => step(graph, link)),
    });
  };

  // Flix: SameFile(x,y) :- Defines(file,x), Defines(file,y).
  //       ImportNeighbor(x,y) :- Defines(source,x), Imports(source,target), Defines(target,y).
  //       ImporterNeighbor(x,y) :- Defines(target,x), Imports(source,target), Defines(source,y).
  for (const defining of links(graph.adjacency.defines.in, sourceIndex)) {
    const file = graph.linkSourceIndices[defining];
    if (file === undefined) continue;
    for (const other of links(graph.adjacency.defines.out, file)) {
      const target = graph.linkTargetIndices[other];
      if (target !== undefined) add("SameFile", target, [defining, other]);
    }
    for (const imported of links(graph.adjacency.imports.out, file)) {
      const targetFile = graph.linkTargetIndices[imported];
      if (targetFile === undefined) continue;
      for (const other of links(graph.adjacency.defines.out, targetFile)) {
        const target = graph.linkTargetIndices[other];
        if (target !== undefined) add("ImportNeighbor", target, [defining, imported, other]);
      }
    }
    for (const importing of links(graph.adjacency.imports.in, file)) {
      const sourceFile = graph.linkSourceIndices[importing];
      if (sourceFile === undefined) continue;
      for (const other of links(graph.adjacency.defines.out, sourceFile)) {
        const target = graph.linkTargetIndices[other];
        if (target !== undefined) add("ImporterNeighbor", target, [defining, importing, other]);
      }
    }
  }

  // Both Flix RepositoryAdjacent rules preserve the actual Parent edge direction.
  for (const parent of links(graph.adjacency.parent.out, sourceIndex)) {
    const target = graph.linkTargetIndices[parent];
    if (target !== undefined) add("RepositoryAdjacent", target, [parent]);
  }
  for (const child of links(graph.adjacency.parent.in, sourceIndex)) {
    const target = graph.linkSourceIndices[child];
    if (target !== undefined) add("RepositoryAdjacent", target, [child]);
  }
  return out;
}
