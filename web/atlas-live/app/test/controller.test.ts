import { Table, Utf8, vectorFromArray } from "apache-arrow";
import { describe, expect, it, vi } from "vitest";

import { buildViewerArrow } from "../../projection/src/arrow.ts";
import { SessionController, type SessionDeps } from "../src/controller.ts";
import { installDiagnostics } from "../src/diagnostics.ts";
import type { LocalDuckDB } from "../src/duckdb.ts";
import { structuralLayout } from "../src/structure.ts";
import type { LoadedWorld, WorldManifest, WorldManifestEntry } from "../src/world.ts";
import { fixtureGraph } from "./graphFixture.ts";

/** A DuckDB stand-in that records the tables it holds and the SQL run against it. */
class FakeDuckDB {
  readonly tables = new Set<string>();
  readonly queries: string[] = [];
  readonly inserts: string[] = [];
  readonly connection = {
    insertArrowTable: async (table: Table, options: { name: string }): Promise<void> => {
      void table;
      this.inserts.push(options.name);
      this.tables.add(options.name);
    },
    query: async (sql: string): Promise<Table> => {
      this.queries.push(sql);
      const drop = /^DROP TABLE IF EXISTS (\w+)$/.exec(sql);
      if (drop !== null && drop[1] !== undefined) {
        this.tables.delete(drop[1]);
        return new Table({});
      }
      if (sql.includes("information_schema.tables")) {
        const names = [...this.tables].toSorted();
        return new Table({ table_name: vectorFromArray(names, new Utf8()) });
      }
      return new Table({});
    },
  };
}

function entry(suffix: string, repository: string, points: number): WorldManifestEntry {
  const digest = suffix.repeat(64).slice(0, 64);
  return {
    snapshotId: `repository-snapshot-v1:${digest}`,
    snapshotDigest: digest,
    repository,
    baseRevision: `${digest.slice(0, 8)}ffff`,
    sourceTreeIdentity: `source-tree:${digest.slice(0, 8)}`,
    factIdentity: `facts:${digest.slice(0, 8)}`,
    counts: {
      files: 2,
      symbols: points,
      directories: 2,
      points,
      links: 8,
      defines: 2,
      imports: 1,
      calls: 2,
      parent: 3,
    },
    assets: {
      metadata: `data/${digest}/metadata.parquet`,
      entities: `data/${digest}/entities.parquet`,
      relations: `data/${digest}/relations.parquet`,
    },
    sha256: {
      metadata: "0".repeat(64),
      entities: "1".repeat(64),
      relations: "2".repeat(64),
    },
    synthetic: false,
  };
}

function loaded(manifestEntry: WorldManifestEntry): LoadedWorld {
  const graph = fixtureGraph();
  const layout = structuralLayout(graph);
  return {
    entry: manifestEntry,
    graph,
    tables: buildViewerArrow(graph, { xy: layout.xy }),
    layout,
    families: null,
    layoutMs: 0,
  };
}

/** A field of the installed `window.__atlasLive` hook. */
function read(field: string): unknown {
  const hook: unknown = Reflect.get(globalThis, "__atlasLive");
  if (typeof hook !== "object" || hook === null) throw new Error("no diagnostics hook");
  return Reflect.get(hook, field);
}

function keys(value: unknown): string[] {
  return typeof value === "object" && value !== null ? Object.keys(value).toSorted() : [];
}

interface Harness {
  readonly controller: SessionController;
  readonly duckdb: FakeDuckDB;
  readonly loadedEntries: WorldManifestEntry[];
  failNext: string | null;
}

function harness(worlds: readonly WorldManifestEntry[], synthetic: WorldManifestEntry | null): Harness {
  const duckdb = new FakeDuckDB();
  const manifest: WorldManifest = { version: 1, worlds, synthetic };
  const state: Harness = { controller: undefined!, duckdb, loadedEntries: [], failNext: null };
  const deps: SessionDeps = {
    // oxlint-disable-next-line typescript/no-unsafe-type-assertion -- the controller only touches `.connection`, which FakeDuckDB implements; a real AsyncDuckDB is not constructible in a unit test.
    createDuckDB: async () => duckdb as unknown as LocalDuckDB,
    fetchManifest: async () => manifest,
    chooseDefaultWorld: (value) => {
      const first = value.worlds[0];
      if (first === undefined) throw new Error("no default world");
      return first;
    },
    loadWorld: async (value) => {
      if (state.failNext !== null) {
        const message = state.failNext;
        state.failNext = null;
        throw new Error(message);
      }
      state.loadedEntries.push(value);
      return loaded(value);
    },
  };
  const controller = new SessionController(deps);
  return Object.assign(state, { controller });
}

describe("SessionController lifecycle", () => {
  it("loads the default world and leaves exactly one live session with its tables", async () => {
    const worlds = [entry("a", "acme/one", 3), entry("b", "acme/two", 4)];
    const h = harness(worlds, null);
    await h.controller.start();
    const snapshot = h.controller.getSnapshot();
    expect(snapshot.status).toBe("ready");
    expect(snapshot.session?.entry.snapshotId).toBe(worlds[0]?.snapshotId);
    expect(snapshot.liveSessions).toBe(1);
    expect(snapshot.duckdbTables).toEqual(["atlas_live_links_1", "atlas_live_points_1"]);
    expect(h.controller.liveSessions).toHaveLength(1);
  });

  it("switching disposes the old session: revision advances, tables swapped, listeners removed", async () => {
    const worlds = [entry("a", "acme/one", 3), entry("b", "acme/two", 4)];
    const h = harness(worlds, null);
    await h.controller.start();
    const first = h.controller.getSnapshot().session;
    expect(first).not.toBeNull();
    if (first === null) return;
    const disposed = vi.fn();
    first.onDispose(disposed);
    expect(first.listenerCount).toBe(1);

    await h.controller.select(worlds[1]?.snapshotId ?? "");
    const snapshot = h.controller.getSnapshot();
    expect(snapshot.selectedValue).toBe(worlds[1]?.snapshotId);
    expect(snapshot.session?.sessionRevision).toBe(2);
    expect(snapshot.session?.entry.snapshotId).toBe(worlds[1]?.snapshotId);
    expect(snapshot.liveSessions).toBe(1);
    expect(h.controller.liveSessions).toHaveLength(1);

    // The old session is disposed: its AbortController fired, its listeners ran,
    // and its DuckDB tables are gone.
    expect(disposed).toHaveBeenCalledTimes(1);
    expect(first.live).toBe(false);
    expect(first.listenerCount).toBe(0);
    expect(h.duckdb.tables.has("atlas_live_points_1")).toBe(false);
    expect(h.duckdb.tables.has("atlas_live_links_1")).toBe(false);
    expect(snapshot.duckdbTables).toEqual(["atlas_live_links_2", "atlas_live_points_2"]);
  });

  it("a failed switch keeps the previous session usable and reports a readable error", async () => {
    const worlds = [entry("a", "acme/one", 3), entry("b", "acme/two", 4)];
    const h = harness(worlds, null);
    await h.controller.start();
    const previous = h.controller.getSnapshot().session;
    h.failNext = "HTTP 500";
    await h.controller.select(worlds[1]?.snapshotId ?? "");
    const snapshot = h.controller.getSnapshot();
    expect(snapshot.session).toBe(previous);
    expect(snapshot.status).toBe("ready");
    expect(snapshot.liveSessions).toBe(1);
    expect(snapshot.error).toContain("acme/two");
    expect(snapshot.error).toContain("HTTP 500");
  });

  it("publishes the layout identity and revision, and merges perf timings across loads", async () => {
    installDiagnostics();
    const worlds = [entry("a", "acme/one", 3), entry("b", "acme/two", 4)];
    const h = harness(worlds, null);
    await h.controller.start();
    const identity = structuralLayout(fixtureGraph()).identity;
    expect(read("layoutIdentity")).toBe(identity);
    expect(read("layoutRevision")).toBe(1);
    // A world without families data publishes no families summary.
    expect(read("families")).toBeNull();
    expect(keys(read("perf"))).toEqual(["duckDbMs", "insertMs", "layoutMs", "loadMs", "manifestMs"]);
    await h.controller.select(worlds[1]?.snapshotId ?? "");
    expect(read("layoutRevision")).toBe(2);
    expect(read("layoutIdentity")).toBe(identity);
    expect(keys(read("perf"))).toContain("duckDbMs");
  });

  it("includes the synthetic fixture as a selectable option and loads it", async () => {
    const worlds = [entry("a", "acme/one", 3)];
    const synthetic = { ...entry("c", "synthetic", 5), synthetic: true };
    const h = harness(worlds, synthetic);
    await h.controller.start();
    expect(h.controller.getSnapshot().options).toHaveLength(2);
    await h.controller.select(synthetic.snapshotId);
    expect(h.controller.getSnapshot().session?.entry.synthetic).toBe(true);
  });
});
