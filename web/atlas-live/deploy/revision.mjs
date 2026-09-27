/**
 * Build-revision stamping for the prebuilt Vercel output.
 *
 * The bundle is built with the literal `__ATLAS_LIVE_BUILD_REVISION__` as its
 * build revision (see `app/vite.config.mjs`), so no Bazel action ever depends on
 * a commit id: changing the revision invalidates nothing. `:deploy` resolves the
 * deployed revision here and replaces the placeholder in the temp copy it
 * uploads, which is why the deployed bundle reports the deployed commit while a
 * local preview keeps the placeholder.
 */
import { spawnSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";

import { listFiles } from "./files.mjs";

/** The placeholder baked into the bundle; keep in sync with `app/vite.config.mjs`. */
export const BUILD_REVISION_PLACEHOLDER = "__ATLAS_LIVE_BUILD_REVISION__";

/** Extensions whose content is text and can carry the placeholder. */
const TEXT_EXTENSIONS = new Set([
  ".cjs",
  ".css",
  ".html",
  ".js",
  ".json",
  ".map",
  ".mjs",
  ".svg",
  ".txt",
  ".xml",
]);

/**
 * Replaces every occurrence of the placeholder with `revision` in the text files
 * under `root`. Returns how many files were rewritten and how many placeholders
 * were replaced.
 */
export function stampBuildRevision(root, revision) {
  if (revision.length === 0) throw new Error("refusing to stamp an empty build revision");
  let files = 0;
  let replacements = 0;
  for (const file of listFiles(root)) {
    if (!TEXT_EXTENSIONS.has(path.extname(file).toLowerCase())) continue;
    const before = fs.readFileSync(file, "utf8");
    const parts = before.split(BUILD_REVISION_PLACEHOLDER);
    const count = parts.length - 1;
    if (count === 0) continue;
    fs.writeFileSync(file, parts.join(revision));
    files += 1;
    replacements += count;
  }
  return { files, replacements };
}

/** Runs `command ... log -r @-` and returns the commit id, or null on any failure. */
function jjCommitId(workspace, command) {
  const result = spawnSync(
    command[0],
    [...command.slice(1), "log", "-r", "@-", "--no-graph", "-T", "commit_id"],
    { cwd: workspace, encoding: "utf8", maxBuffer: 4 * 1024 * 1024 },
  );
  if (result.status !== 0) return null;
  const value = (result.stdout ?? "").trim().split("\n")[0]?.trim() ?? "";
  return /^[0-9a-f]{40,64}$/.test(value) ? value : null;
}

/** Absolute paths that may hold `nix`, in preference order. */
function nixCandidates() {
  return ["/nix/var/nix/profiles/default/bin/nix", `${process.env.HOME ?? ""}/.nix-profile/bin/nix`, "nix"];
}

/**
 * Resolves the revision to stamp, in this order: the explicit argument, the
 * `ATLAS_LIVE_BUILD_REVISION` environment variable, a `jj` on PATH, and finally
 * the pinned Nix dev shell's `jj`. Returns null when none is available, and the
 * caller refuses to deploy rather than invent a revision.
 */
export function resolveBuildRevision({ explicit, workspace }) {
  const given = explicit ?? process.env.ATLAS_LIVE_BUILD_REVISION ?? "";
  if (given.trim().length > 0) return given.trim();
  if (workspace === undefined || !fs.existsSync(path.join(workspace, ".jj"))) return null;
  const direct = jjCommitId(workspace, ["jj"]);
  if (direct !== null) return direct;
  for (const nix of nixCandidates()) {
    const revision = jjCommitId(workspace, [nix, "develop", "--command", "jj"]);
    if (revision !== null) return revision;
  }
  return null;
}
