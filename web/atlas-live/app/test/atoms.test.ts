import { createStore } from "jotai";
import { beforeEach, describe, expect, it } from "vitest";

import { RELATION_ORDER } from "../../projection/src/relation.ts";
import {
  activeLegendAtom,
  adoptGraphAtom,
  clearSelectionAtom,
  emphasisAtom,
  filterRevisionAtom,
  graphAtom,
  hoveredIndexAtom,
  hoveredNeighbourhoodAtom,
  incidentEdgesAtom,
  neighbourhoodDepthAtom,
  measurementModeAtom,
  relationMaskAtom,
  selectedAtom,
  selectedIndicesAtom,
  selectedProvenanceAtom,
  selectionHighlightAtom,
  setDepthAtom,
  setRelationMaskAtom,
  toggleSelectedAtom,
  visibleRelationSetAtom,
} from "../src/atoms.ts";
import { ALL_RELATIONS_MASK, relationMask, sortedSelection } from "../src/selection.ts";
import { fixtureGraph } from "./graphFixture.ts";

describe("viewer state atoms", () => {
  const store = createStore();

  beforeEach(() => {
    store.set(adoptGraphAtom, fixtureGraph());
    store.set(selectedAtom, new Set<string>());
    store.set(relationMaskAtom, ALL_RELATIONS_MASK);
    store.set(neighbourhoodDepthAtom, 1);
    store.set(hoveredIndexAtom, null);
  });

  it("derives the hovered neighbourhood from the enabled relations only", () => {
    store.set(hoveredIndexAtom, 2);
    expect(store.get(hoveredNeighbourhoodAtom)).toEqual({ points: [0, 2, 3], links: [0, 3, 4] });
    store.set(setRelationMaskAtom, relationMask(["defines"]));
    expect(store.get(visibleRelationSetAtom)).toEqual(["defines"]);
    expect(store.get(hoveredNeighbourhoodAtom)).toEqual({ points: [0, 2], links: [0] });
    expect(store.get(filterRevisionAtom)).toBe(1);
  });

  it("derives the incident edges of the pinned selection from the enabled relations only", () => {
    store.set(toggleSelectedAtom, "symbol:0");
    expect(sortedSelection(store.get(selectedAtom))).toEqual(["symbol:0"]);
    expect(store.get(selectedIndicesAtom)).toEqual([2]);
    expect(store.get(incidentEdgesAtom)).toEqual([0, 3, 4]);
    store.set(setRelationMaskAtom, relationMask(["calls"]));
    expect(store.get(incidentEdgesAtom)).toEqual([3, 4]);
    expect(store.get(selectionHighlightAtom)).toEqual({ points: [2, 3], links: [3, 4] });
  });

  it("emphasises the hovered neighbourhood unioned with the pinned selection", () => {
    expect(store.get(emphasisAtom)).toEqual({ points: [], links: [] });
    store.set(hoveredIndexAtom, 2);
    expect(store.get(emphasisAtom)).toEqual({ points: [0, 2, 3], links: [0, 3, 4] });
    store.set(toggleSelectedAtom, "symbol:1");
    // symbol:1 (index 3) is joined to symbol:0 by a calls link, but its own
    // neighbourhood also reaches file:1 (index 1) through defines.
    expect(store.get(emphasisAtom)).toEqual({ points: [0, 1, 2, 3], links: [0, 1, 3, 4] });
    store.set(hoveredIndexAtom, null);
    expect(store.get(emphasisAtom)).toEqual({ points: [1, 2, 3], links: [1, 3, 4] });
  });

  it("grows the neighbourhood with the depth control and clamps the depth", () => {
    store.set(hoveredIndexAtom, 2);
    store.set(setDepthAtom, 2);
    expect(store.get(neighbourhoodDepthAtom)).toBe(2);
    expect(store.get(hoveredNeighbourhoodAtom)).toEqual({
      points: [0, 1, 2, 3, 4],
      links: [0, 1, 2, 3, 4, 5],
    });
    store.set(setDepthAtom, 9);
    expect(store.get(neighbourhoodDepthAtom)).toBe(3);
    store.set(setDepthAtom, 0);
    expect(store.get(neighbourhoodDepthAtom)).toBe(1);
  });

  it("keeps the pinned selection across overlay, filter and hover changes", () => {
    store.set(toggleSelectedAtom, "file:0");
    const pinned = store.get(selectedAtom);
    store.set(measurementModeAtom, "locality");
    store.set(setRelationMaskAtom, relationMask(["parent"]));
    store.set(hoveredIndexAtom, 5);
    store.set(hoveredIndexAtom, null);
    expect(store.get(selectedAtom)).toBe(pinned);
    expect(sortedSelection(store.get(selectedAtom))).toEqual(["file:0"]);
  });

  it("never changes the projected topology when a relation is toggled", () => {
    const graph = store.get(graphAtom);
    store.set(setRelationMaskAtom, relationMask(["defines"]));
    expect(store.get(graphAtom)).toBe(graph);
    expect(store.get(graphAtom)?.pointIds).toBe(graph?.pointIds);
    expect(store.get(graphAtom)?.linkSourceIndices).toBe(graph?.linkSourceIndices);
    expect(store.get(graphAtom)?.linkTargetIndices).toBe(graph?.linkTargetIndices);
  });

  it("drops a pinned selection the newly adopted graph does not contain", () => {
    store.set(selectedAtom, new Set(["file:0", "symbol:99"]));
    expect(store.get(selectedIndicesAtom)).toEqual([0]);
    store.set(adoptGraphAtom, fixtureGraph());
    expect(sortedSelection(store.get(selectedAtom))).toEqual(["file:0"]);
    store.set(clearSelectionAtom);
    expect(sortedSelection(store.get(selectedAtom))).toEqual([]);
  });

  it("reports the selected entities' provenance records", () => {
    store.set(selectedAtom, new Set(["symbol:1", "file:0"]));
    const records = store.get(selectedProvenanceAtom);
    expect(records.map((record) => record.id)).toEqual(["file:0", "symbol:1"]);
    expect(records[0]).toMatchObject({ domain: "file", path: "a.ts", name: null });
    expect(records[1]).toMatchObject({ domain: "symbol", path: "b.ts", name: "beta" });
    expect(records[1]?.counts.calls).toEqual({ in: 1, out: 1 });
  });

  it("marks disabled relations in the active legend", () => {
    expect(store.get(activeLegendAtom).filter((entry) => entry.kind === "relation")).toHaveLength(4);
    store.set(setRelationMaskAtom, relationMask(["defines", "parent"]));
    const relations = store.get(activeLegendAtom).filter((entry) => entry.kind === "relation");
    expect(relations.map((entry) => [entry.key, entry.disabled ?? false])).toEqual([
      ["defines", false],
      ["imports", true],
      ["calls", true],
      ["parent", false],
    ]);
    expect(RELATION_ORDER).toHaveLength(4);
  });
});
