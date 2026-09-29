import { describe, expect, it } from "vitest";

import type { WorldPhysical } from "../../projection/src/physical.ts";
import { regionReuse, shadeOklab } from "../src/physical.ts";
import type { StructuralLayout } from "../src/structure.ts";

function relativeLuminance(hex: string): number {
  const channels = [1, 3, 5].map((offset) => {
    const encoded = Number.parseInt(hex.slice(offset, offset + 2), 16) / 255;
    return encoded <= 0.04045 ? encoded / 12.92 : ((encoded + 0.055) / 1.055) ** 2.4;
  });
  return 0.2126 * (channels[0] ?? 0) + 0.7152 * (channels[1] ?? 0) + 0.0722 * (channels[2] ?? 0);
}

describe("physical reuse shading", () => {
  it("makes higher reuse visibly lighter for each existing family hue", () => {
    for (const familyColor of ["#a14c64", "#4e79a7", "#59a14f"]) {
      const low = shadeOklab(familyColor, 0);
      const middle = shadeOklab(familyColor, 0.5);
      const high = shadeOklab(familyColor, 1);
      expect(low).toMatch(/^#[0-9a-f]{6}$/);
      expect(relativeLuminance(low)).toBeLessThan(relativeLuminance(middle));
      expect(relativeLuminance(middle)).toBeLessThan(relativeLuminance(high));
      expect(relativeLuminance(high) / relativeLuminance(low)).toBeGreaterThan(5);
      expect(shadeOklab(familyColor, -1)).toBe(low);
      expect(shadeOklab(familyColor, 2)).toBe(high);
    }
  });

  it("aggregates exact transition counts across a directory and its descendants", () => {
    const layout: StructuralLayout = {
      identity: "fixture",
      structure: {
        root: 0,
        directoryParent: Int32Array.from([-1, 0]),
        fileDirectory: Int32Array.from([1, 0]),
        symbolFile: Int32Array.from([0]),
      },
      xy: new Float32Array(),
      directoryRegions: [],
      fileCells: [],
    };
    const seeds: WorldPhysical["seeds"] = [
      { pointIndex: 0, requests: 1, evaluations: 1, reuses: 0, reuseFraction: 0 },
      { pointIndex: 1, requests: 9, evaluations: 0, reuses: 9, reuseFraction: 1 },
      { pointIndex: 2, requests: 10, evaluations: 2, reuses: 8, reuseFraction: 0.8 },
    ];
    const physical: WorldPhysical = {
      seeds,
      byPointIndex: new Map(seeds.map((seed) => [seed.pointIndex, seed])),
      minFraction: 0,
      maxFraction: 1,
    };

    const regions = regionReuse(layout, physical);
    expect(regions.get(1)).toEqual({ measuredSeeds: 2, requests: 11, reuses: 8, reuseFraction: 8 / 11 });
    expect(regions.get(0)).toEqual({ measuredSeeds: 3, requests: 20, reuses: 17, reuseFraction: 17 / 20 });
    expect(regionReuse(layout, physical)).toBe(regions);
  });
});
