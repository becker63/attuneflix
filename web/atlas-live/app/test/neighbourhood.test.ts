import { describe, expect, it } from "vitest";

import { RELATION_ORDER } from "../../projection/src/relation.ts";
import {
  degree,
  highlightIds,
  incidentCounts,
  incidentLinks,
  multiSourceHighlight,
  neighbourhood,
  neighbourhoodAtDepth,
} from "../src/neighbourhood.ts";
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

  it("equals the depth-1 neighbourhood at depth 1", () => {
    expect(neighbourhoodAtDepth(graph, 2, RELATION_ORDER, 1)).toEqual(
      neighbourhood(graph, 2, RELATION_ORDER),
    );
  });

  it("expands by BFS layers over the enabled relations", () => {
    // From symbol:0, two hops over every relation reaches file:0, file:1,
    // symbol:1 and the root directory (via parent through file:0), and the
    // links traversed are 0..5.
    expect(neighbourhoodAtDepth(graph, 2, RELATION_ORDER, 2)).toEqual({
      points: [0, 1, 2, 3, 4],
      links: [0, 1, 2, 3, 4, 5],
    });
    // A third hop reaches the "src/" directory (index 5) and links 6 and 7.
    expect(neighbourhoodAtDepth(graph, 2, RELATION_ORDER, 3)).toEqual({
      points: [0, 1, 2, 3, 4, 5],
      links: [0, 1, 2, 3, 4, 5, 6, 7],
    });
    // Two hops over calls only never leaves the {symbol:0, symbol:1} pair.
    expect(neighbourhoodAtDepth(graph, 2, ["calls"], 2)).toEqual({ points: [2, 3], links: [3, 4] });
  });

  it("takes the union of the sources' neighbourhoods", () => {
    // symbol:0 (index 2) and file:1 (index 1) are each reached by a defines
    // link from the other side, so the union is file:0, file:1, symbol:0, symbol:1.
    expect(multiSourceHighlight(graph, [2, 1], ["defines"], 1)).toEqual({
      points: [0, 1, 2, 3],
      links: [0, 1],
    });
    expect(multiSourceHighlight(graph, [2, 3], RELATION_ORDER, 1)).toEqual({
      points: [0, 1, 2, 3],
      links: [0, 1, 3, 4],
    });
    expect(multiSourceHighlight(graph, [], RELATION_ORDER, 2)).toEqual({ points: [], links: [] });
  });

  it("collects incident links of a set of points under the enabled relations", () => {
    expect(incidentLinks(graph, [2], RELATION_ORDER)).toEqual([0, 3, 4]);
    expect(incidentLinks(graph, [2], ["calls"])).toEqual([3, 4]);
    expect(incidentLinks(graph, [2], ["calls", "defines"])).toEqual([0, 3, 4]);
    expect(incidentLinks(graph, [0, 1], ["imports"])).toEqual([2]);
    expect(incidentLinks(graph, [], RELATION_ORDER)).toEqual([]);
  });
});
