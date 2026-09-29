import { describe, expect, it } from "vitest";

import { containmentTree } from "../src/frontier/containment.ts";
import { initialFrontier } from "../src/frontier/frontier.ts";
import { inspectWire } from "../src/frontier/inspector.ts";
import { projectFrontier } from "../src/frontier/wires.ts";
import { FIXTURE_IDS, frontierFixtureGraph } from "./frontierFixture.ts";

describe("projected wire inspection", () => {
  const graph = frontierFixtureGraph();
  const projection = projectFrontier(graph, containmentTree(graph), initialFrontier(), ["imports", "calls"]);
  const wire = projection.wires.find(
    (candidate) => candidate.source === FIXTURE_IDS.a && candidate.target === FIXTURE_IDS.b && candidate.relation === "imports",
  );
  if (wire === undefined) throw new Error("fixture has no a → b imports wire");

  it("derives every summary count from the three exact crossing rows", () => {
    const detail = inspectWire(graph, wire);
    expect(detail).toMatchObject({
      source: "a",
      target: "b",
      relation: "imports",
      multiplicity: 3,
      uniqueSources: 2,
      uniqueTargets: 1,
      boundary: true,
      remaining: 0,
    });
    expect(detail.contributions.map((entry) => [entry.row, entry.source, entry.target])).toEqual([
      [7, "a/sub/z.ts", "b/w.ts"],
      [10, "a/y.ts", "b/w.ts"],
      [11, "a/y.ts", "b/w.ts"],
    ]);
  });

  it("bounds the constituent list and reports the exact remainder", () => {
    const detail = inspectWire(graph, wire, 2);
    expect(detail.contributions).toHaveLength(2);
    expect(detail.remaining).toBe(1);
    expect(detail.multiplicity).toBe(3);
    expect(detail.uniqueSources).toBe(2);
  });

  it("rejects a wire whose backing row is absent or of the wrong relation", () => {
    expect(() => inspectWire(graph, { ...wire, provenance: [999], multiplicity: 1 })).toThrow(/no matching/);
    expect(() => inspectWire(graph, { ...wire, provenance: [12], multiplicity: 1 })).toThrow(/no matching/);
  });
});
