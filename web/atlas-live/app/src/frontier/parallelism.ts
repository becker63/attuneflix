/**
 * Static structural separation over the existing directed frontier wires.
 *
 * A directory origin starts at every visible projected entity physically below
 * it (including the directory node). A file starts at itself and any visible
 * descendants. The entire origin set is excluded from its reachable
 * neighborhood. This prevents a containment artifact from becoming a fake
 * source-language dependency. Nested origins may have overlapping seed sets;
 * that is visible in the raw counts and is never classified as contention.
 *
 * The index depends only on one projection (which already incorporates the
 * enabled imports/calls mask) and its containment tree. Selection, depth and
 * threshold reuse its three precomputed cumulative bitsets.
 */
import type { ContainmentTree } from "./containment.ts";
import type { FrontierProjection } from "./wires.ts";

export type StructuralOrigin = string;
export type StructuralDepth = 1 | 2 | 3;

export interface Neighborhood {
  readonly origin: StructuralOrigin;
  readonly sizes: readonly [number, number, number];
  readonly growth: readonly [number, number];
  readonly sets: readonly [Uint32Array, Uint32Array, Uint32Array];
  readonly occupied: readonly [readonly number[], readonly number[], readonly number[]];
}

export interface NeighborhoodIndex {
  readonly projection: FrontierProjection;
  readonly nodeIds: readonly string[];
  readonly nodeIndices: readonly number[];
  readonly ordinalById: ReadonlyMap<string, number>;
  readonly candidates: readonly StructuralOrigin[];
  readonly eligibleRegions: number;
  readonly byOrigin: Map<StructuralOrigin, Neighborhood>;
  readonly adjacency: readonly (readonly number[])[];
  readonly tree: ContainmentTree;
  readonly overlapMatrices: Map<StructuralDepth, Float32Array>;
  constructionMs: number;
  pairMetricsMs: number;
}

export interface PairDepth {
  readonly a: number;
  readonly b: number;
  readonly intersection: number;
  readonly union: number;
  readonly overlap: number;
}

export interface PairGeometry {
  readonly a: StructuralOrigin;
  readonly b: StructuralOrigin;
  readonly depths: readonly [PairDepth, PairDepth, PairDepth];
  /** null means no common reachable entity through three hops: censored >3°. */
  readonly convergenceDepth: StructuralDepth | null;
}

export interface ConvergenceGraph {
  readonly origins: readonly StructuralOrigin[];
  readonly neighbors: ReadonlyMap<StructuralOrigin, ReadonlySet<StructuralOrigin>>;
  readonly edges: number;
  readonly depth: StructuralDepth;
  readonly threshold: number;
}

/** Maximum aggregate region population; selected files remain individually measurable. */
export const MAX_AGGREGATE_REGIONS = 384;

function depthSlot(depth: StructuralDepth): 0 | 1 | 2 {
  if (depth === 1) return 0;
  if (depth === 2) return 1;
  return 2;
}

function popcount(value: number): number {
  let bits = value;
  bits -= (bits >>> 1) & 0x55555555;
  bits = (bits & 0x33333333) + ((bits >>> 2) & 0x33333333);
  return (((bits + (bits >>> 4)) & 0x0f0f0f0f) * 0x01010101) >>> 24;
}

function contains(set: Uint32Array, ordinal: number): boolean {
  return ((set[ordinal >>> 5] ?? 0) & (1 << (ordinal & 31))) !== 0;
}

function add(set: Uint32Array, ordinal: number): void {
  set[ordinal >>> 5] = (set[ordinal >>> 5] ?? 0) | (1 << (ordinal & 31));
}

function occupied(set: Uint32Array): number[] {
  const positions: number[] = [];
  for (let i = 0; i < set.length; i++) if (set[i] !== 0) positions.push(i);
  return positions;
}

function isWithin(tree: ContainmentTree, point: number, ancestor: number): boolean {
  let current = point;
  while (current >= 0) {
    if (current === ancestor) return true;
    current = tree.containerOf[current] ?? -1;
  }
  return false;
}

function neighborhood(index: NeighborhoodIndex, id: string): Neighborhood {
  const cached = index.byOrigin.get(id);
  if (cached !== undefined) return cached;
  const originPoint = index.tree.graph.indexById.get(id);
  if (originPoint === undefined || !index.ordinalById.has(id)) {
    throw new Error(`structural origin is not visible: ${id}`);
  }
  const seeds: number[] = [];
  for (let ordinal = 0; ordinal < index.nodeIndices.length; ordinal++) {
    if (isWithin(index.tree, index.nodeIndices[ordinal] ?? -1, originPoint)) seeds.push(ordinal);
  }
  const seen = new Uint8Array(index.nodeIds.length);
  for (const seed of seeds) seen[seed] = 1;
  let wave = seeds;
  let cumulative = new Uint32Array(Math.ceil(index.nodeIds.length / 32));
  const sets: Uint32Array[] = [];
  const sizes: number[] = [];
  const words: number[][] = [];
  let size = 0;
  for (let depth = 0; depth < 3; depth++) {
    const next: number[] = [];
    const current = cumulative.slice();
    for (const source of wave) {
      for (const target of index.adjacency[source] ?? []) {
        if (seen[target] === 1) continue;
        seen[target] = 1;
        next.push(target);
        add(current, target);
        size++;
      }
    }
    cumulative = current;
    sets.push(current);
    sizes.push(size);
    words.push(occupied(current));
    wave = next;
  }
  const result: Neighborhood = {
    origin: id,
    sizes: [sizes[0] ?? 0, sizes[1] ?? 0, sizes[2] ?? 0],
    growth: [(sizes[1] ?? 0) - (sizes[0] ?? 0), (sizes[2] ?? 0) - (sizes[1] ?? 0)],
    sets: [sets[0]!, sets[1]!, sets[2]!],
    occupied: [words[0]!, words[1]!, words[2]!],
  };
  index.byOrigin.set(id, result);
  return result;
}

/** Bitsets are allocated for visible regions only; selected files are lazy. */
export function buildNeighborhoodIndex(
  projection: FrontierProjection,
  tree: ContainmentTree,
): NeighborhoodIndex {
  const started = performance.now();
  const nodes = projection.nodes;
  const nodeIds = nodes.map((node) => node.id);
  const nodeIndices = nodes.map((node) => node.index);
  const ordinalById = new Map(nodeIds.map((id, ordinal) => [id, ordinal]));
  const adjacency: Set<number>[] = Array.from({ length: nodes.length }, () => new Set<number>());
  for (const wire of projection.wires) {
    const source = ordinalById.get(wire.source);
    const target = ordinalById.get(wire.target);
    if (source !== undefined && target !== undefined && source !== target) adjacency[source]?.add(target);
  }
  const regions = nodes.filter((node) => node.kind === "directory");
  const originNodes = regions.length > 0 ? regions : nodes.filter((node) => node.kind === "file");
  const candidates = originNodes
    .toSorted((a, b) => a.depth - b.depth || a.id.localeCompare(b.id))
    .slice(0, MAX_AGGREGATE_REGIONS)
    .map((node) => node.id);
  const index: NeighborhoodIndex = {
    projection,
    nodeIds,
    nodeIndices,
    ordinalById,
    candidates,
    eligibleRegions: originNodes.length,
    byOrigin: new Map(),
    adjacency: adjacency.map((set) => [...set].toSorted((a, b) => a - b)),
    tree,
    overlapMatrices: new Map(),
    constructionMs: 0,
    pairMetricsMs: 0,
  };
  for (const id of candidates) neighborhood(index, id);
  index.constructionMs = performance.now() - started;
  return index;
}

const cache = new WeakMap<FrontierProjection, NeighborhoodIndex>();

/** Shared by the graph and inspector; invalidated by a new frontier projection. */
export function neighborhoodIndex(projection: FrontierProjection, tree: ContainmentTree): NeighborhoodIndex {
  const cached = cache.get(projection);
  if (cached !== undefined) return cached;
  const index = buildNeighborhoodIndex(projection, tree);
  cache.set(projection, index);
  return index;
}

export function originNeighborhood(index: NeighborhoodIndex, id: string): Neighborhood {
  return neighborhood(index, id);
}

export function neighborhoodHas(index: NeighborhoodIndex, id: string, depth: StructuralDepth, nodeId: string): boolean {
  const ordinal = index.ordinalById.get(nodeId);
  return ordinal !== undefined && contains(neighborhood(index, id).sets[depthSlot(depth)], ordinal);
}

export function neighborhoodIds(index: NeighborhoodIndex, id: string, depth: StructuralDepth): string[] {
  const bits = neighborhood(index, id).sets[depthSlot(depth)];
  return index.nodeIds.filter((_nodeId, ordinal) => contains(bits, ordinal));
}

export function pairAtDepth(
  index: NeighborhoodIndex,
  a: string,
  b: string,
  depth: StructuralDepth,
): PairDepth {
  const left = neighborhood(index, a);
  const right = neighborhood(index, b);
  const slot = depthSlot(depth);
  const smaller = left.occupied[slot].length <= right.occupied[slot].length ? left : right;
  const larger = smaller === left ? right : left;
  let intersection = 0;
  for (const word of smaller.occupied[slot]) {
    intersection += popcount((smaller.sets[slot][word] ?? 0) & (larger.sets[slot][word] ?? 0));
  }
  const aSize = left.sizes[slot];
  const bSize = right.sizes[slot];
  const union = aSize + bSize - intersection;
  return { a: aSize, b: bSize, intersection, union, overlap: union === 0 ? 0 : intersection / union };
}

export function pairGeometry(index: NeighborhoodIndex, a: string, b: string): PairGeometry {
  const depths: [PairDepth, PairDepth, PairDepth] = [
    pairAtDepth(index, a, b, 1),
    pairAtDepth(index, a, b, 2),
    pairAtDepth(index, a, b, 3),
  ];
  const first = depths.findIndex((item) => item.intersection > 0);
  return { a, b, depths, convergenceDepth: first === 0 ? 1 : first === 1 ? 2 : first === 2 ? 3 : null };
}

export function sharedNeighborhoodIds(index: NeighborhoodIndex, a: string, b: string, depth: StructuralDepth): string[] {
  const left = neighborhood(index, a).sets[depthSlot(depth)];
  const right = neighborhood(index, b).sets[depthSlot(depth)];
  return index.nodeIds.filter((_id, ordinal) => contains(left, ordinal) && contains(right, ordinal));
}

export function convergenceGraph(
  index: NeighborhoodIndex,
  depth: StructuralDepth,
  threshold: number,
): ConvergenceGraph {
  if (threshold < 0 || threshold > 1 || !Number.isFinite(threshold)) throw new Error("threshold must be in [0,1]");
  let matrix = index.overlapMatrices.get(depth);
  if (matrix === undefined) {
    const started = performance.now();
    const count = index.candidates.length;
    matrix = new Float32Array(count * count);
    for (let i = 0; i < count; i++) {
      for (let j = i + 1; j < count; j++) {
        const overlap = pairAtDepth(index, index.candidates[i]!, index.candidates[j]!, depth).overlap;
        matrix[i * count + j] = overlap;
        matrix[j * count + i] = overlap;
      }
    }
    index.overlapMatrices.set(depth, matrix);
    index.pairMetricsMs += performance.now() - started;
  }
  const neighbors = new Map(index.candidates.map((id) => [id, new Set<string>()]));
  let edges = 0;
  for (let i = 0; i < index.candidates.length; i++) {
    const a = index.candidates[i]!;
    for (let j = i + 1; j < index.candidates.length; j++) {
      const b = index.candidates[j]!;
      if ((matrix[i * index.candidates.length + j] ?? 0) < threshold) continue;
      neighbors.get(a)?.add(b);
      neighbors.get(b)?.add(a);
      edges++;
    }
  }
  return { origins: index.candidates, neighbors, edges, depth, threshold };
}

/** Degree-ascending greedy independent set: deterministic estimate, never a maximum claim. */
export function greedySeparatedSet(graph: ConvergenceGraph): string[] {
  const ordered = [...graph.origins].toSorted(
    (a, b) => (graph.neighbors.get(a)?.size ?? 0) - (graph.neighbors.get(b)?.size ?? 0) || a.localeCompare(b),
  );
  const selected = new Set<string>();
  for (const id of ordered) {
    if ([...(graph.neighbors.get(id) ?? [])].some((neighbor) => selected.has(neighbor))) continue;
    selected.add(id);
  }
  return [...selected];
}

/** Degree-descending deterministic greedy coloring, returned as sequential waves. */
export function greedyStructuralWaves(graph: ConvergenceGraph): string[][] {
  const ordered = [...graph.origins].toSorted(
    (a, b) => (graph.neighbors.get(b)?.size ?? 0) - (graph.neighbors.get(a)?.size ?? 0) || a.localeCompare(b),
  );
  const colors = new Map<string, number>();
  const waves: string[][] = [];
  for (const id of ordered) {
    const used = new Set([...(graph.neighbors.get(id) ?? [])].map((neighbor) => colors.get(neighbor)));
    let color = 0;
    while (used.has(color)) color++;
    colors.set(id, color);
    (waves[color] ??= []).push(id);
  }
  return waves;
}

export function separationDecay(index: NeighborhoodIndex, threshold: number): readonly [number, number, number] {
  return [
    greedySeparatedSet(convergenceGraph(index, 1, threshold)).length,
    greedySeparatedSet(convergenceGraph(index, 2, threshold)).length,
    greedySeparatedSet(convergenceGraph(index, 3, threshold)).length,
  ];
}
