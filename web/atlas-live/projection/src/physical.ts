/**
 * Read-only projection of the derived full-coverage Preact Atlas physical table.
 * Absence means unmeasured, never zero reuse.
 */
import type { ViewerGraph } from "./graph.ts";
import { integer, readTable, text } from "./tables.ts";

/** Exact column order of Atlas.Signature.Table.physical. */
export const PHYSICAL_COLUMNS = [
  "signature_protocol", "atlas_protocol", "repository", "base_revision",
  "source_tree_identity", "fact_identity", "snapshot_id", "seed_domain",
  "seed_identity", "seed_ordinal", "logical_routes", "unique_semantic_states",
  "physical_transition_requests", "physical_transition_evaluations",
  "physical_transition_reuses", "logical_per_unique_state",
  "logical_per_physical_evaluation", "memo_cells", "compiled_dag_nodes",
] as const;

export interface PhysicalSeed {
  readonly pointIndex: number;
  readonly requests: number;
  readonly evaluations: number;
  readonly reuses: number;
  readonly reuseFraction: number;
}

export interface WorldPhysical {
  readonly seeds: readonly PhysicalSeed[];
  readonly byPointIndex: ReadonlyMap<number, PhysicalSeed>;
  readonly minFraction: number;
  readonly maxFraction: number;
}

function seedIdentity(graph: ViewerGraph, domain: string, ordinal: number): string {
  const point = domain === "file" ? ordinal : graph.fileCount + ordinal;
  const path = graph.pointPaths[point] ?? "";
  if (domain === "file") return path;
  return `${path}\u0000${graph.pointNames[point] ?? ""}\u0000${graph.pointStartBytes[point] ?? -1}\u0000${graph.pointEndBytes[point] ?? -1}`;
}

/** Joins measured per-seed physical work to exact viewer entity indices. */
export async function projectPhysical(file: ArrayBuffer, graph: ViewerGraph): Promise<WorldPhysical | null> {
  const rows = await readTable(file, "physical", PHYSICAL_COLUMNS);
  const seeds: PhysicalSeed[] = [];
  const byPointIndex = new Map<number, PhysicalSeed>();
  let fileSeeds = 0;
  let symbolSeeds = 0;
  for (const row of rows) {
    if (text(row, "physical", "snapshot_id") !== graph.provenance.snapshotId) continue;
    for (const [column, expected] of [
      ["signature_protocol", "atlas-live-physical-all-seeds-v1"],
      ["atlas_protocol", "atlas-composition-depth7-v1"],
      ["repository", graph.provenance.repository],
      ["base_revision", graph.provenance.baseRevision],
      ["source_tree_identity", graph.provenance.sourceTreeIdentity],
      ["fact_identity", graph.provenance.factIdentity],
    ] as const) {
      if (text(row, "physical", column) !== expected) {
        throw new Error(`physical measurement ${column} does not match the admitted world`);
      }
    }
    const domain = text(row, "physical", "seed_domain");
    if (domain !== "file" && domain !== "symbol") throw new Error(`unknown physical seed domain: ${domain}`);
    const ordinal = integer(row, "physical", "seed_ordinal");
    const limit = domain === "file" ? graph.fileCount : graph.symbolCount;
    if (ordinal < 0 || ordinal >= limit) throw new Error(`physical seed ordinal out of bounds: ${ordinal}`);
    if (text(row, "physical", "seed_identity") !== seedIdentity(graph, domain, ordinal)) {
      throw new Error(`physical seed ${domain}:${ordinal} does not resolve to the admitted entity`);
    }
    const requests = integer(row, "physical", "physical_transition_requests");
    const evaluations = integer(row, "physical", "physical_transition_evaluations");
    const reuses = integer(row, "physical", "physical_transition_reuses");
    if (requests <= 0 || evaluations < 0 || reuses < 0 || requests !== evaluations + reuses) {
      throw new Error(`physical seed ${domain}:${ordinal} has inconsistent work counts`);
    }
    const pointIndex = domain === "file" ? ordinal : graph.fileCount + ordinal;
    if (byPointIndex.has(pointIndex)) throw new Error(`duplicate physical seed ${domain}:${ordinal}`);
    const seed = { pointIndex, requests, evaluations, reuses, reuseFraction: reuses / requests };
    seeds.push(seed);
    byPointIndex.set(pointIndex, seed);
    if (domain === "file") fileSeeds++;
    else symbolSeeds++;
  }
  if (seeds.length === 0) return null;
  if (fileSeeds !== graph.fileCount || symbolSeeds !== graph.symbolCount) {
    throw new Error(`physical coverage incomplete: ${fileSeeds}/${graph.fileCount} files and ${symbolSeeds}/${graph.symbolCount} symbols`);
  }
  const fractions = seeds.map((seed) => seed.reuseFraction);
  return {
    seeds,
    byPointIndex,
    minFraction: Math.min(...fractions),
    maxFraction: Math.max(...fractions),
  };
}
