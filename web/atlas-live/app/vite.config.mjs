import babel from "@rolldown/plugin-babel";
import stylex from "@stylexjs/unplugin";
import react, { reactCompilerPreset } from "@vitejs/plugin-react";
import { defineConfig } from "vite";

// The viewer build revision is baked into the bundle. The Bazel build never
// knows a commit id: it bakes the placeholder `__ATLAS_LIVE_BUILD_REVISION__`,
// and //web/atlas-live:deploy replaces that placeholder in the temp copy it
// uploads (web/atlas-live/deploy/revision.mjs). No Bazel action depends on the
// revision, so a new commit never invalidates a cached build. Setting
// ATLAS_LIVE_BUILD_REVISION bakes a revision directly (and skips stamping).
const buildRevision = process.env.ATLAS_LIVE_BUILD_REVISION ?? "__ATLAS_LIVE_BUILD_REVISION__";

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
