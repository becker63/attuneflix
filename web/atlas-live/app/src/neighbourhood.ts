/**
 * Hover neighbourhood over the projected CSR adjacency. All relations are
 * enabled in this slice, so the highlight is the hovered point, its incident
 * links, and the points at the other end of those links (depth 1).
 *
 * The highlight is computed from the projection's typed adjacency, not from the
 * renderer, so the diagnosed sets never disagree with the world data.
 */
import type { ViewerGraph } from "../../projection/src/graph.ts";
import { RELATION_ORDER, type Relation } from "../../projection/src/relation.ts";

export interface Highlight {
  /** Renderer indices, ascending, always including the hovered point. */
  readonly points: readonly number[];
  /** Link indices, ascending. */
  readonly links: readonly number[];
}

export const EMPTY_HIGHLIGHT: Highlight = { points: [], links: [] };

export interface DirectionalCounts {
  readonly in: number;
  readonly out: number;
}

export type IncidentCounts = Record<Relation, DirectionalCounts>;

/** Incident link counts of one point, per relation and per direction. */
export function incidentCounts(graph: ViewerGraph, index: number): IncidentCounts {
  const counts: Record<Relation, DirectionalCounts> = {
    defines: { in: 0, out: 0 },
    imports: { in: 0, out: 0 },
    calls: { in: 0, out: 0 },
    parent: { in: 0, out: 0 },
  };
  for (const relation of RELATION_ORDER) {
    const adjacency = graph.adjacency[relation];
    const out = adjacency.out.offsets[index + 1]! - adjacency.out.offsets[index]!;
    const inb = adjacency.in.offsets[index + 1]! - adjacency.in.offsets[index]!;
    counts[relation] = { in: inb, out };
  }
  return counts;
}

/** Total incident links of one point over the given relations. */
export function degree(graph: ViewerGraph, index: number, enabled: readonly Relation[]): number {
  let total = 0;
  for (const relation of enabled) {
    const adjacency = graph.adjacency[relation];
    total += adjacency.out.offsets[index + 1]! - adjacency.out.offsets[index]!;
    total += adjacency.in.offsets[index + 1]! - adjacency.in.offsets[index]!;
  }
  return total;
}

/**
 * Depth-1 neighbourhood of `index` over `enabled` relations: the point itself,
 * every neighbour at the other end of an incident link, and the incident links.
 * Self-loops are counted once.
 */
export function neighbourhood(graph: ViewerGraph, index: number, enabled: readonly Relation[]): Highlight {
  const points = new Set<number>([index]);
  const links = new Set<number>();
  for (const relation of enabled) {
    const adjacency = graph.adjacency[relation];
    collect(adjacency.out, index, points, links);
    collect(adjacency.in, index, points, links);
  }
  return { points: [...points].toSorted((a, b) => a - b), links: [...links].toSorted((a, b) => a - b) };
}

function collect(
  csr: { readonly offsets: Uint32Array; readonly points: Uint32Array; readonly links: Uint32Array },
  index: number,
  points: Set<number>,
  links: Set<number>,
): void {
  const start = csr.offsets[index]!;
  const end = csr.offsets[index + 1]!;
  for (let slot = start; slot < end; slot++) {
    const neighbour = csr.points[slot]!;
    const link = csr.links[slot]!;
    points.add(neighbour);
    links.add(link);
  }
}

/** Point ids for a highlight, for the diagnostics hook. */
export function highlightIds(graph: ViewerGraph, highlight: Highlight): string[] {
  return highlight.points.map((point) => graph.pointIds[point] ?? "");
}
