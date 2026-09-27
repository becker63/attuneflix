/**
 * Node CLI driven by the Bazel `synthetic_world` target. Writes the synthetic
 * stress fixture in the projection input format: one directory named by the
 * snapshot digest holding `metadata.parquet`, `entities.parquet`,
 * `relations.parquet`, and `locations.parquet`.
 *
 * Usage: synthetic_cli --out <dir>
 */
import { mkdir, writeFile } from "node:fs/promises";
import path from "node:path";
import process from "node:process";

import { SYNTHETIC_DIGEST, syntheticParquetFiles } from "./synthetic.ts";

function parseOut(argv: readonly string[]): string {
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === "--out") {
      const value = argv[i + 1];
      if (value === undefined || value.startsWith("--")) throw new Error("missing value for --out");
      return value;
    }
  }
  throw new Error("usage: synthetic_cli --out <dir>");
}

async function main(argv: readonly string[]): Promise<number> {
  const out = parseOut(argv);
  const dir = path.join(out, SYNTHETIC_DIGEST);
  await mkdir(dir, { recursive: true });
  const files = syntheticParquetFiles();
  await writeFile(path.join(dir, "metadata.parquet"), files.metadata);
  await writeFile(path.join(dir, "entities.parquet"), files.entities);
  await writeFile(path.join(dir, "relations.parquet"), files.relations);
  await writeFile(path.join(dir, "locations.parquet"), files.locations);
  console.log(`synthetic stress fixture written: ${SYNTHETIC_DIGEST}`);
  return 0;
}

async function run(): Promise<void> {
  try {
    process.exitCode = await main(process.argv.slice(2));
  } catch (error) {
    console.error(error instanceof Error ? error.message : String(error));
    process.exitCode = 1;
  }
}

void run();
