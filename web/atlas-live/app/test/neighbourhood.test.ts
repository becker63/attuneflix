import { describe, expect, it } from "vitest";

import { RELATION_ORDER } from "../../projection/src/relation.ts";
import { degree, highlightIds, incidentCounts, neighbourhood } from "../src/neighbourhood.ts";
import { fixtureGraph } from "./graphFixture.ts";

describe("neighbourhood", () => {
  const graph = fixtureGraph();

  it("returns the point, its incident links and its neighbours", () => {
    // symbol:0 is renderer index 2: inbound defines (link 0), inbound and
    // outbound calls (links 4 and 3) with symbol:1 (index 3).
    const highlight = neighbourhood(graph, 2, RELATION_ORDER);
    expect(highlight.points).toEqual([0, 2, 3]);
    expect(highlight.links).toEqual([0, 3, 4]);
  });

  it("respects the enabled relations", () => {
    expect(neighbourhood(graph, 2, ["defines"]).points).toEqual([0, 2]);
    expect(neighbourhood(graph, 2, ["defines"]).links).toEqual([0]);
    expect(neighbourhood(graph, 2, ["calls"]).links).toEqual([3, 4]);
    expect(neighbourhood(graph, 2, []).points).toEqual([2]);
    expect(neighbourhood(graph, 2, []).links).toEqual([]);
  });

  it("gives per-relation incident counts", () => {
    const counts = incidentCounts(graph, 2);
    expect(counts.defines).toEqual({ in: 1, out: 0 });
    expect(counts.imports).toEqual({ in: 0, out: 0 });
    expect(counts.calls).toEqual({ in: 1, out: 1 });
    expect(counts.parent).toEqual({ in: 0, out: 0 });
    expect(degree(graph, 2, RELATION_ORDER)).toBe(3);
  });

  it("maps a highlight to namespaced point ids", () => {
    expect(highlightIds(graph, neighbourhood(graph, 2, RELATION_ORDER))).toEqual([
      "file:0",
      "symbol:0",
      "symbol:1",
    ]);
  });
});
