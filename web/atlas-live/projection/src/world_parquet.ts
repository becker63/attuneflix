/**
 * The four canonical world Parquet files, written from typed rows with the
 * minimal writer. This is the single owner of the metadata/entities/relations/
 * locations column specs and value order, shared by the synthetic stress fixture
 * and the local-import fixture folders, so both are byte-compatible with the
 * reader the viewer uses in Node and in the browser.
 *
 * It is not a general writer: it exists so the fixtures flow through the
 * identical `projectWorld` path as a real world, with no reader special-case.
 */
import { writeParquet, type ParquetColumn } from "./parquet.ts";
import type { WorldTables } from "./tables.ts";

interface ColumnSpec {
  readonly name: string;
  readonly kind: "int32" | "string";
  readonly nullable?: boolean;
}

const METADATA_SPEC: readonly ColumnSpec[] = [
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
];

const ENTITIES_SPEC: readonly ColumnSpec[] = [
  { name: "snapshot_id", kind: "string" },
  { name: "domain", kind: "string" },
  { name: "entity_id", kind: "int32" },
  { name: "ordinal", kind: "int32" },
  { name: "path", kind: "string" },
  { name: "name", kind: "string", nullable: true },
  { name: "start_byte", kind: "int32", nullable: true },
  { name: "end_byte", kind: "int32", nullable: true },
];

const RELATIONS_SPEC: readonly ColumnSpec[] = [
  { name: "snapshot_id", kind: "string" },
  { name: "relation", kind: "string" },
  { name: "source_domain", kind: "string" },
  { name: "source_id", kind: "int32" },
  { name: "target_domain", kind: "string" },
  { name: "target_id", kind: "int32" },
];

const LOCATIONS_SPEC: readonly ColumnSpec[] = [
  { name: "snapshot_id", kind: "string" },
  { name: "location_id", kind: "int32" },
  { name: "path", kind: "string" },
  { name: "kind", kind: "string" },
];

function columnsFor<T>(
  rows: readonly T[],
  select: (row: T) => ReadonlyArray<number | string | null>,
  spec: readonly ColumnSpec[],
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
    columns.push({ name: entry.name, kind: entry.kind, nullable: entry.nullable, values });
  }
  return columns;
}

export interface WorldParquetFiles {
  readonly metadata: Uint8Array;
  readonly entities: Uint8Array;
  readonly relations: Uint8Array;
  /** Always written; a world without a locations table emits zero rows. */
  readonly locations: Uint8Array;
}

/** The four canonical world Parquet files for typed rows, in the reader's schema. */
export function worldParquetFiles(tables: WorldTables): WorldParquetFiles {
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
      METADATA_SPEC,
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
      ENTITIES_SPEC,
    ),
  );
  const relations = writeParquet(
    columnsFor(
      tables.relations,
      (row) => [row.snapshotId, row.relation, row.sourceDomain, row.sourceId, row.targetDomain, row.targetId],
      RELATIONS_SPEC,
    ),
  );
  const locations = writeParquet(
    columnsFor(
      tables.locations ?? [],
      (row) => [row.snapshotId, row.locationId, row.path, row.kind],
      LOCATIONS_SPEC,
    ),
  );
  return { metadata, entities, relations, locations };
}
