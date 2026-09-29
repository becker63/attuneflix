import { describe, expect, it } from "vitest";

import { viewportWires, zoomWireBudget } from "../src/zoomWires.ts";

describe("large-graph connection visibility", () => {
  it("admits a bounded number of exact wires as zoom increases", () => {
    expect(zoomWireBudget(1)).toBe(0);
    expect(zoomWireBudget(1.25)).toBeGreaterThan(0);
    expect(zoomWireBudget(4)).toBeGreaterThan(zoomWireBudget(2));
    expect(zoomWireBudget(100)).toBe(10_000);
  });

  it("prioritizes on-screen endpoints and excludes wires that miss the viewport", () => {
    const points = new Map([
      [0, { x: -5, y: 30 }],
      [1, { x: 30, y: -5 }], // Bounding box overlaps; the segment misses 0..10.
      [2, { x: 2, y: 2 }],
      [3, { x: 20, y: 20 }],
      [4, { x: -5, y: 5 }],
      [5, { x: 15, y: 5 }],
      [6, { x: 1, y: 1 }],
      [7, { x: 9, y: 9 }],
    ]);
    const wires = [
      { sourceIndex: 0, targetIndex: 1, multiplicity: 100 },
      { sourceIndex: 2, targetIndex: 3, multiplicity: 1 },
      { sourceIndex: 4, targetIndex: 5, multiplicity: 50 },
      { sourceIndex: 6, targetIndex: 7, multiplicity: 3 },
    ];
    const screenOf = (index: number) => points.get(index) ?? null;
    expect([...viewportWires(wires, screenOf, 10, 10, 2)]).toEqual([3, 1]);
    expect([...viewportWires(wires, screenOf, 10, 10, 3)]).toEqual([3, 1, 2]);
  });
});
