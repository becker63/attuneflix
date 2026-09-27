/**
 * Neighbourhoods over the projected CSR adjacency. Only the relation adjacency
 * of the *enabled* relations is ever read, so a disabled relation cannot
 * contribute a point or a link to any highlight, and the depth control expands
 * the highlight by BFS hops over those same adjacency rows.
 *
 * The highlights are computed from the projection's typed adjacency, not from
 * the renderer, so the diagnosed sets never disagree with the world data.
 */
import type { ViewerGraph } from "../../projection/src/graph.ts";
import { RELATION_ORDER, type Relation } from "../../projection/src/relation.ts";
import { clampDepth } from "./selection.ts";

export interface Highlight {
  /** Renderer indices, ascending, always including the hovered point. */
  readonly points: readonly number[];
  /** Link indices, ascending. */
  readonly links: readonly number[];
}

export const EMPTY_HIGHLIGHT: Highlight = { points: [], links: [] };

/** Pointwise union of two highlights, in ascending order. */
export function mergeHighlights(a: Highlight, b: Highlight): Highlight {
  if (b.points.length === 0 && b.links.length === 0) return a;
  if (a.points.length === 0 && a.links.length === 0) return b;
  return {
    points: unionSorted(a.points, b.points),
    links: unionSorted(a.links, b.links),
  };
}

function unionSorted(a: readonly number[], b: readonly number[]): number[] {
  return [...new Set([...a, ...b])].toSorted((x, y) => x - y);
}

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
 * Neighbourhood of `index` over `enabled` relations, expanded by `depth` BFS
 * hops: the points reachable within `depth` hops, and the links traversed while
 * collecting them. Depth 1 is exactly the direct neighbourhood.
 */
export function neighbourhoodAtDepth(
  graph: ViewerGraph,
  index: number,
  enabled: readonly Relation[],
  depth: number,
): Highlight {
  return multiSourceHighlight(graph, [index], enabled, depth);
}

/** Depth-1 neighbourhood of `index` over `enabled` relations. */
export function neighbourhood(graph: ViewerGraph, index: number, enabled: readonly Relation[]): Highlight {
  return multiSourceHighlight(graph, [index], enabled, 1);
}

/**
 * Union of the `depth`-hop neighbourhoods of every source index, over the
 * enabled relations. Sources are always included, even when they have no links
 * under the filter, so a selected isolated point stays in its own highlight.
 */
export function multiSourceHighlight(
  graph: ViewerGraph,
  sources: readonly number[],
  enabled: readonly Relation[],
  depth: number,
): Highlight {
  const points = new Set<number>();
  let frontier: number[] = [];
  for (const source of sources) {
    if (points.has(source)) continue;
    points.add(source);
    frontier.push(source);
  }
  const links = new Set<number>();
  const hops = clampDepth(depth);
  for (let hop = 0; hop < hops && frontier.length > 0; hop++) {
    const next: number[] = [];
    for (const point of frontier) {
      for (const relation of enabled) {
        const adjacency = graph.adjacency[relation];
        expand(adjacency.out, point, points, links, next);
        expand(adjacency.in, point, points, links, next);
      }
    }
    frontier = next;
  }
  return {
    points: [...points].toSorted((a, b) => a - b),
    links: [...links].toSorted((a, b) => a - b),
  };
}

/** Incident link indices of every point in `sources`, under the enabled relations. */
export function incidentLinks(
  graph: ViewerGraph,
  sources: readonly number[],
  enabled: readonly Relation[],
): number[] {
  const links = new Set<number>();
  for (const source of sources) {
    for (const relation of enabled) {
      const adjacency = graph.adjacency[relation];
      collectLinks(adjacency.out, source, links);
      collectLinks(adjacency.in, source, links);
    }
  }
  return [...links].toSorted((a, b) => a - b);
}

interface Csr {
  readonly offsets: Uint32Array;
  readonly points: Uint32Array;
  readonly links: Uint32Array;
}

function collectLinks(csr: Csr, index: number, links: Set<number>): void {
  const end = csr.offsets[index + 1]!;
  for (let slot = csr.offsets[index]!; slot < end; slot++) links.add(csr.links[slot]!);
}

/** Adds a CSR row's neighbours and links, pushing newly reached points onto `next`. */
function expand(csr: Csr, index: number, points: Set<number>, links: Set<number>, next: number[]): void {
  const end = csr.offsets[index + 1]!;
  for (let slot = csr.offsets[index]!; slot < end; slot++) {
    const neighbour = csr.points[slot]!;
    links.add(csr.links[slot]!);
    if (points.has(neighbour)) continue;
    points.add(neighbour);
    next.push(neighbour);
  }
}

/** Point ids for a highlight, for the diagnostics hook. */
export function highlightIds(graph: ViewerGraph, highlight: Highlight): string[] {
  return highlight.points.map((point) => graph.pointIds[point] ?? "");
}
