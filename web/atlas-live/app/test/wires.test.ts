/**
 * Laws of the frontier wire projection (VAL-FRONT-002, VAL-WIRE-001..004,
 * VAL-WIRE-007..009): enabled imports/calls project to π_F(u) --r--> π_F(v),
 * self-projected edges are internalized and never drawn, wires aggregate per
 * (source, target, relation) with multiplicity == backing count, provenance is
 * the deterministic relations.parquet row ordinals, and conservation holds
 * globally and across every expand/collapse transition — on the hand-computed
 * fixture and on the real preact/axios worlds staged by
 * //web/atlas-live/projection:layout_worlds.
 */
import { beforeAll, describe, expect, it } from "vitest";

import { linkRelation, type ViewerGraph } from "../../projection/src/graph.ts";
import { projectWorld } from "../../projection/src/project.ts";
import { RELATION_ORDER } from "../../projection/src/relation.ts";
import { readWorldDir } from "../../projection/src/world_dir.ts";
import { containmentTree, type ContainmentTree } from "../src/frontier/containment.ts";
import {
  collapse,
  expand,
  initialFrontier,
  pi,
  projectedNodes,
  type VisibleFrontier,
} from "../src/frontier/frontier.ts";
import {
  MAX_WIRE_WIDTH,
  WIRE_RELATIONS,
  isWireRelation,
  normalizeWireRelations,
  projectFrontier,
  projectedWireWidth,
  type FrontierProjection,
  type ProjectedDependency,
} from "../src/frontier/wires.ts";
import { FIXTURE_IDS, frontierFixtureGraph } from "./frontierFixture.ts";

const LAYOUT_WORLDS = "../projection/layout_worlds";
const PREACT = "6e2bef41bf19f638be084df8cb82127e4832d4abbafa8ca20ebd5db9be3ac8a9";
const AXIOS = "1e44a1c45ec4a91bb7774dc6d37a2846a5f56262b6fa7ae5722bcbcc15ba10c7";

const ID = FIXTURE_IDS;
const BOTH = ["imports", "calls"] as const;

function wireKey(wire: Pick<ProjectedDependency, "source" | "target" | "relation">): string {
  return `${wire.relation}|${wire.source}|${wire.target}`;
}

function wireSnapshot(projection: FrontierProjection): unknown {
  return {
    nodes: projection.nodes.map((node) => node.id),
    wires: projection.wires.map((wire) => [
      wire.relation,
      wire.source,
      wire.target,
      wire.multiplicity,
      wire.provenance,
    ]),
    internalized: projection.internalized,
    internalizedByNode: [...projection.internalizedByNode.entries()].toSorted(([a], [b]) =>
      a.localeCompare(b),
    ),
  };
}

/** The number of enabled basis dependency edges of the world. */
function enabledBasisCount(graph: ViewerGraph, enabled: readonly string[]): number {
  let total = 0;
  for (const relation of RELATION_ORDER) {
    if (enabled.includes(relation)) total += graph.relationCounts[relation];
  }
  return total;
}

/** Link indices of one wire relation, in ascending link order (hence ascending row order). */
function relationLinks(graph: ViewerGraph, relation: "imports" | "calls"): number[] {
  let start = 0;
  for (const candidate of RELATION_ORDER) {
    if (candidate === relation) break;
    start += graph.relationCounts[candidate];
  }
  return Array.from({ length: graph.relationCounts[relation] }, (_, k) => start + k);
}

/**
 * The full law set of one projection: aggregation shape, per-wire provenance,
 * internalized exactness, and global conservation — all recomputed from the
 * evidence graph, not from the projection under test.
 */
function expectWireLaws(
  graph: ViewerGraph,
  tree: ContainmentTree,
  frontier: VisibleFrontier,
  projection: FrontierProjection,
): void {
  const enabled = normalizeWireRelations(projection.enabled);
  const nodeIds = new Set(projection.nodes.map((node) => node.id));

  // Aggregation: (source, target, relation) is unique; endpoints are projected nodes.
  const keys = new Set<string>();
  for (const wire of projection.wires) {
    expect(isWireRelation(wire.relation)).toBe(true);
    expect(nodeIds.has(wire.source)).toBe(true);
    expect(nodeIds.has(wire.target)).toBe(true);
    expect(wire.source).not.toBe(wire.target);
    expect(keys.has(wireKey(wire))).toBe(false);
    keys.add(wireKey(wire));
  }

  // Per wire: multiplicity == |provenance|, ordinals ascending, each ordinal
  // resolves to a basis row of the wire's relation whose endpoints project
  // exactly onto the wire's endpoints (VAL-WIRE-003/004).
  const linkByRow = new Map<string, number>();
  for (const relation of WIRE_RELATIONS) {
    for (const link of relationLinks(graph, relation)) {
      linkByRow.set(`${relation}:${graph.linkRows[link]}`, link);
    }
  }
  for (const wire of projection.wires) {
    expect(wire.multiplicity).toBe(wire.provenance.length);
    expect(wire.multiplicity).toBeGreaterThan(0);
    for (let k = 1; k < wire.provenance.length; k++) {
      expect(wire.provenance[k]).toBeGreaterThan(wire.provenance[k - 1] ?? -1);
    }
    for (const ordinal of wire.provenance) {
      const link = linkByRow.get(`${wire.relation}:${ordinal}`);
      if (link === undefined) throw new Error(`wire provenance row ${ordinal} is not a ${wire.relation} row`);
      expect(linkRelation(graph, link)).toBe(wire.relation);
      expect(pi(tree, frontier, graph.linkSourceIndices[link] ?? -1)).toBe(wire.sourceIndex);
      expect(pi(tree, frontier, graph.linkTargetIndices[link] ?? -1)).toBe(wire.targetIndex);
    }
  }

  // Internalized exactness (VAL-WIRE-002): independently recompute the
  // self-projected enabled edges and compare per node and in total.
  const expectedByNode = new Map<number, number>();
  let expectedInternalized = 0;
  for (const relation of enabled) {
    for (const link of relationLinks(graph, relation)) {
      const source = pi(tree, frontier, graph.linkSourceIndices[link] ?? -1);
      const target = pi(tree, frontier, graph.linkTargetIndices[link] ?? -1);
      if (source !== target) continue;
      expectedInternalized += 1;
      expectedByNode.set(source, (expectedByNode.get(source) ?? 0) + 1);
    }
  }
  expect(projection.internalized).toBe(expectedInternalized);
  let reportedInternalized = 0;
  for (const [id, count] of projection.internalizedByNode) {
    const index = graph.indexById.get(id);
    if (index === undefined) throw new Error(`internalized reported for unknown node ${id}`);
    expect(count).toBe(expectedByNode.get(index) ?? 0);
    reportedInternalized += count;
  }
  expect(reportedInternalized).toBe(expectedInternalized);
  expect(projection.internalizedByNode.size).toBe(expectedByNode.size);

  // Every enabled basis edge backs exactly one wire or is internalized
  // (VAL-WIRE-001: no invention, no dropped edge).
  let drawn = 0;
  for (const wire of projection.wires) drawn += wire.multiplicity;
  expect(drawn + projection.internalized).toBe(enabledBasisCount(graph, enabled));
}

/** The canonical transition sequence used by the per-transition conservation law. */
function transitions(tree: ContainmentTree): VisibleFrontier[] {
  const states: VisibleFrontier[] = [initialFrontier()];
  let current = states[0] ?? initialFrontier();
  const region = projectedNodes(tree, current).find((node) => node.kind === "directory");
  if (region === undefined) return states;
  current = expand(tree, current, region.id);
  states.push(current);
  const file = projectedNodes(tree, current).find(
    (node) => node.kind === "file" && node.container === region.id,
  );
  if (file !== undefined) {
    current = expand(tree, current, file.id);
    states.push(current);
    current = collapse(tree, current, file.id);
    states.push(current);
  }
  current = collapse(tree, current, region.id);
  states.push(current);
  return states;
}

describe("wire relation vocabulary", () => {
  it("admits exactly imports and calls, never parent or defines (VAL-FRONT-002)", () => {
    expect([...WIRE_RELATIONS]).toEqual(["imports", "calls"]);
    expect(isWireRelation("imports")).toBe(true);
    expect(isWireRelation("calls")).toBe(true);
    expect(isWireRelation("parent")).toBe(false);
    expect(isWireRelation("defines")).toBe(false);
    expect(() => normalizeWireRelations(["parent"])).toThrow(/wire relation/);
    expect(() => normalizeWireRelations(["defines"])).toThrow(/wire relation/);
    expect(() => normalizeWireRelations(["imports", "nonsense"])).toThrow(/wire relation/);
    expect(normalizeWireRelations(["calls", "imports", "calls"])).toEqual(["imports", "calls"]);
  });

  it("maps multiplicity to width only through the documented monotone log map (VAL-WIRE-003)", () => {
    expect(projectedWireWidth(0)).toBe(1);
    expect(projectedWireWidth(1)).toBe(2);
    expect(projectedWireWidth(3)).toBe(3);
    expect(projectedWireWidth(7)).toBe(4);
    // Monotone non-decreasing, capped at MAX_WIRE_WIDTH.
    let previous = 0;
    for (let multiplicity = 0; multiplicity < 1000; multiplicity++) {
      const width = projectedWireWidth(multiplicity);
      expect(width).toBeGreaterThanOrEqual(previous);
      expect(width).toBeLessThanOrEqual(MAX_WIRE_WIDTH);
      previous = width;
    }
    expect(projectedWireWidth(10_000)).toBe(MAX_WIRE_WIDTH);
  });
});

describe("wire projection on the hand-made fixture", () => {
  const graph = frontierFixtureGraph();
  const tree = containmentTree(graph);

  it("aggregates the default frontier with the hand-computed wires and ordinals", () => {
    const frontier = initialFrontier();
    const projection = projectFrontier(graph, tree, frontier, BOTH);
    expect(
      projection.wires.map((wire) => [
        wire.relation,
        wire.source,
        wire.target,
        wire.multiplicity,
        wire.provenance,
      ]),
    ).toEqual([
      ["imports", ID.a, ID.b, 3, [7, 10, 11]],
      ["imports", ID.b, ID.a, 1, [8]],
      ["calls", ID.a, ID.b, 1, [14]],
      ["calls", ID.b, ID.topFile, 1, [16]],
    ]);
    expect(projection.internalized).toBe(6);
    expect(Object.fromEntries(projection.internalizedByNode)).toEqual({ [ID.a]: 4, [ID.topFile]: 2 });
    expectWireLaws(graph, tree, frontier, projection);
  });

  it("decomposes the aggregate when the region expands", () => {
    const frontier = expand(tree, initialFrontier(), ID.a);
    const projection = projectFrontier(graph, tree, frontier, BOTH);
    expect(
      projection.wires.map((wire) => [
        wire.relation,
        wire.source,
        wire.target,
        wire.multiplicity,
        wire.provenance,
      ]),
    ).toEqual([
      ["imports", ID.xFile, ID.yFile, 1, [5]],
      ["imports", ID.xFile, ID.sub, 1, [6]],
      ["imports", ID.yFile, ID.b, 2, [10, 11]],
      ["imports", ID.b, ID.xFile, 1, [8]],
      ["imports", ID.sub, ID.b, 1, [7]],
      ["calls", ID.xFile, ID.sub, 1, [13]],
      ["calls", ID.b, ID.topFile, 1, [16]],
      ["calls", ID.sub, ID.b, 1, [14]],
    ]);
    expect(projection.internalized).toBe(3);
    expect(Object.fromEntries(projection.internalizedByNode)).toEqual({ [ID.xFile]: 1, [ID.topFile]: 2 });
    expectWireLaws(graph, tree, frontier, projection);
  });

  it("exposes individual basis edges once both endpoints are fully expanded", () => {
    let frontier = expand(tree, initialFrontier(), ID.a);
    frontier = expand(tree, frontier, ID.xFile);
    const projection = projectFrontier(graph, tree, frontier, BOTH);
    const call = projection.wires.find((wire) => wire.relation === "calls" && wire.source === ID.xaSym);
    expect(call?.target).toBe(ID.xbSym);
    expect(call?.multiplicity).toBe(1);
    expect(call?.provenance).toEqual([12]);
    // The duplicate a/y.ts -> b/w.ts imports still aggregate, at multiplicity 2.
    const duplicate = projection.wires.find(
      (wire) => wire.relation === "imports" && wire.source === ID.yFile,
    );
    expect(duplicate?.target).toBe(ID.b);
    expect(duplicate?.multiplicity).toBe(2);
    expect(duplicate?.provenance).toEqual([10, 11]);
    expect(projection.internalized).toBe(2);
    expectWireLaws(graph, tree, frontier, projection);
  });

  it("respects the enabled relation set, with per-set conservation (VAL-WIRE-007)", () => {
    const frontier = initialFrontier();
    const importsOnly = projectFrontier(graph, tree, frontier, ["imports"]);
    expect(importsOnly.wires.map(wireKey)).toEqual([`imports|${ID.a}|${ID.b}`, `imports|${ID.b}|${ID.a}`]);
    expect(importsOnly.internalized).toBe(3);
    expectWireLaws(graph, tree, frontier, importsOnly);
    const callsOnly = projectFrontier(graph, tree, frontier, ["calls"]);
    expect(callsOnly.wires.map(wireKey)).toEqual([`calls|${ID.a}|${ID.b}`, `calls|${ID.b}|${ID.topFile}`]);
    expect(callsOnly.internalized).toBe(3);
    expectWireLaws(graph, tree, frontier, callsOnly);
    const none = projectFrontier(graph, tree, frontier, []);
    expect(none.wires).toEqual([]);
    expect(none.internalized).toBe(0);
  });

  it("rejects projecting the spatial relations as wires", () => {
    expect(() => projectFrontier(graph, tree, initialFrontier(), ["imports", "parent"])).toThrow(
      /wire relation/,
    );
    expect(() => projectFrontier(graph, tree, initialFrontier(), ["defines"])).toThrow(/wire relation/);
  });

  it("is deterministic and conserves evidence across expand/collapse (VAL-WIRE-008/009)", () => {
    const initial = initialFrontier();
    const baseline = projectFrontier(graph, tree, initial, BOTH);
    expect(wireSnapshot(projectFrontier(graph, tree, initialFrontier(), BOTH))).toEqual(
      wireSnapshot(baseline),
    );
    let frontier = expand(tree, initial, ID.a);
    frontier = expand(tree, frontier, ID.xFile);
    frontier = collapse(tree, frontier, ID.xFile);
    frontier = collapse(tree, frontier, ID.a);
    // Expand/collapse changed the view along the way; the round trip restores it.
    expect(wireSnapshot(projectFrontier(graph, tree, frontier, BOTH))).toEqual(wireSnapshot(baseline));
  });
});

describe.each([
  ["preact", PREACT],
  ["axios", AXIOS],
])("wire projection laws on the real %s world", (name, digest) => {
  let graph: ViewerGraph;
  let tree: ContainmentTree;

  beforeAll(async () => {
    graph = await projectWorld(await readWorldDir(`${LAYOUT_WORLDS}/${digest}`));
    tree = containmentTree(graph);
  });

  it("never paints parent/defines and conserves evidence for every enabled set (VAL-WIRE-007)", () => {
    const frontier = initialFrontier();
    for (const enabled of [["imports", "calls"], ["imports"], ["calls"], []] as const) {
      const projection = projectFrontier(graph, tree, frontier, enabled);
      expectWireLaws(graph, tree, frontier, projection);
      for (const wire of projection.wires) expect(isWireRelation(wire.relation)).toBe(true);
    }
  });

  it("conserves evidence across a real expand/collapse sequence (VAL-WIRE-008)", () => {
    const total = graph.relationCounts.imports + graph.relationCounts.calls;
    for (const frontier of transitions(tree)) {
      const projection = projectFrontier(graph, tree, frontier, BOTH);
      expectWireLaws(graph, tree, frontier, projection);
      let drawn = 0;
      for (const wire of projection.wires) drawn += wire.multiplicity;
      expect(drawn + projection.internalized).toBe(total);
    }
  });

  it("is deterministic across independent invocations and decodings (VAL-WIRE-009)", async () => {
    const frontier = transitions(tree)[2] ?? initialFrontier();
    const first = projectFrontier(graph, tree, frontier, BOTH);
    const second = projectFrontier(graph, tree, frontier, BOTH);
    expect(wireSnapshot(second)).toEqual(wireSnapshot(first));
    const reloaded = await projectWorld(await readWorldDir(`${LAYOUT_WORLDS}/${digest}`));
    const reloadedTree = containmentTree(reloaded);
    let reloadedFrontier = initialFrontier();
    for (const id of frontier.expanded) reloadedFrontier = expand(reloadedTree, reloadedFrontier, id);
    expect(wireSnapshot(projectFrontier(reloaded, reloadedTree, reloadedFrontier, BOTH))).toEqual(
      wireSnapshot(first),
    );
  });
});
