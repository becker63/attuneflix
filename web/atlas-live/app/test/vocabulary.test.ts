import { describe, expect, it } from "vitest";

import { RELATION_ORDER } from "../../projection/src/relation.ts";
import {
  DOMAIN_ORDER_FOR_LEGEND,
  domainStyle,
  legendEntries,
  pointColorMap,
  relationColor,
  relationStyle,
} from "../src/vocabulary.ts";

describe("visual vocabulary", () => {
  it("keeps the render colour map and the legend on the same entries", () => {
    const map = pointColorMap();
    for (const domain of DOMAIN_ORDER_FOR_LEGEND) {
      expect(map[domain]).toBe(domainStyle(domain).color);
    }
    for (const relation of RELATION_ORDER) {
      expect(relationColor(relation)).toBe(relationStyle(relation).color);
    }
  });

  it("generates one legend entry per overlay category and enabled relation", () => {
    const entries = legendEntries("structure", RELATION_ORDER);
    const keys = entries.map((entry) => `${entry.kind}:${entry.key}`);
    expect(keys).toEqual([
      "category:file",
      "category:symbol",
      "category:location",
      "relation:defines",
      "relation:imports",
      "relation:calls",
      "relation:parent",
    ]);
    const expected: Record<string, string> = { ...pointColorMap() };
    for (const relation of RELATION_ORDER) expected[relation] = relationStyle(relation).color;
    for (const entry of entries) {
      expect(entry.color).toBe(expected[entry.key]);
      expect(entry.glyph.length).toBeGreaterThan(0);
    }
  });

  it("omits disabled relations from the legend", () => {
    const keys = legendEntries("structure", ["defines"]).map((entry) => entry.key);
    expect(keys).toContain("defines");
    expect(keys).not.toContain("calls");
  });

  it("falls back to a neutral colour for an unknown relation value", () => {
    expect(relationColor("not-a-relation")).toBe("#6b7280");
  });
});
