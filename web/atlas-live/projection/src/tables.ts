/**
 * Decoding of the canonical world Parquet files into typed rows. This module only
 * checks the physical schema and cell types; every semantic law (snapshot
 * consistency, counts, endpoint resolution) is checked by `projectTables` in
 * graph.ts so that hand-built tables get the same validation as decoded ones.
 *
 * Schemas (see `src/Repository/Table.flix` and the mission's parquet-schemas.md):
 *   metadata:  one row; repository, base_revision, source_tree_identity,
 *              fact_identity, snapshot_id, file_count, symbol_count,
 *              defines_count, imports_count, calls_count, parent_count,
 *              unresolved_imports, unresolved_calls
 *   entities:  snapshot_id, domain, entity_id, ordinal, path,
 *              name?, start_byte?, end_byte?
 *   relations: snapshot_id, relation, source_domain, source_id,
 *              target_domain, target_id
 *   locations (optional): snapshot_id, location_id, path, kind ("file"|"directory")
 */
import { parquetMetadata, parquetReadObjects, parquetSchema, type FileMetaData } from "hyparquet";

import { ProjectionError } from "./errors.ts";

export interface MetadataRow {
  readonly repository: string;
  readonly baseRevision: string;
  readonly sourceTreeIdentity: string;
  readonly factIdentity: string;
  readonly snapshotId: string;
  readonly fileCount: number;
  readonly symbolCount: number;
  readonly definesCount: number;
  readonly importsCount: number;
  readonly callsCount: number;
  readonly parentCount: number;
  readonly unresolvedImports: number;
  readonly unresolvedCalls: number;
}

export interface EntityRow {
  readonly snapshotId: string;
  readonly domain: string;
  readonly entityId: number;
  readonly ordinal: number;
  readonly path: string;
  readonly name: string | null;
  readonly startByte: number | null;
  readonly endByte: number | null;
}

export interface RelationRow {
  readonly snapshotId: string;
  readonly relation: string;
  readonly sourceDomain: string;
  readonly sourceId: number;
  readonly targetDomain: string;
  readonly targetId: number;
}

export interface LocationRow {
  readonly snapshotId: string;
  readonly locationId: number;
  readonly path: string;
  readonly kind: string;
}

export interface WorldTables {
  readonly metadata: MetadataRow;
  readonly entities: readonly EntityRow[];
  readonly relations: readonly RelationRow[];
  readonly locations: readonly LocationRow[] | null;
}

/** One world's Parquet bytes. `locations` is optional (added by the Flix export). */
export interface WorldFiles {
  readonly metadata: ArrayBuffer;
  readonly entities: ArrayBuffer;
  readonly relations: ArrayBuffer;
  readonly locations?: ArrayBuffer;
}

type TableName = "metadata" | "entities" | "relations" | "locations";

const METADATA_COLUMNS = [
  "repository",
  "base_revision",
  "source_tree_identity",
  "fact_identity",
  "snapshot_id",
  "file_count",
  "symbol_count",
  "defines_count",
  "imports_count",
  "calls_count",
  "parent_count",
  "unresolved_imports",
  "unresolved_calls",
] as const;

const ENTITY_COLUMNS = [
  "snapshot_id",
  "domain",
  "entity_id",
  "ordinal",
  "path",
  "name",
  "start_byte",
  "end_byte",
] as const;

const RELATION_COLUMNS = [
  "snapshot_id",
  "relation",
  "source_domain",
  "source_id",
  "target_domain",
  "target_id",
] as const;

const LOCATION_COLUMNS = ["snapshot_id", "location_id", "path", "kind"] as const;

async function readTable(
  file: ArrayBuffer,
  table: TableName,
  expectedColumns: readonly string[],
): Promise<Record<string, unknown>[]> {
  let metadata: FileMetaData;
  try {
    metadata = parquetMetadata(file);
  } catch (cause) {
    throw new ProjectionError({
      kind: "invalid-schema",
      table,
      message: `not a readable Parquet file: ${cause instanceof Error ? cause.message : String(cause)}`,
    });
  }
  const actual = parquetSchema(metadata).children.map((child) => child.element.name);
  if (actual.length !== expectedColumns.length || !expectedColumns.every((c, i) => actual[i] === c)) {
    throw new ProjectionError({
      kind: "invalid-schema",
      table,
      message: `expected columns ${expectedColumns.join(", ")}; got ${actual.join(", ")}`,
    });
  }
  const rows = await parquetReadObjects({ file, metadata });
  return rows.map((row) => {
    const record: Record<string, unknown> = {};
    for (const column of expectedColumns) {
      // ParquetRow values are typed `any`; widen each cell to unknown at the boundary.
      const value = row[column] as unknown;
      if (value === undefined) {
        throw new ProjectionError({ kind: "invalid-schema", table, message: `missing column ${column}` });
      }
      record[column] = value;
    }
    return record;
  });
}

function cell(row: Record<string, unknown>, table: TableName, column: string): unknown {
  const value = row[column];
  if (value === undefined) {
    throw new ProjectionError({ kind: "invalid-schema", table, message: `missing column ${column}` });
  }
  return value;
}

function text(row: Record<string, unknown>, table: TableName, column: string): string {
  const value = cell(row, table, column);
  if (typeof value !== "string") {
    throw new ProjectionError({ kind: "invalid-schema", table, message: `column ${column} is not a string` });
  }
  return value;
}

function optionalText(row: Record<string, unknown>, table: TableName, column: string): string | null {
  const value = cell(row, table, column);
  if (value === null) return null;
  if (typeof value !== "string") {
    throw new ProjectionError({
      kind: "invalid-schema",
      table,
      message: `column ${column} is not a string or null`,
    });
  }
  return value;
}

function integer(row: Record<string, unknown>, table: TableName, column: string): number {
  const value = cell(row, table, column);
  const asNumber = typeof value === "bigint" ? Number(value) : value;
  if (typeof asNumber !== "number" || !Number.isSafeInteger(asNumber)) {
    throw new ProjectionError({
      kind: "invalid-schema",
      table,
      message: `column ${column} is not an integer`,
    });
  }
  return asNumber;
}

function optionalInteger(row: Record<string, unknown>, table: TableName, column: string): number | null {
  const value = cell(row, table, column);
  if (value === null) return null;
  const asNumber = typeof value === "bigint" ? Number(value) : value;
  if (typeof asNumber !== "number" || !Number.isSafeInteger(asNumber)) {
    throw new ProjectionError({
      kind: "invalid-schema",
      table,
      message: `column ${column} is not an integer or null`,
    });
  }
  return asNumber;
}

export async function decodeMetadata(file: ArrayBuffer): Promise<MetadataRow> {
  const rows = await readTable(file, "metadata", METADATA_COLUMNS);
  if (rows.length !== 1) {
    throw new ProjectionError({
      kind: "invalid-schema",
      table: "metadata",
      message: `expected exactly one row, got ${rows.length}`,
    });
  }
  const row = rows[0];
  if (row === undefined) {
    throw new ProjectionError({ kind: "invalid-schema", table: "metadata", message: "missing row" });
  }
  return {
    repository: text(row, "metadata", "repository"),
    baseRevision: text(row, "metadata", "base_revision"),
    sourceTreeIdentity: text(row, "metadata", "source_tree_identity"),
    factIdentity: text(row, "metadata", "fact_identity"),
    snapshotId: text(row, "metadata", "snapshot_id"),
    fileCount: integer(row, "metadata", "file_count"),
    symbolCount: integer(row, "metadata", "symbol_count"),
    definesCount: integer(row, "metadata", "defines_count"),
    importsCount: integer(row, "metadata", "imports_count"),
    callsCount: integer(row, "metadata", "calls_count"),
    parentCount: integer(row, "metadata", "parent_count"),
    unresolvedImports: integer(row, "metadata", "unresolved_imports"),
    unresolvedCalls: integer(row, "metadata", "unresolved_calls"),
  };
}

export async function decodeEntities(file: ArrayBuffer): Promise<EntityRow[]> {
  const rows = await readTable(file, "entities", ENTITY_COLUMNS);
  return rows.map((row) => ({
    snapshotId: text(row, "entities", "snapshot_id"),
    domain: text(row, "entities", "domain"),
    entityId: integer(row, "entities", "entity_id"),
    ordinal: integer(row, "entities", "ordinal"),
    path: text(row, "entities", "path"),
    name: optionalText(row, "entities", "name"),
    startByte: optionalInteger(row, "entities", "start_byte"),
    endByte: optionalInteger(row, "entities", "end_byte"),
  }));
}

export async function decodeRelations(file: ArrayBuffer): Promise<RelationRow[]> {
  const rows = await readTable(file, "relations", RELATION_COLUMNS);
  return rows.map((row) => ({
    snapshotId: text(row, "relations", "snapshot_id"),
    relation: text(row, "relations", "relation"),
    sourceDomain: text(row, "relations", "source_domain"),
    sourceId: integer(row, "relations", "source_id"),
    targetDomain: text(row, "relations", "target_domain"),
    targetId: integer(row, "relations", "target_id"),
  }));
}

export async function decodeLocations(file: ArrayBuffer): Promise<LocationRow[]> {
  const rows = await readTable(file, "locations", LOCATION_COLUMNS);
  return rows.map((row) => ({
    snapshotId: text(row, "locations", "snapshot_id"),
    locationId: integer(row, "locations", "location_id"),
    path: text(row, "locations", "path"),
    kind: text(row, "locations", "kind"),
  }));
}

/** Copies bytes into a fresh ArrayBuffer (hyparquet's AsyncBuffer shape). */
export function toArrayBuffer(bytes: Uint8Array): ArrayBuffer {
  const copy = new Uint8Array(bytes.byteLength);
  copy.set(bytes);
  return copy.buffer;
}

export async function decodeWorldFiles(files: WorldFiles): Promise<WorldTables> {
  const [metadata, entities, relations, locations] = await Promise.all([
    decodeMetadata(files.metadata),
    decodeEntities(files.entities),
    decodeRelations(files.relations),
    files.locations === undefined ? Promise.resolve(null) : decodeLocations(files.locations),
  ]);
  return { metadata, entities, relations, locations };
}
