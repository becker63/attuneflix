/**
 * A tiny static file server for the Bazel-built bundle: the app (`dist/`) plus
 * the content-addressed world data and `manifest.json`. Used by the local
 * `:preview` on 127.0.0.1:4173 and by the Playwright e2e run, so the bundle is
 * served the same way in both.
 *
 * The default root is the `static/` tree next to this script (the runfiles
 * layout); pass `--root <dir>` to override it relative to the current directory.
 *
 * By default the server copies the root into a fresh temp directory and serves
 * THAT snapshot. Bazel deletes and re-creates the `copy_to_directory` output
 * under the runfiles tree whenever a `bazel build` refreshes it, which empties
 * the running server's `static/` and kills it with ENOENT mid-session; serving a
 * copy makes a running preview immune to that. Pass `--no-snapshot` to serve the
 * given root in place (used where nothing refreshes it).
 *
 * Usage: node serve.mjs [--root <dir>] [--port <n>] [--no-snapshot]
 */
import fs from "node:fs";
import http from "node:http";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const scriptDir = path.dirname(fileURLToPath(import.meta.url));

function parseArgs(argv) {
  const options = { root: path.join(scriptDir, "static"), port: 4173, snapshot: true };
  for (let i = 0; i < argv.length; i++) {
    const flag = argv[i];
    const value = argv[i + 1];
    if (flag === "--root" && value !== undefined) {
      options.root = path.resolve(value);
      i += 1;
    } else if (flag === "--port" && value !== undefined) {
      options.port = Number(value);
      i += 1;
    } else if (flag === "--no-snapshot") {
      options.snapshot = false;
    }
  }
  return options;
}

/** Copy `root` (following the runfiles symlink) into a fresh temp directory. */
function snapshotRoot(root) {
  const copy = fs.mkdtempSync(path.join(os.tmpdir(), "atlas-live-preview-"));
  fs.cpSync(fs.realpathSync(root), copy, { recursive: true, dereference: true });
  return copy;
}

const TYPES = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".mjs": "text/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".wasm": "application/wasm",
  ".json": "application/json",
  ".parquet": "application/octet-stream",
  ".arrow": "application/vnd.apache.arrow.file",
  ".svg": "image/svg+xml",
  ".png": "image/png",
  ".ico": "image/x-icon",
  ".woff2": "font/woff2",
};

const { root, port, snapshot } = parseArgs(process.argv.slice(2));
const snapshotDir = snapshot ? snapshotRoot(root) : null;
const absoluteRoot = snapshotDir ?? path.resolve(root);
const cleanup = () => {
  if (snapshotDir !== null) {
    try {
      fs.rmSync(snapshotDir, { recursive: true, force: true });
    } catch {
      // The temp copy is best-effort cleanup; a leftover directory is harmless.
    }
  }
};
process.once("exit", cleanup);
process.once("SIGINT", () => process.exit(0));
process.once("SIGTERM", () => process.exit(0));
http
  .createServer((request, response) => {
    const url = new URL(request.url ?? "/", "http://127.0.0.1");
    let file = path.join(absoluteRoot, decodeURIComponent(url.pathname));
    if (!file.startsWith(absoluteRoot)) {
      response.writeHead(403).end();
      return;
    }
    if (fs.existsSync(file) && fs.statSync(file).isDirectory()) file = path.join(file, "index.html");
    if (!fs.existsSync(file)) file = path.join(absoluteRoot, "index.html");
    response.writeHead(200, {
      "content-type": TYPES[path.extname(file)] ?? "application/octet-stream",
      "cache-control": "no-store",
    });
    fs.createReadStream(file).pipe(response);
  })
  .listen(port, "127.0.0.1", () => {
    const source = snapshotDir === null ? "" : ` (snapshot of ${path.resolve(root)})`;
    console.log(`serving ${absoluteRoot}${source} on http://127.0.0.1:${port}/`);
  });
