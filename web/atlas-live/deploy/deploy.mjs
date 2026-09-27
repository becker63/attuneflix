/**
 * Entry point of `//web/atlas-live:deploy`: publishes the prebuilt Build Output
 * API v3 tree (`:vercel_output`) to Vercel project `atlas-live` in team
 * `becker63s-projects`, and prints the production URL.
 *
 * Vercel never builds from source. The Bazel tree is copied into a temp
 * directory, the build-revision placeholder is stamped with the deployed
 * revision, the project is linked through a temp `.vercel/project.json`, and the
 * Bazel-provided Vercel CLI 60.1.3 runs `deploy --prebuilt --prod`. The temp
 * directory is removed before this returns.
 *
 * `VERCEL_TOKEN` comes from the environment and is only passed through the child
 * environment: never on a command line, never printed (all printed text is
 * redacted), and `HOME` is redirected into the temp directory so the CLI cannot
 * write anywhere else.
 *
 * `--dry-run` copies and stamps the output and creates/looks up the project, but
 * publishes no deployment.
 *
 * Usage: deploy [--build-revision <commit>] [--output <dir>] [--dry-run] [--verbose]
 */
import { spawnSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import process from "node:process";
import { fileURLToPath } from "node:url";

import { makeWritable, treeSize } from "./files.mjs";
import { resolveBuildRevision, stampBuildRevision } from "./revision.mjs";
import { ensureProject, productionTarget } from "./vercel_api.mjs";

const TEAM_SLUG = "becker63s-projects";
const TEAM_ID = "team_rzeYKohSpmJuZgKrKh1A4MEY";
const PROJECT = "atlas-live";

/** Credentials that must never appear in anything this script prints. */
const SECRET_VARIABLES = [
  "VERCEL_TOKEN",
  "GH_TOKEN",
  "BUILDBUDDY_API_KEY",
  "FACTORY_API_KEY",
  "OPENROUTER_API_KEY",
];

const SCRIPT_DIR = path.dirname(fileURLToPath(import.meta.url));
const DEFAULT_OUTPUT = path.resolve(SCRIPT_DIR, "..", "vercel_output");

function parseArgs(argv) {
  const options = { buildRevision: undefined, output: undefined, dryRun: false, verbose: false };
  for (let i = 0; i < argv.length; i += 1) {
    const flag = argv[i];
    if (flag === "--verbose") {
      options.verbose = true;
      continue;
    }
    if (flag === "--dry-run") {
      options.dryRun = true;
      continue;
    }
    const value = argv[i + 1];
    if (flag === "--build-revision" || flag === "--output") {
      if (value === undefined) throw new Error(`${flag} needs a value`);
      if (flag === "--build-revision") options.buildRevision = value;
      else options.output = value;
      i += 1;
      continue;
    }
    throw new Error(`unknown argument ${flag ?? ""}`);
  }
  return options;
}

/** Replaces every credential value with a fixed marker. */
function redact(text) {
  let output = text;
  for (const name of SECRET_VARIABLES) {
    const value = process.env[name];
    if (value !== undefined && value.length >= 6) output = output.split(value).join("[redacted]");
  }
  return output;
}

/** URLs the CLI echoed, so the printed output stays verifiable without its noise. */
function urlsIn(text) {
  return [...new Set(text.match(/https:\/\/[A-Za-z0-9._-]+\.vercel\.app[^\s]*/g) ?? [])];
}

function runVercel(cli, temp, projectId, token) {
  const args = [
    "--cwd",
    temp,
    "--scope",
    TEAM_SLUG,
    "deploy",
    "--prebuilt",
    "--prod",
    "--yes",
    "--non-interactive",
  ];
  // HOME sits *inside* the temp directory (never equal to it: the CLI refuses to
  // deploy when `--cwd` is the home directory) so the CLI cannot write outside it.
  const env = {
    ...process.env,
    CI: "1",
    HOME: path.join(temp, "home"),
    NO_COLOR: "1",
    VERCEL_ORG_ID: TEAM_ID,
    VERCEL_PROJECT_ID: projectId,
    VERCEL_TELEMETRY_DISABLED: "1",
    VERCEL_TOKEN: token,
    XDG_CACHE_HOME: path.join(temp, ".cache"),
    XDG_CONFIG_HOME: path.join(temp, ".config"),
    XDG_DATA_HOME: path.join(temp, ".local", "share"),
  };
  const result = spawnSync(cli, args, { encoding: "utf8", env, maxBuffer: 64 * 1024 * 1024 });
  return {
    status: result.status,
    stdout: result.stdout ?? "",
    stderr: result.stderr ?? "",
    error: result.error,
  };
}

/** The last lines of the CLI output, for a failure that happens after the deploy. */
function cliTail(run) {
  const text = redact(`${run.stdout}\n${run.stderr}`).trim();
  return text.split("\n").slice(-15).join("\n");
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  const token = process.env.VERCEL_TOKEN;
  if (token === undefined || token.length === 0) {
    throw new Error("VERCEL_TOKEN is not set; the deploy cannot authenticate");
  }
  const output = path.resolve(options.output ?? DEFAULT_OUTPUT);
  if (!fs.existsSync(path.join(output, "config.json"))) {
    throw new Error(`no Build Output API tree at ${output}; build //web/atlas-live:vercel_output`);
  }
  const cli = path.resolve(SCRIPT_DIR, "..", "vercel_cli_", "vercel_cli");
  if (!fs.existsSync(cli)) throw new Error(`the Bazel Vercel CLI launcher is missing at ${cli}`);

  const workspace = process.env.BUILD_WORKSPACE_DIRECTORY;
  const revision = resolveBuildRevision({ explicit: options.buildRevision, workspace });
  if (revision === null) {
    throw new Error(
      "no build revision: pass --build-revision <commit>, set ATLAS_LIVE_BUILD_REVISION, " +
        "or run from the jj workspace where `nix develop --command jj` is available",
    );
  }

  const temp = fs.mkdtempSync(path.join(os.tmpdir(), "atlas-live-deploy-"));
  try {
    // Runfiles entries are symlinks into bazel-out and read-only; dereference so
    // the upload gets real files, then make the copy writable so it can be
    // stamped and removed.
    const vercelOutput = path.join(temp, ".vercel", "output");
    fs.mkdirSync(path.dirname(vercelOutput), { recursive: true });
    fs.cpSync(output, vercelOutput, { recursive: true, dereference: true });
    makeWritable(vercelOutput);
    const stamped = stampBuildRevision(vercelOutput, revision);

    const project = await ensureProject({ token, teamId: TEAM_ID, name: PROJECT });
    fs.writeFileSync(
      path.join(temp, ".vercel", "project.json"),
      `${JSON.stringify({ orgId: TEAM_ID, projectId: project.id }, null, 2)}\n`,
    );
    if (project.created && options.verbose) console.log(`project: created ${PROJECT} in ${TEAM_SLUG}`);

    if (options.dryRun) {
      console.log(
        `dry run: ${treeSize(vercelOutput)} bytes copied, ${stamped.files} file(s) stamped ` +
          `with ${revision}, project ${project.id}; no deployment published`,
      );
      return;
    }

    const run = runVercel(cli, temp, project.id, token);
    const cliText = redact(`${run.stdout}\n${run.stderr}`);
    if (run.status !== 0) {
      const detail = run.error === undefined ? cliText.trim() : `${String(run.error)}\n${cliText.trim()}`;
      throw new Error(`vercel deploy exited ${run.status}:\n${detail}`);
    }

    let target;
    try {
      target = await productionTarget({ token, teamId: TEAM_ID, projectId: project.id });
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      throw new Error(`${message}; the CLI reported:\n${cliTail(run)}`);
    }
    const productionUrl = target.alias ?? target.deployment.url;
    console.log(`production URL: ${productionUrl}`);
    console.log(`deployment id: ${target.deployment.id}`);
    console.log(`build revision: ${revision} (${stamped.files} file(s), ${stamped.replacements} stamp(s))`);
    if (options.verbose) {
      for (const url of urlsIn(cliText)) console.log(`cli URL: ${url}`);
    }
  } finally {
    fs.rmSync(temp, { recursive: true, force: true });
  }
}

async function run() {
  try {
    await main();
  } catch (error) {
    console.error(redact(error instanceof Error ? error.message : String(error)));
    process.exitCode = 1;
  }
}

void run();
