import { describe, expect, it } from "vitest";

import { projectWorld } from "../../projection/src/project.ts";
import { readWorldDir } from "../../projection/src/world_dir.ts";
import { containmentTree } from "../src/frontier/containment.ts";
import { expand, initialFrontier } from "../src/frontier/frontier.ts";
import {
  buildNeighborhoodIndex,
  convergenceGraph,
  greedySeparatedSet,
  greedyStructuralWaves,
  neighborhoodIds,
  originNeighborhood,
  pairGeometry,
  separationDecay,
  sharedNeighborhoodIds,
} from "../src/frontier/parallelism.ts";
import { projectFrontier } from "../src/frontier/wires.ts";
import { FIXTURE_IDS as ID, frontierFixtureGraph } from "./frontierFixture.ts";

const graph = frontierFixtureGraph();
const tree = containmentTree(graph);
const index = buildNeighborhoodIndex(projectFrontier(graph, tree, initialFrontier(), ["imports", "calls"]), tree);

describe("static structural neighborhoods on a known directed graph", () => {
  it("keeps directed cumulative reach, excludes origin seeds, and finds first convergence at degree two", () => {
    expect(index.candidates).toEqual([ID.a, ID.b, ID.c]);
    expect(neighborhoodIds(index, ID.a, 1)).toEqual([ID.b]);
    expect(new Set(neighborhoodIds(index, ID.a, 2))).toEqual(new Set([ID.b, ID.topFile]));
    expect(originNeighborhood(index, ID.a).sizes).toEqual([1, 2, 2]);
    expect(originNeighborhood(index, ID.a).growth).toEqual([1, 0]);
    const pair = pairGeometry(index, ID.a, ID.b);
    expect(pair.convergenceDepth).toBe(2);
    expect(pair.depths[0]).toEqual({ a: 1, b: 2, intersection: 0, union: 3, overlap: 0 });
    expect(pair.depths[1]).toEqual({ a: 2, b: 2, intersection: 1, union: 3, overlap: 1 / 3 });
    expect(sharedNeighborhoodIds(index, ID.a, ID.b, 2)).toEqual([ID.topFile]);
    expect(pairGeometry(index, ID.b, ID.a).convergenceDepth).toBe(pair.convergenceDepth);
    expect(pairGeometry(index, ID.b, ID.a).depths.map((item) => item.overlap)).toEqual(
      pair.depths.map((item) => item.overlap),
    );
  });

  it("censors disjoint and empty neighborhoods, including the empty/empty Jaccard case", () => {
    const disjoint = pairGeometry(index, ID.a, ID.c);
    expect(disjoint.convergenceDepth).toBeNull();
    expect(disjoint.depths[2].overlap).toBe(0);
    const empty = pairGeometry(index, ID.c, ID.c);
    expect(empty.depths[2]).toEqual({ a: 0, b: 0, intersection: 0, union: 0, overlap: 0 });
  });

  it("obeys the projected relation mask and remains monotone after expansion", () => {
    const disabled = buildNeighborhoodIndex(projectFrontier(graph, tree, initialFrontier(), []), tree);
    expect(pairGeometry(disabled, ID.a, ID.b).convergenceDepth).toBeNull();
    const finer = buildNeighborhoodIndex(
      projectFrontier(graph, tree, expand(tree, initialFrontier(), ID.a), ["imports", "calls"]), tree,
    );
    for (const origin of finer.candidates) {
      const one = new Set(neighborhoodIds(finer, origin, 1));
      const two = new Set(neighborhoodIds(finer, origin, 2));
      const three = new Set(neighborhoodIds(finer, origin, 3));
      for (const id of one) expect(two.has(id)).toBe(true);
      for (const id of two) expect(three.has(id)).toBe(true);
    }
    // A directory's origin set includes its now-visible children, which are
    // excluded from its own neighborhood; containment does not add fake hops.
    expect(neighborhoodIds(finer, ID.a, 1)).not.toContain(ID.xFile);
  });

  it("builds deterministic derived graphs, separated sets, waves, and decay", () => {
    const first = convergenceGraph(index, 2, 0.25);
    const second = convergenceGraph(index, 2, 0.25);
    expect(first.edges).toBe(1);
    expect(first.neighbors.get(ID.a)).toEqual(new Set([ID.b]));
    expect(greedySeparatedSet(first)).toEqual(greedySeparatedSet(second));
    expect(greedySeparatedSet(first)).toHaveLength(2);
    expect(greedyStructuralWaves(first)).toEqual(greedyStructuralWaves(second));
    expect(greedyStructuralWaves(first)).toHaveLength(2);
    expect(separationDecay(index, 0.25)).toEqual([3, 2, 2]);
  });
});

const BENCHMARK_WORLDS = [
  ["axios", "1e44a1c45ec4a91bb7774dc6d37a2846a5f56262b6fa7ae5722bcbcc15ba10c7"],
  ["preact", "6e2bef41bf19f638be084df8cb82127e4832d4abbafa8ca20ebd5db9be3ac8a9"],
  ["babel", "002a462e6f58440bbf60071f1e945b38bb304fe46a38ca6fdfd578248693cf01"],
] as const;

function measure(label: string, built: ReturnType<typeof buildNeighborhoodIndex>): void {
  const decay = separationDecay(built, 0.25);
  const first = built.candidates[0];
  const second = built.candidates[1];
  const started = performance.now();
  if (first !== undefined && second !== undefined) {
    for (let i = 0; i < 100; i++) pairGeometry(built, first, second);
  }
  const selectionMs = (performance.now() - started) / 100;
  const setBytes = [...built.byOrigin.values()].reduce(
    (sum, neighborhood) => sum + neighborhood.sets.reduce((bytes, bits) => bytes + bits.byteLength, 0), 0,
  );
  const matrixBytes = [...built.overlapMatrices.values()].reduce((sum, matrix) => sum + matrix.byteLength, 0);
  expect(decay.every(Number.isFinite)).toBe(true);
  expect(selectionMs).toBeGreaterThanOrEqual(0);
  console.log(JSON.stringify({ benchmark: label, visibleNodes: built.nodeIds.length,
    eligibleRegions: built.eligibleRegions, indexedRegions: built.candidates.length,
    indexMs: Number(built.constructionMs.toFixed(2)), pairMatricesMs: Number(built.pairMetricsMs.toFixed(2)),
    selectionMs: Number(selectionMs.toFixed(3)), indexBytes: setBytes + matrixBytes, decay }));
}

describe("measured index cost on the staged small, medium and largest worlds", () => {
  it.each(BENCHMARK_WORLDS)("records actual %s costs without a timing pass/fail threshold", async (name, digest) => {
    const world = await projectWorld(await readWorldDir(`../projection/layout_worlds/${digest}`));
    const worldTree = containmentTree(world);
    const projection = projectFrontier(world, worldTree, initialFrontier(), ["imports", "calls"]);
    const built = buildNeighborhoodIndex(projection, worldTree);
    measure(name, built);
    // Pick the top-level visible region with the most physically contained
    // entities, then measure a real expansion rather than only the coarse 12-node overview.
    const descendantCounts = new Int32Array(world.pointCount);
    for (let point = 0; point < world.pointCount; point++) {
      let ancestor = point;
      while (ancestor >= 0) {
        descendantCounts[ancestor] = (descendantCounts[ancestor] ?? 0) + 1;
        ancestor = worldTree.containerOf[ancestor] ?? -1;
      }
    }
    const largestRegion = [...built.candidates].toSorted((a, b) =>
      (descendantCounts[world.indexById.get(b) ?? -1] ?? 0) -
      (descendantCounts[world.indexById.get(a) ?? -1] ?? 0) || a.localeCompare(b))[0];
    if (largestRegion !== undefined) {
      const expanded = expand(worldTree, initialFrontier(), largestRegion);
      measure(`${name}:expanded`, buildNeighborhoodIndex(
        projectFrontier(world, worldTree, expanded, ["imports", "calls"]), worldTree,
      ));
    }
  });
});
