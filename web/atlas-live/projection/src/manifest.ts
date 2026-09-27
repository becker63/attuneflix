/**
 * The manifest emitted by the Bazel `:data` target: one entry per world, with the
 * provenance of the world, the projected counts, the content-addressed asset
 * paths, and the sha256 of every shipped Parquet file. Serialized
 * deterministically (worlds sorted by snapshot id).
 */
import { ProjectionError } from "./errors.ts";
import type { ViewerGraph } from "./graph.ts";

export const MANIFEST_VERSION = 1;

export const SNAPSHOT_ID_PREFIX = "repository-snapshot-v1:";

export interface WorldCounts {
  readonly files: number;
  readonly symbols: number;
  readonly directories: number;
  readonly points: number;
  readonly links: number;
  readonly defines: number;
  readonly imports: number;
  readonly calls: number;
  readonly parent: number;
}

export interface WorldAssets {
  readonly metadata: string;
  readonly entities: string;
  readonly relations: string;
  readonly locations?: string;
}

export interface WorldHashes {
  readonly metadata: string;
  readonly entities: string;
  readonly relations: string;
  readonly locations?: string;
}

export interface WorldManifestEntry {
  readonly snapshotId: string;
  readonly snapshotDigest: string;
  readonly repository: string;
  readonly baseRevision: string;
  readonly sourceTreeIdentity: string;
  readonly factIdentity: string;
  readonly counts: WorldCounts;
  readonly assets: WorldAssets;
  readonly sha256: WorldHashes;
  /** True only for the synthetic stress fixture; false for every real world. */
  readonly synthetic: boolean;
}

export interface WorldManifest {
  readonly version: typeof MANIFEST_VERSION;
  readonly worlds: readonly WorldManifestEntry[];
  /**
   * The synthetic stress fixture, kept out of `worlds` so it is never counted
   * among the 78 census worlds, or null when no fixture was generated.
   */
  readonly synthetic: WorldManifestEntry | null;
}

/** The content-addressed data path component of a snapshot id. */
export function snapshotDigest(snapshotId: string): string {
  if (!snapshotId.startsWith(SNAPSHOT_ID_PREFIX)) {
    throw new ProjectionError({
      kind: "invalid-schema",
      table: "metadata",
      message: `snapshot_id does not start with ${SNAPSHOT_ID_PREFIX}: ${snapshotId}`,
    });
  }
  return snapshotId.slice(SNAPSHOT_ID_PREFIX.length);
}

export function manifestEntry(graph: ViewerGraph, synthetic = false): WorldManifestEntry {
  const { provenance } = graph;
  const digest = snapshotDigest(provenance.snapshotId);
  const assets: { metadata: string; entities: string; relations: string; locations?: string } = {
    metadata: `data/${digest}/metadata.parquet`,
    entities: `data/${digest}/entities.parquet`,
    relations: `data/${digest}/relations.parquet`,
  };
  const sha256: { metadata: string; entities: string; relations: string; locations?: string } = {
    metadata: provenance.fileSha256.metadata,
    entities: provenance.fileSha256.entities,
    relations: provenance.fileSha256.relations,
  };
  if (provenance.fileSha256.locations !== undefined) {
    assets.locations = `data/${digest}/locations.parquet`;
    sha256.locations = provenance.fileSha256.locations;
  }
  return {
    snapshotId: provenance.snapshotId,
    snapshotDigest: digest,
    repository: provenance.repository,
    baseRevision: provenance.baseRevision,
    sourceTreeIdentity: provenance.sourceTreeIdentity,
    factIdentity: provenance.factIdentity,
    counts: {
      files: graph.fileCount,
      symbols: graph.symbolCount,
      directories: graph.directoryCount,
      points: graph.pointCount,
      links: graph.linkCount,
      defines: graph.relationCounts.defines,
      imports: graph.relationCounts.imports,
      calls: graph.relationCounts.calls,
      parent: graph.relationCounts.parent,
    },
    assets,
    sha256,
    synthetic,
  };
}

export function serializeManifest(
  entries: readonly WorldManifestEntry[],
  synthetic: WorldManifestEntry | null = null,
): string {
  const worlds = entries.toSorted((a, b) =>
    a.snapshotId < b.snapshotId ? -1 : a.snapshotId > b.snapshotId ? 1 : 0,
  );
  const manifest: WorldManifest = { version: MANIFEST_VERSION, worlds, synthetic };
  return JSON.stringify(manifest, null, 2) + "\n";
}
