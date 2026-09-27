import { describe, expect, it } from "vitest";

import { computeLayout } from "../src/layout.ts";
import { fixtureGraph } from "./graphFixture.ts";

describe("deterministic layout", () => {
  const graph = fixtureGraph();

  it("returns one interleaved coordinate pair per point", () => {
    const xy = computeLayout(graph);
    expect(xy.length).toBe(graph.pointCount * 2);
    for (const value of xy) expect(Number.isFinite(value)).toBe(true);
  });

  it("is deterministic for the same graph", () => {
    expect(Array.from(computeLayout(graph))).toEqual(Array.from(computeLayout(graph)));
  });

  it("spreads points across the canvas", () => {
    const xy = computeLayout(graph);
    const xs: number[] = [];
    const ys: number[] = [];
    for (let i = 0; i < graph.pointCount; i++) {
      xs.push(xy[i * 2] ?? 0);
      ys.push(xy[i * 2 + 1] ?? 0);
    }
    expect(Math.max(...xs) - Math.min(...xs)).toBeGreaterThan(100);
    expect(Math.max(...ys) - Math.min(...ys)).toBeGreaterThan(50);
  });
});
