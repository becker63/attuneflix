import { describe, expect, it } from "vitest";

import { isTerminalStatus } from "../src/status.ts";

describe("stream status", () => {
  it("treats only completed and failed as terminal", () => {
    expect(isTerminalStatus("completed")).toBe(true);
    expect(isTerminalStatus("failed")).toBe(true);
    expect(isTerminalStatus("gapped")).toBe(false);
    expect(isTerminalStatus("disconnected")).toBe(false);
  });
});
