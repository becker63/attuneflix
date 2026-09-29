/** The frozen SWE Explore repository medians, read from the Flix report table. */
import type { RepositorySignature } from "./manifest.ts";
import { integer, readTable, text } from "./tables.ts";

export const SIGNATURE_COLUMNS = [
  "repository", "snapshot_count", "file_count_p50", "symbol_count_p50",
  "file_extinction", "symbol_extinction", "file_reach_p90", "symbol_reach_p90",
  "file_recurrence", "symbol_recurrence", "import_asymmetry", "call_asymmetry",
  "physical_compression", "reuse_fraction", "feature_range_mean", "feature_range_max",
] as const;

function finite(row: Record<string, unknown>, name: string): number {
  const value = row[name];
  if (typeof value !== "number" || !Number.isFinite(value)) {
    throw new Error(`signature ${name} is not a finite number`);
  }
  return value;
}

export async function repositorySignatures(file: ArrayBuffer): Promise<ReadonlyMap<string, RepositorySignature>> {
  const rows = await readTable(file, "repository signatures", SIGNATURE_COLUMNS);
  const signatures = new Map<string, RepositorySignature>();
  for (const row of rows) {
    const repository = text(row, "repository signatures", "repository");
    if (signatures.has(repository)) throw new Error(`duplicate repository signature: ${repository}`);
    const snapshots = integer(row, "repository signatures", "snapshot_count");
    if (snapshots < 1) throw new Error(`repository signature has no snapshots: ${repository}`);
    const signature: RepositorySignature = {
      protocol: "atlas-signature-swe-explore-v1",
      snapshots,
      files: finite(row, "file_count_p50"),
      symbols: finite(row, "symbol_count_p50"),
      fileExtinction: finite(row, "file_extinction"),
      symbolExtinction: finite(row, "symbol_extinction"),
      fileReachP90: finite(row, "file_reach_p90"),
      symbolReachP90: finite(row, "symbol_reach_p90"),
      fileRecurrence: finite(row, "file_recurrence"),
      symbolRecurrence: finite(row, "symbol_recurrence"),
      physicalCompression: finite(row, "physical_compression"),
      reuseFraction: finite(row, "reuse_fraction"),
    };
    for (const fraction of [signature.fileExtinction, signature.symbolExtinction,
      signature.fileReachP90, signature.symbolReachP90, signature.reuseFraction]) {
      if (fraction < 0 || fraction > 1) throw new Error(`invalid signature fraction for ${repository}`);
    }
    if (signature.fileRecurrence < 1 || signature.symbolRecurrence < 1 || signature.physicalCompression < 1) {
      throw new Error(`invalid signature recurrence/compression for ${repository}`);
    }
    signatures.set(repository, signature);
  }
  return signatures;
}
