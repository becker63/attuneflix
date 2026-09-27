import babel from "@rolldown/plugin-babel";
import stylex from "@stylexjs/unplugin";
import react, { reactCompilerPreset } from "@vitejs/plugin-react";
import { defineConfig } from "vite";

// The viewer build revision is stamped at build time. It defaults to "dev" so a
// plain local build never invents a commit id.
const buildRevision = process.env.ATLAS_LIVE_BUILD_REVISION ?? "dev";

export default defineConfig({
  // rules_js node_modules is a read-only output tree; keep Vite's cache out of it.
  cacheDir: `${process.env.TEST_TMPDIR ?? process.env.TMPDIR ?? "/tmp"}/vite-cache`,
  define: {
    __ATLAS_BUILD_REVISION__: JSON.stringify(buildRevision),
  },
  plugins: [
    stylex.vite({ useCSSLayers: true, devPersistToDisk: false }),
    react(),
    babel({ presets: [reactCompilerPreset()] }),
  ],
  resolve: {
    preserveSymlinks: false,
    alias: [
      // gl-bench's "browser" field points at an IIFE build that Rolldown cannot import.
      { find: /^gl-bench$/, replacement: "gl-bench/dist/gl-bench.module.js" },
    ],
  },
  build: {
    target: "es2022",
    outDir: "dist",
    emptyOutDir: true,
    assetsInlineLimit: 0,
    chunkSizeWarningLimit: 4096,
  },
});
