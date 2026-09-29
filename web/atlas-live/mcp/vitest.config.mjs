import { defineConfig } from "vitest/config";

export default defineConfig({
  cacheDir: `${process.env.TEST_TMPDIR ?? process.env.TMPDIR ?? "/tmp"}/atlas-mcp-vitest-cache`,
  test: { environment: "node", include: ["test/**/*.test.ts"] },
});
