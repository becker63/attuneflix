import { describe, expect, it } from "vitest";

import { documentTitle, isSettled } from "../src/title.ts";

describe("document title", () => {
  it("names the snapshot when one is loaded", () => {
    expect(documentTitle(undefined)).toBe("Atlas Live");
    expect(documentTitle("axios")).toBe("axios · Atlas Live");
  });
});

describe("status badge", () => {
  it("settles only on terminal protocol statuses", () => {
    expect(isSettled("completed")).toBe(true);
    expect(isSettled("reconnecting")).toBe(false);
  });
});
