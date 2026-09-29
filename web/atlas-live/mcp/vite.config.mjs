import { defineConfig } from "vite";

export default defineConfig({
  cacheDir: `${process.env.TEST_TMPDIR ?? process.env.TMPDIR ?? "/tmp"}/atlas-mcp-vite-cache`,
  build: {
    target: "es2022",
    outDir: "dist",
    emptyOutDir: true,
    lib: { entry: "src/edge.ts", formats: ["es"], fileName: () => "index.js" },
    minify: true,
  },
});
