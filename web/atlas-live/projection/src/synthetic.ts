/**
 * The synthetic 10k-node / 50k-edge stress fixture, generated deterministically
 * by a Bazel target (`//web/atlas-live/projection:synthetic_world`).
 *
 * It is not a repository and claims no repository: every identity field marks it
 * as synthetic, and the manifest keeps it out of the 78-world list. It is emitted
 * in the SAME projection input format as a real world (metadata / entities /
 * relations / locations Parquet, see `writeParquet`), so the viewer projects it
 * through the identical code path and can never mistake it for evidence.
 *
 * Shape (`SYNTHETIC_STRESS`): 2,000 files + 7,000 symbols + 1,000 directories =
 * 10,000 points; 7,000 defines + 15,001 imports + 25,000 calls + 2,999 parent =
 * 50,000 links. All arithmetic is index-based and pure, so the bytes are stable
 * across runs.
 */
import type { EntityRow, LocationRow, MetadataRow, RelationRow, WorldTables } from "./tables.ts";
import { writeParquet, type ParquetColumn } from "./parquet.ts";
import { SNAPSHOT_ID_PREFIX } from "./manifest.ts";

/** sha256("atlas-live-synthetic-stress-v1"); a fixed content address. */
export const SYNTHETIC_DIGEST = "59ad7394fb5fe1fe4f387c50ad3dc7644c589c4bcba773ea17fe8f8c65c09b6b";
export const SYNTHETIC_SNAPSHOT_ID = `${SNAPSHOT_ID_PREFIX}${SYNTHETIC_DIGEST}`;
export const SYNTHETIC_REPOSITORY = "synthetic";
export const SYNTHETIC_BASE_REVISION = "synthetic-stress-v1";
export const SYNTHETIC_SOURCE_TREE_IDENTITY = "source-tree-synthetic-v1:0000000000000000";
export const SYNTHETIC_FACT_IDENTITY = "repository-facts-synthetic-v1:0000000000000000";

export interface SyntheticConfig {
  readonly files: number;
  readonly symbols: number;
  readonly directories: number;
  readonly imports: number;
  readonly calls: number;
}

/** 10,000 points and 50,000 links (defines = symbols, parent = files + directories - 1). */
export const SYNTHETIC_STRESS: SyntheticConfig = {
  files: 2000,
  symbols: 7000,
  directories: 1000,
  imports: 15001,
  calls: 25000,
};

export const SYNTHETIC_EXPECTED_POINTS = 10000;
export const SYNTHETIC_EXPECTED_LINKS = 50000;

function fileName(index: number): string {
  return `file_${index}.ts`;
}

function filePath(index: number, directoryCount: number): string {
  return `dir_${1 + (index % directoryCount)}/${fileName(index)}`;
}

function directoryPath(index: number): string {
  return `dir_${index}/`;
}

/** The synthetic world's typed rows, in the canonical world-table shape. */
export function syntheticWorld(config: SyntheticConfig = SYNTHETIC_STRESS): WorldTables {
  const { files, symbols, directories, imports, calls } = config;
  if (directories < 2) throw new Error("synthetic fixture needs at least one non-root directory");
  const nonRootDirectories = directories - 1;
  // Directory locations are the ids [files, files + directories); id `files` is
  // the root "". Files and non-root directories point at their parent directory.
  const rootLocation = files;
  const parentForFile = (index: number): number => rootLocation + 1 + (index % nonRootDirectories);
  const parentCount = files + nonRootDirectories;

  const metadata: MetadataRow = {
    repository: SYNTHETIC_REPOSITORY,
    baseRevision: SYNTHETIC_BASE_REVISION,
    sourceTreeIdentity: SYNTHETIC_SOURCE_TREE_IDENTITY,
    factIdentity: SYNTHETIC_FACT_IDENTITY,
    snapshotId: SYNTHETIC_SNAPSHOT_ID,
    fileCount: files,
    symbolCount: symbols,
    definesCount: symbols,
    importsCount: imports,
    callsCount: calls,
    parentCount,
    unresolvedImports: 0,
    unresolvedCalls: 0,
  };

  const entities: EntityRow[] = [];
  for (let index = 0; index < files; index++) {
    entities.push({
      snapshotId: SYNTHETIC_SNAPSHOT_ID,
      domain: "file",
      entityId: index,
      ordinal: index,
      path: filePath(index, nonRootDirectories),
      name: null,
      startByte: null,
      endByte: null,
    });
  }
  for (let index = 0; index < symbols; index++) {
    entities.push({
      snapshotId: SYNTHETIC_SNAPSHOT_ID,
      domain: "symbol",
      entityId: index,
      ordinal: index,
      path: filePath(index % files, nonRootDirectories),
      name: `sym_${index}`,
      startByte: index * 8,
      endByte: index * 8 + 6,
    });
  }

  const relations: RelationRow[] = [];
  for (let symbol = 0; symbol < symbols; symbol++) {
    relations.push({
      snapshotId: SYNTHETIC_SNAPSHOT_ID,
      relation: "defines",
      sourceDomain: "file",
      sourceId: symbol % files,
      targetDomain: "symbol",
      targetId: symbol,
    });
  }
  for (let index = 0; index < imports; index++) {
    const source = (index * 7 + 3) % files;
    let target = (index * 13 + 5) % files;
    if (target === source) target = (target + 1) % files;
    relations.push({
      snapshotId: SYNTHETIC_SNAPSHOT_ID,
      relation: "imports",
      sourceDomain: "file",
      sourceId: source,
      targetDomain: "file",
      targetId: target,
    });
  }
  for (let index = 0; index < calls; index++) {
    relations.push({
      snapshotId: SYNTHETIC_SNAPSHOT_ID,
      relation: "calls",
      sourceDomain: "symbol",
      sourceId: (index * 17 + 1) % symbols,
      targetDomain: "symbol",
      targetId: (index * 29 + 11) % symbols,
    });
  }
  for (let index = 0; index < files; index++) {
    relations.push({
      snapshotId: SYNTHETIC_SNAPSHOT_ID,
      relation: "parent",
      sourceDomain: "location",
      sourceId: index,
      targetDomain: "location",
      targetId: parentForFile(index),
    });
  }
  for (let index = 0; index < nonRootDirectories; index++) {
    relations.push({
      snapshotId: SYNTHETIC_SNAPSHOT_ID,
      relation: "parent",
      sourceDomain: "location",
      sourceId: rootLocation + 1 + index,
      targetDomain: "location",
      targetId: rootLocation,
    });
  }

  const locations: LocationRow[] = [];
  for (let index = 0; index < files; index++) {
    locations.push({
      snapshotId: SYNTHETIC_SNAPSHOT_ID,
      locationId: index,
      path: filePath(index, nonRootDirectories),
      kind: "file",
    });
  }
  locations.push({
    snapshotId: SYNTHETIC_SNAPSHOT_ID,
    locationId: rootLocation,
    path: "",
    kind: "directory",
  });
  for (let index = 0; index < nonRootDirectories; index++) {
    locations.push({
      snapshotId: SYNTHETIC_SNAPSHOT_ID,
      locationId: rootLocation + 1 + index,
      path: directoryPath(index + 1),
      kind: "directory",
    });
  }

  return { metadata, entities, relations, locations };
}

function columnsFor<T>(
  rows: readonly T[],
  select: (row: T) => ReadonlyArray<number | string | null>,
  spec: ReadonlyArray<{ name: string; kind: "int32" | "string"; nullable?: boolean }>,
): ParquetColumn[] {
  const columns: ParquetColumn[] = [];
  for (let column = 0; column < spec.length; column++) {
    const entry = spec[column];
    if (entry === undefined) throw new Error(`missing column spec ${column}`);
    const values = rows.map((row) => {
      const cells = select(row);
      const value = cells[column];
      return value === undefined ? null : value;
    });
    columns.push({
      name: entry.name,
      kind: entry.kind,
      nullable: entry.nullable,
      values,
    });
  }
  return columns;
}

/** The four Parquet files of the synthetic world, in the canonical schemas. */
export function syntheticParquetFiles(config: SyntheticConfig = SYNTHETIC_STRESS): {
  metadata: Uint8Array;
  entities: Uint8Array;
  relations: Uint8Array;
  locations: Uint8Array;
} {
  const tables = syntheticWorld(config);
  const metadata = writeParquet(
    columnsFor(
      [tables.metadata],
      (row) => [
        row.repository,
        row.baseRevision,
        row.sourceTreeIdentity,
        row.factIdentity,
        row.snapshotId,
        row.fileCount,
        row.symbolCount,
        row.definesCount,
        row.importsCount,
        row.callsCount,
        row.parentCount,
        row.unresolvedImports,
        row.unresolvedCalls,
      ],
      [
        { name: "repository", kind: "string" },
        { name: "base_revision", kind: "string" },
        { name: "source_tree_identity", kind: "string" },
        { name: "fact_identity", kind: "string" },
        { name: "snapshot_id", kind: "string" },
        { name: "file_count", kind: "int32" },
        { name: "symbol_count", kind: "int32" },
        { name: "defines_count", kind: "int32" },
        { name: "imports_count", kind: "int32" },
        { name: "calls_count", kind: "int32" },
        { name: "parent_count", kind: "int32" },
        { name: "unresolved_imports", kind: "int32" },
        { name: "unresolved_calls", kind: "int32" },
      ],
    ),
  );
  const entities = writeParquet(
    columnsFor(
      tables.entities,
      (row) => [
        row.snapshotId,
        row.domain,
        row.entityId,
        row.ordinal,
        row.path,
        row.name,
        row.startByte,
        row.endByte,
      ],
      [
        { name: "snapshot_id", kind: "string" },
        { name: "domain", kind: "string" },
        { name: "entity_id", kind: "int32" },
        { name: "ordinal", kind: "int32" },
        { name: "path", kind: "string" },
        { name: "name", kind: "string", nullable: true },
        { name: "start_byte", kind: "int32", nullable: true },
        { name: "end_byte", kind: "int32", nullable: true },
      ],
    ),
  );
  const relations = writeParquet(
    columnsFor(
      tables.relations,
      (row) => [row.snapshotId, row.relation, row.sourceDomain, row.sourceId, row.targetDomain, row.targetId],
      [
        { name: "snapshot_id", kind: "string" },
        { name: "relation", kind: "string" },
        { name: "source_domain", kind: "string" },
        { name: "source_id", kind: "int32" },
        { name: "target_domain", kind: "string" },
        { name: "target_id", kind: "int32" },
      ],
    ),
  );
  const locations = writeParquet(
    columnsFor(tables.locations ?? [], (row) => [row.snapshotId, row.locationId, row.path, row.kind], [
      { name: "snapshot_id", kind: "string" },
      { name: "location_id", kind: "int32" },
      { name: "path", kind: "string" },
      { name: "kind", kind: "string" },
    ]),
  );
  return { metadata, entities, relations, locations };
}
