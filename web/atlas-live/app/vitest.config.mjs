import { defineConfig } from "vitest/config";

export default defineConfig({
  // The rules_js node_modules tree is read-only; keep Vite's cache in the test sandbox.
  cacheDir: `${process.env.TEST_TMPDIR ?? process.env.TMPDIR ?? "/tmp"}/vitest-cache`,
  test: {
    environment: "node",
    include: ["test/**/*.test.ts", "test/**/*.test.tsx"],
  },
});
