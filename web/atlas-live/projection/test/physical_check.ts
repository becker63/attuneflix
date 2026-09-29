/** Exact parity and coverage law for the new all-seed Preact measurement. */
import { readFile } from "node:fs/promises";
import path from "node:path";

import { projectTables } from "../src/graph.ts";
import { PHYSICAL_COLUMNS, projectPhysical } from "../src/physical.ts";
import { decodeWorldFiles, integer, readTable, text } from "../src/tables.ts";

const DIGEST = "6e2bef41bf19f638be084df8cb82127e4832d4abbafa8ca20ebd5db9be3ac8a9";
const WORLD = path.join("layout_worlds", DIGEST);

async function bytes(file: string): Promise<ArrayBuffer> {
  const buffer = await readFile(file);
  return Uint8Array.from(buffer).buffer;
}

function fail(message: string): never { throw new Error(message); }

const graph = projectTables(await decodeWorldFiles({
  metadata: await bytes(path.join(WORLD, "metadata.parquet")),
  entities: await bytes(path.join(WORLD, "entities.parquet")),
  relations: await bytes(path.join(WORLD, "relations.parquet")),
}), { metadata: DIGEST, entities: DIGEST, relations: DIGEST });
const fullBytes = await bytes("physical/physical.parquet");
const projected = await projectPhysical(fullBytes, graph);
if (projected === null || projected.seeds.length !== graph.fileCount + graph.symbolCount) {
  fail("all-seed physical table does not cover every Preact file and symbol");
}

const full = await readTable(fullBytes, "physical", PHYSICAL_COLUMNS);
const frozen = await readTable(
  await bytes("physical_frozen/physical.parquet"),
  "physical", PHYSICAL_COLUMNS,
);
const rows = new Map(full.map((row) => [
  `${text(row, "physical", "seed_domain")}:${integer(row, "physical", "seed_ordinal")}`, row,
]));
const frozenPreact = frozen.filter((row) => text(row, "physical", "snapshot_id") === graph.provenance.snapshotId);
if (frozenPreact.length !== 16) fail(`expected 16 frozen Preact panel rows, got ${frozenPreact.length}`);
const exact = [
  "seed_identity", "logical_routes", "unique_semantic_states", "physical_transition_requests",
  "physical_transition_evaluations", "physical_transition_reuses", "memo_cells",
] as const;
for (const row of frozenPreact) {
  const key = `${text(row, "physical", "seed_domain")}:${integer(row, "physical", "seed_ordinal")}`;
  const measured = rows.get(key);
  if (measured === undefined) fail(`missing frozen seed ${key}`);
  for (const column of exact) {
    if (row[column] !== measured[column]) fail(`physical parity mismatch at ${key}.${column}`);
  }
}
console.log(`Physical parity: ${projected.seeds.length} Preact seeds; 16 frozen panel rows exact`);
