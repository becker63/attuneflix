import { describe, expect, it } from "vitest";

import { shadeOklab } from "../src/physical.ts";

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
      expect(shadeOklab(familyColor, -1)).toBe(low);
      expect(shadeOklab(familyColor, 2)).toBe(high);
    }
  });
});
