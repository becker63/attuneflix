import { describe, expect, it } from "vitest";

import { projectTables } from "../src/graph.ts";
import { manifestEntry, serializeManifest, snapshotDigest } from "../src/manifest.ts";
import {
  FIXTURE_HASHES,
  FIXTURE_HASHES_WITH_LOCATIONS,
  FIXTURE_SNAPSHOT_ID,
  fixtureTables,
} from "./fixture.ts";

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}

describe("manifest entries (VAL-PROJ-010)", () => {
  it("derives the content-addressed digest from the snapshot id", () => {
    expect(snapshotDigest(FIXTURE_SNAPSHOT_ID)).toBe(
      "f17tu2e0000000000000000000000000000000000000000000000000000000",
    );
  });

  it("carries counts equal to the metadata formulas", () => {
    const graph = projectTables(fixtureTables(true), FIXTURE_HASHES_WITH_LOCATIONS);
    const entry = manifestEntry(graph);
    expect(entry).toEqual({
      snapshotId: FIXTURE_SNAPSHOT_ID,
      snapshotDigest: "f17tu2e0000000000000000000000000000000000000000000000000000000",
      repository: "acme/fixture",
      baseRevision: "f00dcafe",
      sourceTreeIdentity: "source-tree-fixture-v1:aaaa",
      factIdentity: "repository-facts-v2:bbbb",
      counts: {
        files: 3,
        symbols: 4,
        directories: 2,
        points: 9,
        links: 13,
        defines: 4,
        imports: 2,
        calls: 3,
        parent: 4,
      },
      assets: {
        metadata: "data/f17tu2e0000000000000000000000000000000000000000000000000000000/metadata.parquet",
        entities: "data/f17tu2e0000000000000000000000000000000000000000000000000000000/entities.parquet",
        relations: "data/f17tu2e0000000000000000000000000000000000000000000000000000000/relations.parquet",
        locations: "data/f17tu2e0000000000000000000000000000000000000000000000000000000/locations.parquet",
      },
      sha256: FIXTURE_HASHES_WITH_LOCATIONS,
      synthetic: false,
    });
  });

  it("marks a synthetic fixture entry synthetic and keeps it out of the worlds list", () => {
    const graph = projectTables(fixtureTables(false), FIXTURE_HASHES);
    const entry = manifestEntry(graph, true);
    expect(entry.synthetic).toBe(true);
    const world = { ...entry, synthetic: false, snapshotId: "repository-snapshot-v1:aaaa" };
    const parsed: unknown = JSON.parse(serializeManifest([world], entry));
    expect(isRecord(parsed)).toBe(true);
    if (!isRecord(parsed)) return;
    expect(parsed.version).toBe(1);
    const worlds = parsed.worlds;
    if (Array.isArray(worlds)) expect(worlds).toHaveLength(1);
    const synthetic = parsed.synthetic;
    expect(isRecord(synthetic)).toBe(true);
    if (isRecord(synthetic)) expect(synthetic.synthetic).toBe(true);
  });

  it("omits the locations asset when no locations table was supplied", () => {
    const graph = projectTables(fixtureTables(false), FIXTURE_HASHES);
    const entry = manifestEntry(graph);
    expect("locations" in entry.assets).toBe(false);
    expect("locations" in entry.sha256).toBe(false);
  });

  it("serializes deterministically, sorted by snapshot id (VAL-PROJ-006)", () => {
    const graph = projectTables(fixtureTables(false), FIXTURE_HASHES);
    const entry = manifestEntry(graph);
    const other = { ...entry, snapshotId: "repository-snapshot-v1:aaaa", snapshotDigest: "aaaa" };
    const a = serializeManifest([entry, other]);
    const b = serializeManifest([other, entry]);
    expect(a).toBe(b);
    expect(a.indexOf('"repository-snapshot-v1:aaaa"')).toBeLessThan(
      a.indexOf(JSON.stringify(FIXTURE_SNAPSHOT_ID)),
    );
    const parsed: unknown = JSON.parse(a);
    expect(parsed).toMatchObject({ version: 1 });
  });
});
