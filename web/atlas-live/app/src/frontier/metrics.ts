/**
 * The architectural region metrics (brief §8): deterministic measurements per
 * visible region, computed over the ENABLED wire relations only. Measurements
 * first — no hard-coded qualitative region classes anywhere (brief §10).
 *
 * Definitions (pinned by the known-answer fixtures in test/metrics.test.ts):
 *
 * A raw entity is INSIDE a region R when R is an ancestor-or-self of the entity
 * in the containment tree. For one enabled basis dependency edge u --r--> v and
 * one visible region R:
 *
 *   internal(R)  counts edges with both u and v inside R — self-loops included
 *                (a self-loop never crosses a boundary).
 *   egress(R)    counts edges with u inside R and v outside R.
 *   ingress(R)   counts edges with u outside R and v inside R.
 *   boundary(R)  = ingress(R) + egress(R), exactly; the two directions are
 *                preserved separately and never merged into an undirected cut.
 *   peers(R)     = the number of distinct other visible nodes R exchanges with
 *                (either direction) over the current frontier's projected wires.
 *   localness(R) = internal(R) / (internal(R) + boundary(R)); when
 *                internal == 0 and boundary == 0 (an isolated region),
 *                localness is defined as exactly 1 — perfect locality.
 *   reach_d(R)   (d in {1,2,3}) = the number of distinct other visible nodes
 *                reachable from R within d hops following projected wire
 *                direction (source -> target) at the current frontier; the
 *                region itself is never counted. reach_1 <= reach_2 <= reach_3.
 *
 * Double-counting rules (exact):
 * - An edge that crosses two nested visible boundaries is counted at EACH
 *   visible boundary it crosses: u inside child C, v outside parent R (with C
 *   inside R) counts as egress(C) AND egress(R). Membership-based counting does
 *   this by construction.
 * - An edge with both endpoints inside R is internal to R and contributes to no
 *   boundary counter of R — even when the edge is drawn as a wire between two
 *   visible children of R.
 * - A self-loop (u == v) is internal to every visible region containing u and
 *   crosses nothing.
 * - The per-relation breakdowns (imports / calls) partition every counter: for
 *   each region, internalByRelation.imports + internalByRelation.calls ==
 *   internal (likewise egress, ingress). A disabled relation contributes 0.
 *
 * Metrics are a pure function of (world, enabled relations, frontier): the
 * internal/ingress/egress counters depend only on the tree and the enabled
 * relations; peers/reach depend on the current frontier's projected wires.
 * Nothing here reads interaction history, renderer state, or React.
 */
import type { ViewerGraph } from "../../../projection/src/graph.ts";
import { pointId } from "../../../projection/src/graph.ts";
import { RELATION_ORDER } from "../../../projection/src/relation.ts";
import type { ContainmentTree } from "./containment.ts";
import type { FrontierProjection, WireRelation } from "./wires.ts";

/** Per-relation components of one counter; a disabled relation stays 0. */
export interface RegionRelationCounts {
  readonly imports: number;
  readonly calls: number;
}

/** The metric vector of one visible region (directory, file, or symbol grain). */
export interface RegionMetrics {
  /** Projected node id of the region. */
  readonly region: string;
  readonly internal: number;
  readonly egress: number;
  readonly ingress: number;
  /** Exactly ingress + egress. */
  readonly boundary: number;
  /** Distinct other visible nodes exchanged with, either direction. */
  readonly peers: number;
  /** internal / (internal + boundary); exactly 1 for an isolated region (0/0). */
  readonly localness: number;
  /** Distinct regions reachable within 1, 2, 3 hops over projected wires. */
  readonly reach: readonly [number, number, number];
  readonly internalByRelation: RegionRelationCounts;
  readonly egressByRelation: RegionRelationCounts;
  readonly ingressByRelation: RegionRelationCounts;
}

/** Region id -> metric vector, in projected-node order. */
export type ProjectionMetrics = ReadonlyMap<string, RegionMetrics>;

interface MutableCounts {
  internal: number;
  egress: number;
  ingress: number;
  internalByRelation: { imports: number; calls: number };
  egressByRelation: { imports: number; calls: number };
  ingressByRelation: { imports: number; calls: number };
}

function zeroCounts(): MutableCounts {
  return {
    internal: 0,
    egress: 0,
    ingress: 0,
    internalByRelation: { imports: 0, calls: 0 },
    egressByRelation: { imports: 0, calls: 0 },
    ingressByRelation: { imports: 0, calls: 0 },
  };
}

/**
 * Computes the metric vector of every visible node of the projection. Pure:
 * reads the evidence graph, the containment tree, and the projection; mutates
 * none of them.
 */
export function computeProjectionMetrics(
  graph: ViewerGraph,
  tree: ContainmentTree,
  projection: FrontierProjection,
): ProjectionMetrics {
  const visible = new Uint8Array(graph.pointCount);
  for (const node of projection.nodes) visible[node.index] = 1;

  // chainOf[point]: the visible nodes on the container path from the point up,
  // nearest first (the point itself included when visible). Memoized.
  const chainOf: (readonly number[] | undefined)[] = Array.from({ length: graph.pointCount });
  const chain = (start: number): readonly number[] => {
    const cached = chainOf[start];
    if (cached !== undefined) return cached;
    const out: number[] = [];
    let point = start;
    while (point >= 0 && point !== tree.root) {
      if (visible[point] === 1) out.push(point);
      point = tree.containerOf[point] ?? -1;
    }
    chainOf[start] = out;
    return out;
  };

  const counts = new Map<number, MutableCounts>();
  const counter = (index: number): MutableCounts => {
    const existing = counts.get(index);
    if (existing !== undefined) return existing;
    const created = zeroCounts();
    counts.set(index, created);
    return created;
  };
  for (const node of projection.nodes) counter(node.index);

  // internal/ingress/egress: membership counting over the enabled basis edges.
  let linkStart = 0;
  const linkEnd = new Map<WireRelation, number>();
  const linkBegin = new Map<WireRelation, number>();
  for (const relation of RELATION_ORDER) {
    if (relation === "imports" || relation === "calls") {
      linkBegin.set(relation, linkStart);
      linkEnd.set(relation, linkStart + graph.relationCounts[relation]);
    }
    linkStart += graph.relationCounts[relation];
  }
  for (const relation of projection.enabled) {
    const start = linkBegin.get(relation) ?? 0;
    const end = linkEnd.get(relation) ?? 0;
    for (let link = start; link < end; link++) {
      const sourceChain = chain(graph.linkSourceIndices[link] ?? 0);
      const targetChain = chain(graph.linkTargetIndices[link] ?? 0);
      const targetSet = new Set(targetChain);
      for (const region of sourceChain) {
        const entry = counter(region);
        if (targetSet.has(region)) {
          entry.internal += 1;
          entry.internalByRelation[relation] += 1;
        } else {
          entry.egress += 1;
          entry.egressByRelation[relation] += 1;
        }
      }
      const sourceSet = new Set(sourceChain);
      for (const region of targetChain) {
        if (sourceSet.has(region)) continue;
        const entry = counter(region);
        entry.ingress += 1;
        entry.ingressByRelation[relation] += 1;
      }
    }
  }

  // peers/reach: the projected wire graph among the visible nodes.
  const out = new Map<number, Set<number>>();
  const inbound = new Map<number, Set<number>>();
  for (const wire of projection.wires) {
    if (!out.has(wire.sourceIndex)) out.set(wire.sourceIndex, new Set());
    out.get(wire.sourceIndex)?.add(wire.targetIndex);
    if (!inbound.has(wire.targetIndex)) inbound.set(wire.targetIndex, new Set());
    inbound.get(wire.targetIndex)?.add(wire.sourceIndex);
  }

  const metrics: Map<string, RegionMetrics> = new Map();
  for (const node of projection.nodes) {
    const index = node.index;
    const { internal, egress, ingress, internalByRelation, egressByRelation, ingressByRelation } =
      counts.get(index) ?? zeroCounts();
    const boundary = ingress + egress;
    const peers = new Set([...(out.get(index) ?? []), ...(inbound.get(index) ?? [])]).size;
    const seen = new Set<number>([index]);
    let wave = new Set<number>([index]);
    const reach: [number, number, number] = [0, 0, 0];
    for (let depth = 0; depth < 3; depth++) {
      const next = new Set<number>();
      for (const member of wave) {
        for (const neighbour of out.get(member) ?? []) {
          if (!seen.has(neighbour)) {
            seen.add(neighbour);
            next.add(neighbour);
          }
        }
      }
      reach[depth] = seen.size - 1;
      wave = next;
    }
    metrics.set(node.id, {
      region: pointId(graph, index),
      internal,
      egress,
      ingress,
      boundary,
      peers,
      localness: internal + boundary === 0 ? 1 : internal / (internal + boundary),
      reach,
      internalByRelation,
      egressByRelation,
      ingressByRelation,
    });
  }
  return metrics;
}
