/**
 * Laws of the frontier region metrics (VAL-METRIC-001..009): the exact formulas
 * of app/src/frontier/metrics.ts are pinned by known-answer fixtures over a
 * scripted expand/collapse sequence, ingress/egress stay separate with
 * boundary == ingress + egress, localness defines the 0/0 -> 1 rule,
 * double-counting rules are exact, reach_1 <= reach_2 <= reach_3 counts distinct
 * projected neighbour regions, the enabled relation set is respected, metrics
 * are a pure function of (world, relations, frontier), and the whole thing is
 * spot-checked against an independent path-based derivation over the staged
 * preact tables.
 */
import { beforeAll, describe, expect, it } from "vitest";

import type { ViewerGraph } from "../../projection/src/graph.ts";
import { projectWorld } from "../../projection/src/project.ts";
import { decodeWorldFiles, type WorldTables } from "../../projection/src/tables.ts";
import { readWorldDir } from "../../projection/src/world_dir.ts";
import { containmentTree, type ContainmentTree } from "../src/frontier/containment.ts";
import { collapse, expand, initialFrontier, type VisibleFrontier } from "../src/frontier/frontier.ts";
import { computeProjectionMetrics, type RegionMetrics } from "../src/frontier/metrics.ts";
import { projectFrontier } from "../src/frontier/wires.ts";
import { FIXTURE_IDS, frontierFixtureGraph } from "./frontierFixture.ts";

const LAYOUT_WORLDS = "../projection/layout_worlds";
const PREACT = "6e2bef41bf19f638be084df8cb82127e4832d4abbafa8ca20ebd5db9be3ac8a9";

const ID = FIXTURE_IDS;
const BOTH = ["imports", "calls"] as const;

/** Containing directory of a path, per the evidence path convention. */
function containingPath(path: string): string {
  const slash = path.lastIndexOf("/");
  return slash < 0 ? "" : path.slice(0, slash);
}

interface ExpectedMetrics {
  readonly internal: number;
  readonly egress: number;
  readonly ingress: number;
  readonly peers: number;
  readonly localness: number;
  readonly reach: readonly [number, number, number];
}

function metricsAt(
  graph: ViewerGraph,
  tree: ContainmentTree,
  frontier: VisibleFrontier,
  enabled: readonly ("imports" | "calls")[] = BOTH,
): ReadonlyMap<string, RegionMetrics> {
  return computeProjectionMetrics(graph, tree, projectFrontier(graph, tree, frontier, enabled));
}

/** Asserts every pinned quantity, plus the structural identities, of one region. */
function expectRegion(
  metrics: ReadonlyMap<string, RegionMetrics>,
  region: string,
  expected: ExpectedMetrics,
): void {
  const actual = metrics.get(region);
  if (actual === undefined) throw new Error(`no metrics for region ${region}`);
  expect(actual.region).toBe(region);
  expect(actual.internal, `${region}.internal`).toBe(expected.internal);
  expect(actual.egress, `${region}.egress`).toBe(expected.egress);
  expect(actual.ingress, `${region}.ingress`).toBe(expected.ingress);
  expect(actual.boundary, `${region}.boundary == ingress + egress`).toBe(expected.ingress + expected.egress);
  expect(actual.peers, `${region}.peers`).toBe(expected.peers);
  expect(actual.localness, `${region}.localness`).toBe(expected.localness);
  expect(actual.reach, `${region}.reach`).toEqual(expected.reach);
  expect(actual.reach[0], `${region} reach monotone 1..2`).toBeLessThanOrEqual(actual.reach[1]);
  expect(actual.reach[1], `${region} reach monotone 2..3`).toBeLessThanOrEqual(actual.reach[2]);
  // Per-relation breakdowns sum exactly to the relation-blind totals.
  expect(actual.internalByRelation.imports + actual.internalByRelation.calls).toBe(actual.internal);
  expect(actual.egressByRelation.imports + actual.egressByRelation.calls).toBe(actual.egress);
  expect(actual.ingressByRelation.imports + actual.ingressByRelation.calls).toBe(actual.ingress);
}

describe("region metrics on the hand-made fixture (VAL-METRIC-001/002)", () => {
  const graph = frontierFixtureGraph();
  const tree = containmentTree(graph);

  it("computes the hand-computed vectors at the default frontier", () => {
    const metrics = metricsAt(graph, tree, initialFrontier());
    expect([...metrics.keys()].toSorted((a, b) => a.localeCompare(b))).toEqual(
      [ID.topFile, ID.a, ID.b, ID.c].toSorted((a, b) => a.localeCompare(b)),
    );
    expectRegion(metrics, ID.a, {
      internal: 4,
      egress: 4,
      ingress: 1,
      peers: 1,
      localness: 4 / 9,
      reach: [1, 2, 2],
    });
    expectRegion(metrics, ID.b, {
      internal: 0,
      egress: 2,
      ingress: 4,
      peers: 2,
      localness: 0,
      reach: [2, 2, 2],
    });
    expectRegion(metrics, ID.topFile, {
      internal: 2,
      egress: 0,
      ingress: 1,
      peers: 1,
      localness: 2 / 3,
      reach: [0, 0, 0],
    });
    // The empty directory is the isolated region: the 0/0 rule gives localness 1.
    expectRegion(metrics, ID.c, {
      internal: 0,
      egress: 0,
      ingress: 0,
      peers: 0,
      localness: 1,
      reach: [0, 0, 0],
    });
  });

  it("keeps the per-relation breakdown exact and separable (VAL-METRIC-003/005)", () => {
    const metrics = metricsAt(graph, tree, initialFrontier());
    const a = metrics.get(ID.a);
    expect(a?.internalByRelation).toEqual({ imports: 2, calls: 2 });
    expect(a?.egressByRelation).toEqual({ imports: 3, calls: 1 });
    expect(a?.ingressByRelation).toEqual({ imports: 1, calls: 0 });
    const b = metrics.get(ID.b);
    expect(b?.internalByRelation).toEqual({ imports: 0, calls: 0 });
    expect(b?.egressByRelation).toEqual({ imports: 1, calls: 1 });
    expect(b?.ingressByRelation).toEqual({ imports: 3, calls: 1 });
  });

  it("counts a nested-boundary crossing at each visible boundary it crosses (VAL-METRIC-005)", () => {
    // With `a` expanded, a/sub is its own visible region: the a/sub/z.ts -> b/w.ts
    // edges cross the visible boundaries of a/sub AND of a, and are counted at both.
    const metrics = metricsAt(graph, tree, expand(tree, initialFrontier(), ID.a));
    const sub = metrics.get(ID.sub);
    const a = metrics.get(ID.a);
    // egress(a/sub) = { imports row 7, calls row 14 } = 2; egress(a) adds the two
    // a/y.ts -> b/w.ts duplicates: 4. Both include row 7 / row 14.
    expect(sub?.egress).toBe(2);
    expect(sub?.egressByRelation).toEqual({ imports: 1, calls: 1 });
    expect(a?.egress).toBe(4);
    expect(a?.egressByRelation).toEqual({ imports: 3, calls: 1 });
    // The edges internal to a/sub's parent never touch a/sub's boundary counters...
    expect(sub?.internal).toBe(0);
    // ...and self-loops are internalized, contributing to no boundary counter:
    // top.ts has internal 2 (the import and the call self-loops) and boundary 1
    // (only the wa -> top call crosses in).
    const top = metrics.get(ID.topFile);
    expect(top?.internal).toBe(2);
    expect(top?.boundary).toBe(1);
    // The file grain: a/x.ts holds the xa -> xb call internally.
    expectRegion(metrics, ID.xFile, {
      internal: 1,
      egress: 3,
      ingress: 1,
      peers: 3,
      localness: 1 / 5,
      reach: [2, 3, 4],
    });
    expectRegion(metrics, ID.yFile, {
      internal: 0,
      egress: 2,
      ingress: 1,
      peers: 2,
      localness: 0,
      reach: [1, 3, 4],
    });
    expectRegion(metrics, ID.sub, {
      internal: 0,
      egress: 2,
      ingress: 2,
      peers: 2,
      localness: 0,
      reach: [1, 3, 4],
    });
    expectRegion(metrics, ID.b, {
      internal: 0,
      egress: 2,
      ingress: 4,
      peers: 4,
      localness: 0,
      reach: [2, 4, 4],
    });
    // `a` itself no longer exchanges directly: its traffic decomposed to its children.
    expectRegion(metrics, ID.a, {
      internal: 4,
      egress: 4,
      ingress: 1,
      peers: 0,
      localness: 4 / 9,
      reach: [0, 0, 0],
    });
  });

  it("counts reach over projected wires at the symbol grain too (VAL-METRIC-006)", () => {
    let frontier = expand(tree, initialFrontier(), ID.a);
    frontier = expand(tree, frontier, ID.xFile);
    const metrics = metricsAt(graph, tree, frontier);
    expectRegion(metrics, ID.xaSym, {
      internal: 0,
      egress: 2,
      ingress: 0,
      peers: 2,
      localness: 0,
      reach: [2, 3, 5],
    });
    expectRegion(metrics, ID.xbSym, {
      internal: 0,
      egress: 0,
      ingress: 1,
      peers: 1,
      localness: 0,
      reach: [0, 0, 0],
    });
    // Revealing the symbols does not change their file's membership counters.
    expectRegion(metrics, ID.xFile, {
      internal: 1,
      egress: 3,
      ingress: 1,
      peers: 3,
      localness: 1 / 5,
      reach: [2, 3, 4],
    });
  });

  it("respects the enabled relation set (VAL-METRIC-007)", () => {
    const importsOnly = metricsAt(graph, tree, initialFrontier(), ["imports"]);
    expectRegion(importsOnly, ID.a, {
      internal: 2,
      egress: 3,
      ingress: 1,
      peers: 1,
      localness: 1 / 3,
      reach: [1, 1, 1],
    });
    expectRegion(importsOnly, ID.b, {
      internal: 0,
      egress: 1,
      ingress: 3,
      peers: 1,
      localness: 0,
      reach: [1, 1, 1],
    });
    expectRegion(importsOnly, ID.topFile, {
      internal: 1,
      egress: 0,
      ingress: 0,
      peers: 0,
      localness: 1,
      reach: [0, 0, 0],
    });
    // A disabled relation never leaks into a breakdown.
    const a = importsOnly.get(ID.a);
    expect(a?.internalByRelation).toEqual({ imports: 2, calls: 0 });
    expect(a?.egressByRelation).toEqual({ imports: 3, calls: 0 });
    expect(a?.ingressByRelation).toEqual({ imports: 1, calls: 0 });
    // Re-enabling calls restores the both-relations answers exactly.
    expectRegion(metricsAt(graph, tree, initialFrontier(), BOTH), ID.a, {
      internal: 4,
      egress: 4,
      ingress: 1,
      peers: 1,
      localness: 4 / 9,
      reach: [1, 2, 2],
    });
  });

  it("is a pure function of (world, relations, frontier), not of history (VAL-METRIC-009)", () => {
    const sequence: VisibleFrontier[] = [initialFrontier()];
    let current = sequence[0] ?? initialFrontier();
    current = expand(tree, current, ID.a);
    sequence.push(current);
    current = expand(tree, current, ID.sub);
    sequence.push(current);
    current = expand(tree, current, ID.zFile);
    sequence.push(current);
    current = collapse(tree, current, ID.sub);
    sequence.push(current);
    current = collapse(tree, current, ID.a);
    sequence.push(current);
    for (const frontier of sequence) {
      const first = metricsAt(graph, tree, frontier);
      const second = metricsAt(graph, tree, frontier);
      expect([...second.entries()]).toEqual([...first.entries()]);
    }
    // The round trip lands back on the default answers...
    const restored = metricsAt(graph, tree, sequence[sequence.length - 1] ?? initialFrontier());
    expectRegion(restored, ID.a, {
      internal: 4,
      egress: 4,
      ingress: 1,
      peers: 1,
      localness: 4 / 9,
      reach: [1, 2, 2],
    });
    // ...and the same expanded set reached through a different history (different
    // revision) yields the identical metric vectors.
    let detour = expand(tree, initialFrontier(), ID.b);
    detour = collapse(tree, detour, ID.b);
    detour = expand(tree, detour, ID.a);
    const direct = expand(tree, initialFrontier(), ID.a);
    expect(detour.revision).not.toBe(direct.revision);
    expect([...metricsAt(graph, tree, detour).entries()]).toEqual([
      ...metricsAt(graph, tree, direct).entries(),
    ]);
  });
});

describe("region metrics on the real preact world (VAL-METRIC-003/004/008)", () => {
  let graph: ViewerGraph;
  let tree: ContainmentTree;
  let tables: WorldTables;

  beforeAll(async () => {
    const files = await readWorldDir(`${LAYOUT_WORLDS}/${PREACT}`);
    graph = await projectWorld(files);
    tree = containmentTree(graph);
    tables = await decodeWorldFiles(files);
  });

  /**
   * The independent derivation: region membership from entity paths and the
   * locations table alone (never the frontier modules), then per-region
   * counters straight from the relations rows.
   */
  function oracle(): Map<string, ExpectedMetrics & { boundary: number }> {
    const locations = tables.locations;
    if (locations === null) throw new Error("preact ships a locations table");
    const directoryPathById = new Map<number, string>();
    for (const row of locations) {
      if (row.kind === "directory") directoryPathById.set(row.locationId, row.path);
    }
    const fileIdByPath = new Map<string, string>();
    for (const entity of tables.entities) {
      if (entity.domain === "file") fileIdByPath.set(entity.path, `file:${entity.entityId}`);
    }
    // Top-level region of one entity path: the root-anchored file that holds the
    // entity, or the highest directory below the root.
    const regionOfPath = (path: string): string => {
      let directory = containingPath(path);
      if (directory === "") {
        const file = fileIdByPath.get(path);
        if (file === undefined) throw new Error(`no file row for root-anchored ${path}`);
        return file;
      }
      let parent = containingPath(directory);
      while (parent !== "") {
        directory = parent;
        parent = containingPath(directory);
      }
      for (const [id, candidate] of directoryPathById) {
        if (candidate === directory) return `location:${id}`;
      }
      throw new Error(`no directory row for ${directory}`);
    };
    const entityRegion = new Map<string, string>();
    for (const entity of tables.entities) {
      entityRegion.set(`${entity.domain}:${entity.entityId}`, regionOfPath(entity.path));
    }
    interface Counters {
      internal: number;
      egress: number;
      ingress: number;
    }
    const counters = new Map<string, Counters>();
    const counter = (region: string): Counters => {
      const existing = counters.get(region);
      if (existing !== undefined) return existing;
      const created = { internal: 0, egress: 0, ingress: 0 };
      counters.set(region, created);
      return created;
    };
    const wires = new Map<string, number>();
    // Seed every top-level region, even one that exchanges nothing, so the
    // oracle population matches the projected node set exactly.
    for (const region of entityRegion.values()) counter(region);
    for (const row of tables.relations) {
      if (row.relation !== "imports" && row.relation !== "calls") continue;
      const source = entityRegion.get(`${row.sourceDomain}:${row.sourceId}`);
      const target = entityRegion.get(`${row.targetDomain}:${row.targetId}`);
      if (source === undefined || target === undefined) throw new Error("unresolved oracle endpoint");
      if (source === target) {
        counter(source).internal += 1;
        continue;
      }
      counter(source).egress += 1;
      counter(target).ingress += 1;
      const key = `${source}|${target}`;
      wires.set(key, (wires.get(key) ?? 0) + 1);
    }
    // Peers (either direction) and directed reach over the oracle wires.
    const out = new Map<string, Set<string>>();
    const inbound = new Map<string, Set<string>>();
    for (const key of wires.keys()) {
      const [source, target] = key.split("|");
      if (source === undefined || target === undefined) throw new Error("bad key");
      if (!out.has(source)) out.set(source, new Set());
      out.get(source)?.add(target);
      if (!inbound.has(target)) inbound.set(target, new Set());
      inbound.get(target)?.add(source);
    }
    const regions = new Set([...counters.keys(), ...out.keys(), ...inbound.keys()]);
    const result = new Map<string, ExpectedMetrics & { boundary: number }>();
    for (const region of regions) {
      const seen = new Set<string>([region]);
      let frontierSet = new Set<string>([region]);
      const reach: [number, number, number] = [0, 0, 0];
      for (let depth = 0; depth < 3; depth++) {
        const next = new Set<string>();
        for (const node of frontierSet) {
          for (const neighbour of out.get(node) ?? []) {
            if (!seen.has(neighbour)) {
              seen.add(neighbour);
              next.add(neighbour);
            }
          }
        }
        reach[depth] = seen.size - 1;
        frontierSet = next;
      }
      const { internal = 0, egress = 0, ingress = 0 } = counters.get(region) ?? {};
      const boundary = ingress + egress;
      const peers = new Set([...(out.get(region) ?? []), ...(inbound.get(region) ?? [])]).size;
      result.set(region, {
        internal,
        egress,
        ingress,
        boundary,
        peers,
        localness: internal + boundary === 0 ? 1 : internal / (internal + boundary),
        reach,
      });
    }
    return result;
  }

  it("matches the independent path-based derivation for every top-level region (VAL-METRIC-008)", () => {
    const expected = oracle();
    const metrics = metricsAt(graph, tree, initialFrontier());
    expect(metrics.size).toBe(expected.size);
    for (const [region, oracleVector] of expected) {
      const actual = metrics.get(region);
      if (actual === undefined) throw new Error(`metrics module is missing region ${region}`);
      expect(actual.internal, `${region}.internal`).toBe(oracleVector.internal);
      expect(actual.egress, `${region}.egress`).toBe(oracleVector.egress);
      expect(actual.ingress, `${region}.ingress`).toBe(oracleVector.ingress);
      expect(actual.boundary, `${region}.boundary`).toBe(oracleVector.boundary);
      expect(actual.peers, `${region}.peers`).toBe(oracleVector.peers);
      expect(actual.localness, `${region}.localness`).toBe(oracleVector.localness);
      expect([...actual.reach], `${region}.reach`).toEqual([...oracleVector.reach]);
    }
  });

  it("keeps ingress and egress separate with boundary their exact sum (VAL-METRIC-003)", () => {
    const metrics = metricsAt(graph, tree, initialFrontier());
    expect(metrics.size).toBeGreaterThan(1);
    for (const region of metrics.values()) {
      expect(region.boundary).toBe(region.ingress + region.egress);
      expect(region.localness).toBeGreaterThanOrEqual(0);
      expect(region.localness).toBeLessThanOrEqual(1);
      if (region.internal === 0 && region.boundary === 0) expect(region.localness).toBe(1);
      else expect(region.localness).toBe(region.internal / (region.internal + region.boundary));
    }
  });
});
