/**
 * SessionController owns the dataset lifecycle outside React: one self-hosted
 * DuckDB for the whole page, the manifest and picker options, and the current
 * GraphSession. React reads it through `useSyncExternalStore` and never holds
 * the graph data itself.
 *
 * Switching datasets:
 *   1. fires the previous in-flight load's AbortController;
 *   2. publishes an explicit loading state (the old session stays mounted and
 *      usable, so a failed switch never blanks the page);
 *   3. loads and inserts the new world's Arrow tables under revision-suffixed
 *      table names (so the old session's tables survive until the swap);
 *   4. disposes the old session — abort fired, listeners removed, its DuckDB
 *      tables dropped — and advances the session revision;
 *   5. publishes the new session; the renderer remounts (camera fits the new
 *      graph) and the selection is pruned against the new graph in main.tsx.
 *
 * A failed load keeps the previous session and reports a readable error naming
 * the dataset; a failed first load reports the empty state.
 */
import { datasetLabel, datasetOptions, type DatasetOption } from "./datasets.ts";
import { publish, publishPerf } from "./diagnostics.ts";
import { createLocalDuckDB, type LocalDuckDB } from "./duckdb.ts";
import { GraphSession, LINKS_TABLE, POINTS_TABLE } from "./session.ts";
import {
  chooseDefaultWorld,
  fetchManifest,
  loadWorld,
  type LoadedWorld,
  type WorldManifest,
  type WorldManifestEntry,
} from "./world.ts";

export type SessionStatus = "booting" | "loading" | "ready" | "error";

export interface SessionSnapshot {
  readonly status: SessionStatus;
  readonly manifest: WorldManifest | null;
  readonly options: readonly DatasetOption[];
  readonly selectedValue: string | null;
  /** The current session, or the last one if a switch is in flight or failed. */
  readonly session: GraphSession | null;
  readonly error: string | null;
  readonly liveSessions: number;
  readonly duckdbTables: readonly string[];
}

export interface SessionDeps {
  createDuckDB(): Promise<LocalDuckDB>;
  fetchManifest(signal: AbortSignal): Promise<WorldManifest>;
  chooseDefaultWorld(manifest: WorldManifest): WorldManifestEntry;
  loadWorld(entry: WorldManifestEntry, signal: AbortSignal): Promise<LoadedWorld>;
}

const DEFAULT_DEPS: SessionDeps = {
  createDuckDB: () => createLocalDuckDB(),
  fetchManifest: (signal) => fetchManifest("manifest.json", signal),
  chooseDefaultWorld,
  loadWorld: (entry, signal) => loadWorld(entry, signal),
};

function messageOf(cause: unknown): string {
  return cause instanceof Error ? cause.message : String(cause);
}

export class SessionController {
  #state: SessionSnapshot = {
    status: "booting",
    manifest: null,
    options: [],
    selectedValue: null,
    session: null,
    error: null,
    liveSessions: 0,
    duckdbTables: [],
  };
  readonly #deps: SessionDeps;
  readonly #listeners = new Set<() => void>();
  readonly #live = new Set<GraphSession>();
  #duckdb: LocalDuckDB | null = null;
  #revision = 0;
  #loadAbort: AbortController | null = null;

  constructor(deps: SessionDeps = DEFAULT_DEPS) {
    this.#deps = deps;
  }

  subscribe = (listener: () => void): (() => void) => {
    this.#listeners.add(listener);
    return () => {
      this.#listeners.delete(listener);
    };
  };

  getSnapshot = (): SessionSnapshot => this.#state;

  /** Boots DuckDB, loads the manifest, and selects the default world. */
  async start(): Promise<void> {
    try {
      const beforeDuckDb = performance.now();
      this.#duckdb ??= await this.#deps.createDuckDB();
      const duckDbMs = Math.round(performance.now() - beforeDuckDb);
      const beforeManifest = performance.now();
      const manifest = await this.#deps.fetchManifest(new AbortController().signal);
      const manifestMs = Math.round(performance.now() - beforeManifest);
      this.#publish({ manifest, options: datasetOptions(manifest) });
      publishPerf({ duckDbMs, manifestMs });
      await this.#load(this.#deps.chooseDefaultWorld(manifest));
    } catch (cause) {
      const error = `Could not load the world list: ${messageOf(cause)}`;
      this.#publish({ status: "error", error });
      publish({ loading: false, ready: false, error });
    }
  }

  /** Loads the dataset with this snapshot id, if the picker offered it. */
  async select(value: string): Promise<void> {
    const option = this.#state.options.find((candidate) => candidate.value === value);
    if (option === undefined) return;
    if (value === this.#state.selectedValue && this.#state.status === "ready") return;
    await this.#load(option.entry);
  }

  /** The live sessions, for tests and the disposal invariant. */
  get liveSessions(): readonly GraphSession[] {
    return [...this.#live];
  }

  async #load(entry: WorldManifestEntry): Promise<void> {
    const option = this.#state.options.find((candidate) => candidate.value === entry.snapshotId);
    const previous = this.#state.session;
    // Fire the superseded load's controller so its fetches stop.
    this.#loadAbort?.abort();
    const abort = new AbortController();
    this.#loadAbort = abort;

    this.#publish({ status: "loading", selectedValue: entry.snapshotId, error: null });
    publish({ loading: true, ready: false, error: null });

    try {
      const duckdb = this.#duckdb;
      if (duckdb === null) throw new Error("DuckDB is not ready");
      const beforeLoad = performance.now();
      const loaded = await this.#deps.loadWorld(entry, abort.signal);
      if (abort.signal.aborted) return;
      const loadMs = Math.round(performance.now() - beforeLoad);

      const revision = this.#revision + 1;
      const pointsTable = `${POINTS_TABLE}_${revision}`;
      const linksTable = `${LINKS_TABLE}_${revision}`;
      const beforeInsert = performance.now();
      await this.#dropTables(duckdb, pointsTable, linksTable);
      await duckdb.connection.insertArrowTable(loaded.tables.points, { name: pointsTable });
      await duckdb.connection.insertArrowTable(loaded.tables.links, { name: linksTable });
      if (abort.signal.aborted) return;
      const insertMs = Math.round(performance.now() - beforeInsert);

      const session = new GraphSession({
        duckdb,
        entry: loaded.entry,
        graph: loaded.graph,
        layout: loaded.layout,
        families: loaded.families,
        physical: loaded.physical,
        pointsTable,
        linksTable,
        sessionRevision: revision,
        abort,
      });
      // The exact table remains available for the existing Families overlay;
      // the default Structure view starts from the projected, coarse wires.
      await duckdb.connection.insertArrowTable(session.initialProjectedLinks(), {
        name: session.getViewSnapshot().linksTable,
      });
      if (abort.signal.aborted) {
        await session.dispose();
        return;
      }
      this.#revision = revision;
      this.#live.add(session);
      // The old session is dropped only once its replacement is live.
      if (previous !== null) await this.#retire(previous);
      const duckdbTables = await this.#tables(duckdb);

      this.#publish({
        status: "ready",
        session,
        selectedValue: entry.snapshotId,
        error: null,
        liveSessions: this.#live.size,
        duckdbTables,
      });
      const counts = loaded.entry.counts;
      publish({
        loading: false,
        ready: false,
        snapshotId: loaded.graph.provenance.snapshotId,
        dataset: {
          repository: loaded.entry.repository,
          baseRevision: loaded.entry.baseRevision,
          synthetic: loaded.entry.synthetic,
        },
        sessionRevision: revision,
        topologyRevision: session.topologyRevision,
        liveSessions: this.#live.size,
        duckdbTables,
        renderLinks: session.renderLinks,
        counts: {
          points: counts.points,
          links: counts.links,
          files: counts.files,
          symbols: counts.symbols,
          directories: counts.directories,
          defines: counts.defines,
          imports: counts.imports,
          calls: counts.calls,
          parent: counts.parent,
        },
        layoutIdentity: loaded.layout.identity,
        layoutRevision: revision,
        families:
          loaded.families === null
            ? null
            : {
                familyCount: loaded.families.familyCount,
                singletonFamilies: loaded.families.singletonCount,
                fallbackMembers: loaded.families.fallbackCount,
                edges: loaded.families.edges.length,
                renderedEdges: loaded.families.renderedEdges.length,
                unattributedEdges: loaded.families.unattributed,
              },
        error: null,
      });
      publishPerf({ loadMs, insertMs, layoutMs: loaded.layoutMs });
    } catch (cause) {
      if (abort.signal.aborted) return;
      const error = `Could not load ${option === undefined ? entry.repository : datasetLabel(option)}: ${messageOf(cause)}`;
      this.#publish({
        status: previous === null ? "error" : "ready",
        session: previous,
        selectedValue: previous === null ? entry.snapshotId : previous.entry.snapshotId,
        error,
        liveSessions: this.#live.size,
        duckdbTables: this.#state.duckdbTables,
      });
      // The old graph is still mounted and rendering, so it stays ready.
      publish({ loading: false, ready: previous !== null, error });
    }
  }

  async #retire(session: GraphSession): Promise<void> {
    await session.dispose();
    this.#live.delete(session);
  }

  async #dropTables(duckdb: LocalDuckDB, pointsTable: string, linksTable: string): Promise<void> {
    await duckdb.connection.query(`DROP TABLE IF EXISTS ${pointsTable}`);
    await duckdb.connection.query(`DROP TABLE IF EXISTS ${linksTable}`);
  }

  /** The `atlas_live_*` tables currently in the database, sorted. */
  async #tables(duckdb: LocalDuckDB): Promise<readonly string[]> {
    const result = await duckdb.connection.query(
      "SELECT table_name FROM information_schema.tables ORDER BY table_name",
    );
    const names: string[] = [];
    for (const row of result.toArray()) {
      const name: unknown = Reflect.get(row, "table_name");
      if (typeof name === "string" && name.startsWith("atlas_live_")) names.push(name);
    }
    return names;
  }

  #publish(patch: Partial<SessionSnapshot>): void {
    this.#state = { ...this.#state, ...patch };
    for (const listener of this.#listeners) listener();
  }
}
