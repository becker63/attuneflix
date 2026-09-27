import { describe, expect, it } from "vitest";

import { RELATION_ORDER } from "../../projection/src/relation.ts";
import {
  ALL_RELATIONS_MASK,
  DEFAULT_DEPTH,
  EMPTY_SELECTION,
  MAX_DEPTH,
  MIN_DEPTH,
  clampDepth,
  clickSelection,
  isRelationEnabled,
  maskedRelations,
  pruneSelection,
  relationMask,
  selectOnly,
  selectionIndices,
  sortedSelection,
  toggleRelation,
  toggleSelection,
} from "../src/selection.ts";
import { fixtureGraph } from "./graphFixture.ts";

describe("pinned selection", () => {
  it("pins exactly one entity on a plain click and replaces the previous one", () => {
    const first = clickSelection(EMPTY_SELECTION, "file:0", false);
    expect(sortedSelection(first)).toEqual(["file:0"]);
    const second = clickSelection(first, "symbol:1", false);
    expect(sortedSelection(second)).toEqual(["symbol:1"]);
  });

  it("adds and removes with the modifier", () => {
    const both = clickSelection(clickSelection(EMPTY_SELECTION, "file:0", false), "symbol:1", true);
    expect(sortedSelection(both)).toEqual(["file:0", "symbol:1"]);
    const removed = clickSelection(both, "file:0", true);
    expect(sortedSelection(removed)).toEqual(["symbol:1"]);
    expect(sortedSelection(clickSelection(removed, "symbol:1", true))).toEqual([]);
  });

  it("never mutates the input selection", () => {
    const original = selectOnly("file:0");
    const next = toggleSelection(original, "symbol:0");
    expect(sortedSelection(original)).toEqual(["file:0"]);
    expect(sortedSelection(next)).toEqual(["file:0", "symbol:0"]);
  });

  it("resolves selection ids to renderer indices and ignores unknown ids", () => {
    const graph = fixtureGraph();
    const selected = new Set(["symbol:1", "file:0", "symbol:99"]);
    expect(selectionIndices(graph, selected)).toEqual([0, 3]);
    expect(selectionIndices(null, selected)).toEqual([]);
  });

  it("drops ids the new graph does not contain", () => {
    const graph = fixtureGraph();
    const selected = new Set(["file:0", "symbol:99"]);
    expect(sortedSelection(pruneSelection(selected, graph))).toEqual(["file:0"]);
    expect(pruneSelection(EMPTY_SELECTION, graph).size).toBe(0);
  });
});

describe("relation filter", () => {
  it("round-trips a mask through the canonical relation order", () => {
    expect(maskedRelations(ALL_RELATIONS_MASK)).toEqual([...RELATION_ORDER]);
    expect(maskedRelations(relationMask(["calls", "defines"]))).toEqual(["defines", "calls"]);
    expect(maskedRelations(relationMask([]))).toEqual([]);
  });

  it("toggles one relation without touching the others", () => {
    const withoutCalls = toggleRelation(ALL_RELATIONS_MASK, "calls");
    expect(isRelationEnabled(withoutCalls, "calls")).toBe(false);
    for (const relation of RELATION_ORDER) {
      if (relation !== "calls") expect(isRelationEnabled(withoutCalls, relation)).toBe(true);
    }
    expect(maskedRelations(toggleRelation(withoutCalls, "calls"))).toEqual([...RELATION_ORDER]);
  });
});

describe("neighbourhood depth", () => {
  it("clamps to the supported 1..3 range", () => {
    expect(MIN_DEPTH).toBe(1);
    expect(MAX_DEPTH).toBe(3);
    expect(DEFAULT_DEPTH).toBe(1);
    expect(clampDepth(0)).toBe(1);
    expect(clampDepth(-4)).toBe(1);
    expect(clampDepth(2)).toBe(2);
    expect(clampDepth(3.9)).toBe(3);
    expect(clampDepth(9)).toBe(3);
    expect(clampDepth(Number.NaN)).toBe(1);
  });
});
