/** Explain one projected dependency from the exact rows that back it. */
import { linkRelation, type ViewerGraph } from "../../../projection/src/graph.ts";
import type { ProjectedDependency } from "./wires.ts";

export interface ExactContribution {
  readonly row: number;
  readonly sourceId: string;
  readonly source: string;
  readonly targetId: string;
  readonly target: string;
}

export interface WireInspection {
  readonly sourceId: string;
  readonly source: string;
  readonly targetId: string;
  readonly target: string;
  readonly relation: "imports" | "calls";
  readonly multiplicity: number;
  readonly uniqueSources: number;
  readonly uniqueTargets: number;
  readonly boundary: true;
  readonly contributions: readonly ExactContribution[];
  readonly remaining: number;
}

const linkByRow = new WeakMap<ViewerGraph, ReadonlyMap<number, number>>();

function rowIndex(graph: ViewerGraph): ReadonlyMap<number, number> {
  const cached = linkByRow.get(graph);
  if (cached !== undefined) return cached;
  const index = new Map<number, number>();
  for (let link = 0; link < graph.linkCount; link++) {
    const row = graph.linkRows[link];
    if (row === undefined || index.has(row)) throw new Error(`duplicate or missing relation row ${row}`);
    index.set(row, link);
  }
  linkByRow.set(graph, index);
  return index;
}

function humanName(graph: ViewerGraph, index: number): string {
  return graph.pointNames[index] ?? graph.pointPaths[index] ??
    graph.pointLabels[index] ?? graph.pointIds[index] ?? "";
}

/**
 * Every displayed count is independently recovered from backing relations
 * rows. `limit` bounds the concrete list, never the aggregate measurements.
 */
export function inspectWire(graph: ViewerGraph, wire: ProjectedDependency, limit = 25): WireInspection {
  if (wire.multiplicity !== wire.provenance.length) {
    throw new Error(`wire multiplicity ${wire.multiplicity} differs from ${wire.provenance.length} backing rows`);
  }
  const rows = rowIndex(graph);
  const sourceIds = new Set<string>();
  const targetIds = new Set<string>();
  const contributions: ExactContribution[] = [];
  for (const row of wire.provenance) {
    const link = rows.get(row);
    if (link === undefined || linkRelation(graph, link) !== wire.relation) {
      throw new Error(`wire ${wire.relation} has no matching exact relation row ${row}`);
    }
    const sourceIndex = graph.linkSourceIndices[link];
    const targetIndex = graph.linkTargetIndices[link];
    if (sourceIndex === undefined || targetIndex === undefined) throw new Error(`unresolved row ${row}`);
    const sourceId = graph.pointIds[sourceIndex];
    const targetId = graph.pointIds[targetIndex];
    if (sourceId === undefined || targetId === undefined) throw new Error(`unknown endpoint in row ${row}`);
    sourceIds.add(sourceId);
    targetIds.add(targetId);
    if (contributions.length < Math.max(0, limit)) {
      contributions.push({
        row,
        sourceId,
        source: humanName(graph, sourceIndex),
        targetId,
        target: humanName(graph, targetIndex),
      });
    }
  }
  return {
    sourceId: wire.source,
    source: humanName(graph, wire.sourceIndex),
    targetId: wire.target,
    target: humanName(graph, wire.targetIndex),
    relation: wire.relation,
    multiplicity: wire.multiplicity,
    uniqueSources: sourceIds.size,
    uniqueTargets: targetIds.size,
    boundary: true,
    contributions,
    remaining: wire.multiplicity - contributions.length,
  };
}
