/**
 * Round-trip tests against the smallest real world (axios/axios), staged by the
 * `axios_world` copy_to_directory target. WORLD_ROOT points at the staged tree.
 */
import { createHash } from "node:crypto";
import { readFile } from "node:fs/promises";
import path from "node:path";
import { env } from "node:process";

import { describe, expect, it } from "vitest";

import { linkRelation, linkSourceDomain, linkTargetDomain, projectTables } from "../src/graph.ts";
import { projectWorld } from "../src/project.ts";
import { RELATION_ORDER, isRelation, type Relation } from "../src/relation.ts";
import { decodeWorldFiles, type RelationRow, type WorldFiles } from "../src/tables.ts";
import { graphSnapshot } from "./snapshot.ts";

const DIGEST = "1e44a1c45ec4a91bb7774dc6d37a2846a5f56262b6fa7ae5722bcbcc15ba10c7";
const WORLD_DIR = path.join(env.WORLD_ROOT ?? "axios_world", DIGEST);

async function readBytes(name: string): Promise<ArrayBuffer> {
  const buffer = await readFile(path.join(WORLD_DIR, name));
  const copy = new Uint8Array(buffer.byteLength);
  copy.set(buffer);
  return copy.buffer;
}

async function readWorld(): Promise<WorldFiles> {
  return {
    metadata: await readBytes("metadata.parquet"),
    entities: await readBytes("entities.parquet"),
    relations: await readBytes("relations.parquet"),
  };
}

function sha256Node(bytes: ArrayBuffer): string {
  return createHash("sha256").update(new Uint8Array(bytes)).digest("hex");
}

describe("real world decode (axios/axios)", () => {
  it("decodes metadata, entities and relations with the documented schemas", async () => {
    const tables = await decodeWorldFiles(await readWorld());
    const { metadata } = tables;
    expect(metadata.repository).toBe("axios/axios");
    expect(metadata.snapshotId).toBe(`repository-snapshot-v1:${DIGEST}`);
    const files = tables.entities.filter((row) => row.domain === "file");
    const symbols = tables.entities.filter((row) => row.domain === "symbol");
    expect(files.length).toBe(metadata.fileCount);
    expect(symbols.length).toBe(metadata.symbolCount);
    expect(tables.relations.length).toBe(
      metadata.definesCount + metadata.importsCount + metadata.callsCount + metadata.parentCount,
    );
    for (const row of tables.entities) {
      expect(row.entityId).toBe(row.ordinal);
    }
  });

  it("projects points = F + S + D and links = defines + imports + calls + parent", async () => {
    const files = await readWorld();
    const tables = await decodeWorldFiles(files);
    const graph = await projectWorld(files);
    const { metadata } = tables;
    const directoryCount = metadata.parentCount - metadata.fileCount + 1;
    expect(graph.directoryCount).toBe(directoryCount);
    expect(graph.pointCount).toBe(metadata.fileCount + metadata.symbolCount + directoryCount);
    expect(graph.linkCount).toBe(
      metadata.definesCount + metadata.importsCount + metadata.callsCount + metadata.parentCount,
    );
    expect(graph.relationCounts).toEqual({
      defines: metadata.definesCount,
      imports: metadata.importsCount,
      calls: metadata.callsCount,
      parent: metadata.parentCount,
    });
  });

  it("round-trips every link's typed endpoints against the original rows (VAL-PROJ-002)", async () => {
    const files = await readWorld();
    const tables = await decodeWorldFiles(files);
    const graph = projectTables(tables, {
      metadata: sha256Node(files.metadata),
      entities: sha256Node(files.entities),
      relations: sha256Node(files.relations),
    });
    // Rebuild the canonical link list from the raw rows.
    const buckets = new Map<Relation, RelationRow[]>();
    for (const relation of RELATION_ORDER) buckets.set(relation, []);
    for (const row of tables.relations) {
      if (!isRelation(row.relation)) throw new Error(`unexpected relation ${row.relation}`);
      buckets.get(row.relation)?.push(row);
    }
    const canonical = RELATION_ORDER.flatMap((relation) => buckets.get(relation) ?? []);
    expect(graph.linkCount).toBe(canonical.length);
    for (const [i, row] of canonical.entries()) {
      expect(linkRelation(graph, i)).toBe(row.relation);
      expect(linkSourceDomain(graph, i)).toBe(row.sourceDomain);
      expect(graph.linkSourceIds[i]).toBe(row.sourceId);
      expect(linkTargetDomain(graph, i)).toBe(row.targetDomain);
      expect(graph.linkTargetIds[i]).toBe(row.targetId);
      const sourceId = graph.pointIds[graph.linkSourceIndices[i] ?? -1];
      const targetId = graph.pointIds[graph.linkTargetIndices[i] ?? -1];
      const expected = (domain: string, id: number): string =>
        domain === "location" && id < graph.fileCount ? `file:${id}` : `${domain}:${id}`;
      expect(sourceId).toBe(expected(row.sourceDomain, row.sourceId));
      expect(targetId).toBe(expected(row.targetDomain, row.targetId));
    }
  });

  it("matches CSR adjacency against a naive recomputation (VAL-PROJ-004)", async () => {
    const graph = await projectWorld(await readWorld());
    for (const relation of RELATION_ORDER) {
      const { out, in: inbound } = graph.adjacency[relation];
      const naiveOut: number[][] = Array.from({ length: graph.pointCount }, () => []);
      const naiveIn: number[][] = Array.from({ length: graph.pointCount }, () => []);
      for (let link = 0; link < graph.linkCount; link++) {
        if (linkRelation(graph, link) !== relation) continue;
        naiveOut[graph.linkSourceIndices[link] ?? -1]?.push(link);
        naiveIn[graph.linkTargetIndices[link] ?? -1]?.push(link);
      }
      expect(out.offsets.length).toBe(graph.pointCount + 1);
      expect(inbound.offsets.length).toBe(graph.pointCount + 1);
      for (let point = 0; point < graph.pointCount; point++) {
        expect(Array.from(out.links.slice(out.offsets[point] ?? 0, out.offsets[point + 1] ?? 0))).toEqual(
          naiveOut[point],
        );
        expect(
          Array.from(inbound.links.slice(inbound.offsets[point] ?? 0, inbound.offsets[point + 1] ?? 0)),
        ).toEqual(naiveIn[point]);
      }
    }
  });

  it("creates no duplicate file points and exactly D directory points (VAL-PROJ-007)", async () => {
    const graph = await projectWorld(await readWorld());
    const directoryIds = graph.pointIds.filter((id) => id.startsWith("location:"));
    expect(directoryIds.length).toBe(graph.directoryCount);
    for (const id of directoryIds) {
      const numeric = Number(id.slice("location:".length));
      expect(numeric).toBeGreaterThanOrEqual(graph.fileCount);
    }
    // parent endpoints below F resolve to file points
    for (let link = 0; link < graph.linkCount; link++) {
      if (linkRelation(graph, link) !== "parent") continue;
      const sourceId = graph.linkSourceIds[link] ?? -1;
      if (sourceId < graph.fileCount) {
        expect(graph.pointIds[graph.linkSourceIndices[link] ?? -1]).toBe(`file:${sourceId}`);
      }
    }
  });

  it("labels every directory point 'directory #<id>' when no locations table is supplied", async () => {
    const graph = await projectWorld(await readWorld());
    for (const [i, id] of graph.pointIds.entries()) {
      if (id.startsWith("location:")) {
        expect(graph.pointLabels[i]).toBe(`directory #${id.slice("location:".length)}`);
        expect(graph.pointPaths[i]).toBeNull();
      }
    }
  });

  it("is deterministic from identical bytes and carries real provenance (VAL-PROJ-006, VAL-PROJ-009)", async () => {
    const files = await readWorld();
    const [a, b] = await Promise.all([projectWorld(files), projectWorld(files)]);
    expect(graphSnapshot(a)).toEqual(graphSnapshot(b));
    expect(a.provenance.fileSha256).toEqual({
      metadata: sha256Node(files.metadata),
      entities: sha256Node(files.entities),
      relations: sha256Node(files.relations),
    });
    expect(a.provenance.repository).toBe("axios/axios");
    expect(a.provenance.snapshotId).toBe(`repository-snapshot-v1:${DIGEST}`);
    expect(a.provenance.baseRevision.length).toBeGreaterThan(0);
    expect(a.provenance.sourceTreeIdentity.startsWith("source-tree-")).toBe(true);
    expect(a.provenance.factIdentity.startsWith("repository-facts-v2:")).toBe(true);
  });
});
