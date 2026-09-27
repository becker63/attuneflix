import { describe, expect, it } from "vitest";

import { DOMAIN_ORDER, domainRank, isDomain } from "../src/domain.ts";

describe("domain order", () => {
  it("ranks domains in point order", () => {
    expect(DOMAIN_ORDER.map((domain) => domainRank(domain))).toEqual([0, 1, 2]);
  });

  it("recognises only known domains", () => {
    expect(isDomain("symbol")).toBe(true);
    expect(isDomain("directory")).toBe(false);
  });
});
