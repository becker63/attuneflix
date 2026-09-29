/**
 * The wire projection: enabled dependency edges (`imports`, `calls`) projected
 * through the visible frontier and aggregated per (source, target, relation).
 *
 * For every enabled basis dependency u --r--> v (r a wire relation):
 *
 *   projected wire  π_F(u) --r--> π_F(v)   when π_F(u) ≠ π_F(v)  (drawn)
 *   internalized into region R              when π_F(u) = π_F(v) = R (counted,
 *                                           never drawn)
 *
 * `parent` and `defines` are space and ownership: they build the containment
 * tree and are NEVER painted as wires — requesting them here throws.
 *
 * Aggregation: one ProjectedDependency per (source, target, relation) triple;
 * `multiplicity` is the backing basis-edge count and `provenance` the exact
 * backing relations.parquet row ordinals, ascending. Wires are ordered
 * canonically by (relation rank, source index, target index), so the output is
 * a deterministic function of (world, frontier, enabled relations).
 *
 * Conservation (law-tested): sum(multiplicity over wires) + internalized ==
 * the number of enabled basis dependency edges — at every frontier state, and
 * stable across expand/collapse because transitions change only the view.
 */
import { pointId, type ViewerGraph } from "../../../projection/src/graph.ts";
import { relationRank, type Relation } from "../../../projection/src/relation.ts";
import type { ContainmentTree } from "./containment.ts";
import { projectedNodes, type ProjectedNode, type VisibleFrontier } from "./frontier.ts";

/** The only relations that may ever be painted as wires. */
export const WIRE_RELATIONS = ["imports", "calls"] as const;

export type WireRelation = (typeof WIRE_RELATIONS)[number];

export function isWireRelation(value: string): value is WireRelation {
  return (WIRE_RELATIONS as readonly string[]).includes(value);
}

/**
 * Validates and canonicalizes an enabled wire-relation set: dedupes, orders by
 * the canonical relation order, and rejects any non-wire relation — the
 * projection refuses to draw space/ownership facts as wires.
 */
export function normalizeWireRelations(enabled: readonly string[]): WireRelation[] {
  const unique = new Set<string>(enabled);
  for (const relation of unique) {
    if (!isWireRelation(relation)) {
      throw new Error(`not a wire relation (space/ownership is never wired): ${relation}`);
    }
  }
  return WIRE_RELATIONS.filter((relation) => unique.has(relation));
}

/** One aggregated projected wire between two distinct visible nodes. */
export interface ProjectedDependency {
  /** Projected endpoint node ids (graph point ids). */
  readonly source: string;
  readonly target: string;
  /** Projected endpoint point indices. */
  readonly sourceIndex: number;
  readonly targetIndex: number;
  readonly relation: WireRelation;
  /** Number of backing basis dependency edges (== provenance.length). */
  readonly multiplicity: number;
  /** Backing relations.parquet row ordinals, ascending. */
  readonly provenance: readonly number[];
}

/** The full view projection of one world at one frontier over one enabled set. */
export interface FrontierProjection {
  readonly frontier: VisibleFrontier;
  /** The enabled wire relations, canonicalized. */
  readonly enabled: readonly WireRelation[];
  /** Visible frontier members, ascending point index. */
  readonly nodes: readonly ProjectedNode[];
  /** Aggregated wires, canonical order. */
  readonly wires: readonly ProjectedDependency[];
  /** Enabled basis edges whose projected endpoints coincide (never drawn). */
  readonly internalized: number;
  /** Projected node id -> count of basis edges self-projected onto that node. */
  readonly internalizedByNode: ReadonlyMap<string, number>;
}

/** Link-index range [start, end) of each relation, in the canonical link order (RELATION_ORDER). */
function linkRanges(graph: ViewerGraph): Record<Relation, readonly [number, number]> {
  let start = 0;
  const next = (relation: Relation): readonly [number, number] => {
    const range: readonly [number, number] = [start, start + graph.relationCounts[relation]];
    start += graph.relationCounts[relation];
    return range;
  };
  // RELATION_ORDER is defines, imports, calls, parent; the ranges partition the links.
  return { defines: next("defines"), imports: next("imports"), calls: next("calls"), parent: next("parent") };
}

/**
 * Projects the world's enabled dependency edges through the frontier. Pure:
 * reads the evidence graph and the frontier value, allocates fresh output, and
 * mutates neither.
 */
export function projectFrontier(
  graph: ViewerGraph,
  tree: ContainmentTree,
  frontier: VisibleFrontier,
  enabled: readonly string[],
): FrontierProjection {
  const enabledRelations = normalizeWireRelations(enabled);
  const nodes = projectedNodes(tree, frontier);

  // π_F with memoization over the container chain.
  const expanded = new Uint8Array(graph.pointCount);
  for (const id of frontier.expanded) {
    const index = graph.indexById.get(id);
    if (index === undefined) throw new Error(`frontier carries an id outside this world: ${id}`);
    expanded[index] = 1;
  }
  expanded[tree.root] = 1;
  const isVisiblePoint = (index: number): boolean => {
    if (index === tree.root) return false;
    const container = tree.containerOf[index] ?? -1;
    return container >= 0 && expanded[container] === 1;
  };
  const piMemo = new Int32Array(graph.pointCount).fill(-1);
  const piOf = (index: number): number => {
    let point = index;
    let resolved = piMemo[point] ?? -1;
    if (resolved >= 0) return resolved;
    // Walk to the deepest visible ancestor-or-self, then fill the whole chain.
    const chain: number[] = [];
    while (point !== tree.root && !isVisiblePoint(point)) {
      chain.push(point);
      point = tree.containerOf[point] ?? tree.root;
      resolved = piMemo[point] ?? -1;
      if (resolved >= 0) {
        point = resolved;
        break;
      }
    }
    for (const member of chain) piMemo[member] = point;
    return point;
  };

  interface Aggregate {
    sourceIndex: number;
    targetIndex: number;
    relation: WireRelation;
    provenance: number[];
  }
  const aggregates = new Map<string, Aggregate>();
  const internalizedByIndex = new Map<number, number>();
  let internalized = 0;
  const ranges = linkRanges(graph);

  for (const relation of enabledRelations) {
    const [start, end] = ranges[relation];
    for (let link = start; link < end; link++) {
      const source = piOf(graph.linkSourceIndices[link] ?? 0);
      const target = piOf(graph.linkTargetIndices[link] ?? 0);
      if (source === target) {
        internalized += 1;
        internalizedByIndex.set(source, (internalizedByIndex.get(source) ?? 0) + 1);
        continue;
      }
      const key = `${relation}|${source}|${target}`;
      const existing = aggregates.get(key);
      if (existing !== undefined) {
        existing.provenance.push(graph.linkRows[link] ?? -1);
      } else {
        aggregates.set(key, {
          sourceIndex: source,
          targetIndex: target,
          relation,
          provenance: [graph.linkRows[link] ?? -1],
        });
      }
    }
  }

  const wires: ProjectedDependency[] = [...aggregates.values()]
    .toSorted(
      (a, b) =>
        relationRank(a.relation) - relationRank(b.relation) ||
        a.sourceIndex - b.sourceIndex ||
        a.targetIndex - b.targetIndex,
    )
    .map((aggregate) => ({
      source: pointId(graph, aggregate.sourceIndex),
      target: pointId(graph, aggregate.targetIndex),
      sourceIndex: aggregate.sourceIndex,
      targetIndex: aggregate.targetIndex,
      relation: aggregate.relation,
      multiplicity: aggregate.provenance.length,
      provenance: aggregate.provenance,
    }));

  const internalizedByNode = new Map<string, number>();
  for (const [index, count] of [...internalizedByIndex.entries()].toSorted((a, b) => a[0] - b[0])) {
    internalizedByNode.set(pointId(graph, index), count);
  }

  return { frontier, enabled: enabledRelations, nodes, wires, internalized, internalizedByNode };
}

/** The widest a projected wire is drawn (multiplicity is log-scaled). */
export const MAX_WIRE_WIDTH = 8;

/**
 * Rendered width of a projected wire: 1 + log2(1 + multiplicity), capped — the
 * familyEdgeWidth precedent. Width only ever approximates the count; the exact
 * multiplicity is a number on the wire's detail state, never thickness alone.
 */
export function projectedWireWidth(multiplicity: number): number {
  return Math.min(1 + Math.log2(1 + Math.max(0, multiplicity)), MAX_WIRE_WIDTH);
}
