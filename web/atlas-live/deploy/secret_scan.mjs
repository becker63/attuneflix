/**
 * Entry point of `//web/atlas-live:secret_scan_test`: a count-only credential
 * scan of the shipped Build Output API tree (`:vercel_output`) and of the
 * checked-in sources the bundle is built from, so a planted credential fails the
 * scan even where the bundler would drop the file.
 *
 * It looks for GitHub, Vercel, BuildBuddy, Factory and OpenRouter credential
 * shapes, for those environment-variable names bound to a value, and (when the
 * variable is present in this process) for the literal value of
 * `GH_TOKEN`, `VERCEL_TOKEN`, `BUILDBUDDY_API_KEY`, `FACTORY_API_KEY` and
 * `OPENROUTER_API_KEY`. It reports file names, pattern names and counts only:
 * never a matched value.
 */
import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import { fileURLToPath } from "node:url";

import { listFiles } from "./files.mjs";

const SCRIPT_DIR = path.dirname(fileURLToPath(import.meta.url));
const PACKAGE_DIR = path.resolve(SCRIPT_DIR, "..");

/** Scan roots, relative to the package directory: the output, then its sources. */
const ROOTS = [
  "vercel_output",
  "app/index.html",
  "app/vite.config.mjs",
  "app/src",
  "projection/src",
  "protocol/src",
  "mcp/src",
];

/** Token shapes. Each is matched with the global flag so a count is available. */
const PATTERNS = [
  { name: "github-token", regex: /\bgh[pousr]_[A-Za-z0-9]{20,}\b/g },
  { name: "github-pat", regex: /\bgithub_pat_[A-Za-z0-9_]{20,}\b/g },
  { name: "openrouter-key", regex: /\bsk-or-[A-Za-z0-9._-]{16,}\b/g },
  {
    name: "buildbuddy-api-key-header",
    regex: /x-buildbuddy-api-key\s*[:=]\s*["']?[A-Za-z0-9._-]{8,}/gi,
  },
  { name: "github-token-binding", regex: /GH_TOKEN\s*[:=]\s*["']?[A-Za-z0-9._-]{8,}/g },
  { name: "vercel-token-binding", regex: /VERCEL_TOKEN\s*[:=]\s*["']?[A-Za-z0-9._-]{8,}/g },
  { name: "buildbuddy-key-binding", regex: /BUILDBUDDY_API_KEY\s*[:=]\s*["']?[A-Za-z0-9._-]{8,}/g },
  { name: "factory-key-binding", regex: /FACTORY_API_KEY\s*[:=]\s*["']?[A-Za-z0-9._-]{8,}/g },
  { name: "openrouter-key-binding", regex: /OPENROUTER_API_KEY\s*[:=]\s*["']?[A-Za-z0-9._-]{8,}/g },
];

/** Credential values to look for literally when they are present in this process. */
const CREDENTIAL_VARIABLES = [
  "GH_TOKEN",
  "VERCEL_TOKEN",
  "BUILDBUDDY_API_KEY",
  "FACTORY_API_KEY",
  "OPENROUTER_API_KEY",
];

/** Values shorter than this are too likely to occur by chance to be reported. */
const MIN_VALUE_LENGTH = 12;

/** Every file of one scan root; a missing root is an error, never silent. */
function expandRoot(root) {
  const full = path.join(PACKAGE_DIR, root);
  if (!fs.existsSync(full)) throw new Error(`secret_scan: scan root ${root} is missing`);
  return fs.statSync(full).isDirectory() ? listFiles(full) : [full];
}

/** A readable `root[/relative]` label, used in findings instead of a full path. */
function labelFor(root, file) {
  const full = path.join(PACKAGE_DIR, root);
  if (!fs.statSync(full).isDirectory()) return root;
  return `${root}/${path.relative(full, file)}`;
}

function scan() {
  const roots = ROOTS.map((root) => ({ root, files: expandRoot(root) }));
  const findings = [];
  let variablesChecked = 0;

  for (const variable of CREDENTIAL_VARIABLES) {
    const value = process.env[variable];
    if (value !== undefined && value.length >= MIN_VALUE_LENGTH) variablesChecked += 1;
  }

  for (const { root, files } of roots) {
    for (const file of files) {
      const label = labelFor(root, file);
      const buffer = fs.readFileSync(file);
      const text = buffer.toString("latin1");
      for (const pattern of PATTERNS) {
        const matches = [...text.matchAll(pattern.regex)].length;
        if (matches > 0) findings.push(`${pattern.name} (${matches}) in ${label}`);
      }
      for (const variable of CREDENTIAL_VARIABLES) {
        const value = process.env[variable];
        if (value !== undefined && value.length >= MIN_VALUE_LENGTH && buffer.includes(value)) {
          findings.push(`${variable} value in ${label}`);
        }
      }
    }
  }
  return { roots, findings, variablesChecked };
}

function run() {
  try {
    const result = scan();
    const counts = result.roots.map(({ root, files }) => `${root} ${files.length}`).join(", ");
    console.log(`secret_scan: files scanned [${counts}] against ${PATTERNS.length} patterns`);
    console.log(`secret_scan: ${result.variablesChecked} present credential value(s) checked literally`);
    if (result.findings.length > 0) {
      for (const finding of result.findings) console.error(`secret_scan: ${finding}`);
      throw new Error(`secret_scan: ${result.findings.length} credential finding(s)`);
    }
    console.log("secret_scan: 0 matches");
  } catch (error) {
    console.error(error instanceof Error ? error.message : String(error));
    process.exitCode = 1;
  }
}

run();
