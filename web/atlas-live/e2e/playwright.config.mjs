import { defineConfig } from "@playwright/test";

const outputs =
  process.env.TEST_UNDECLARED_OUTPUTS_DIR ?? `${process.env.TMPDIR ?? "/tmp"}/playwright-outputs`;

export default defineConfig({
  testDir: "test",
  timeout: 180_000,
  workers: 1,
  retries: 0,
  reporter: [["list"]],
  outputDir: `${outputs}/test-results`,
  webServer: {
    // Same server as `:preview`; ../static is the Bazel-built bundle + data tree.
    command: `"${process.execPath}" ../serve.mjs --root ../static --port 4173`,
    url: "http://127.0.0.1:4173/",
    reuseExistingServer: false,
    timeout: 30_000,
    stdout: "pipe",
  },
  use: {
    baseURL: "http://127.0.0.1:4173",
    viewport: { width: 1024, height: 700 },
    launchOptions: {
      args: ["--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--ignore-gpu-blocklist"],
    },
  },
  projects: [{ name: "chromium", use: { browserName: "chromium" } }],
});
