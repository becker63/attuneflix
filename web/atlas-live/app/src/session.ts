/**
 * GraphSession: everything the viewer needs about one loaded world, held outside
 * React. It owns the ViewerGraph (stable indices, typed endpoints, CSR
 * adjacency), its structural layout, the provenance from the manifest, and the
 * DuckDB tables that feed the renderer. React state holds only identities and
 * revision counters.
 */
import type { Domain } from "../../projection/src/domain.ts";
import { DOMAIN_ORDER } from "../../projection/src/domain.ts";
import type { WorldFamilies } from "../../projection/src/families.ts";
import type { ViewerGraph } from "../../projection/src/graph.ts";
import { RELATION_ORDER, type Relation } from "../../projection/src/relation.ts";
import { shouldRenderLinks } from "./datasets.ts";
import type { LocalDuckDB } from "./duckdb.ts";
import {
  degree,
  incidentCounts,
  neighbourhood,
  type Highlight,
  type IncidentCounts,
} from "./neighbourhood.ts";
import type { StructuralLayout } from "./structure.ts";
import type { WorldManifestEntry } from "./world.ts";

export const POINTS_TABLE = "atlas_live_points";
export const LINKS_TABLE = "atlas_live_links";

export interface GraphSessionOptions {
  readonly duckdb: LocalDuckDB;
  readonly entry: WorldManifestEntry;
  readonly graph: ViewerGraph;
  /** The graph's structural layout; the points table's x/y columns come from it. */
  readonly layout: StructuralLayout;
  /** The world's families layer, or null for a world without families data. */
  readonly families?: WorldFamilies | null;
  readonly pointsTable?: string;
  readonly linksTable?: string;
  /** Monotonic across dataset switches; 1 for the first session. */
  readonly sessionRevision?: number;
  /**
   * Aborted when this session is disposed, so in-flight work tied to the session
   * stops. The controller passes the load controller it created for this world.
   */
  readonly abort?: AbortController;
}

export class GraphSession {
  /** The self-hosted DuckDB used by the renderer (its `WasmDuckDBConnection`). */
  readonly duckdb: LocalDuckDB;
  readonly entry: WorldManifestEntry;
  readonly graph: ViewerGraph;
  /** Fixed for the session's lifetime: no view change recomputes it. */
  readonly layout: StructuralLayout;
  /** The world's families layer; null when the world ships no families data. */
  readonly families: WorldFamilies | null;
  readonly pointsTable: string;
  readonly linksTable: string;
  /** Increments when a new session replaces this one; stable for a loaded world. */
  readonly sessionRevision: number;
  /** Increments when the projected topology changes; overlays never touch it. */
  readonly topologyRevision = 1;

  readonly #abort: AbortController;
  readonly #disposalListeners = new Set<() => void>();
  #disposed = false;

  constructor(options: GraphSessionOptions) {
    this.duckdb = options.duckdb;
    this.entry = options.entry;
    this.graph = options.graph;
    this.layout = options.layout;
    this.families = options.families ?? null;
    this.pointsTable = options.pointsTable ?? POINTS_TABLE;
    this.linksTable = options.linksTable ?? LINKS_TABLE;
    this.sessionRevision = options.sessionRevision ?? 1;
    this.#abort = options.abort ?? new AbortController();
  }

  get pointCount(): number {
    return this.graph.pointCount;
  }

  get linkCount(): number {
    return this.graph.linkCount;
  }

  /** Whether the renderer draws this dataset's links (see LINK_RENDER_BUDGET). */
  get renderLinks(): boolean {
    return shouldRenderLinks(this.entry.counts);
  }

  /** False once `dispose()` has run. */
  get live(): boolean {
    return !this.#disposed;
  }

  /** Registered teardown callbacks still attached to this session. */
  get listenerCount(): number {
    return this.#disposalListeners.size;
  }

  /**
   * Registers a teardown callback. `dispose()` runs every registered listener and
   * clears the set, so a disposed session holds no listeners.
   */
  onDispose(listener: () => void): () => void {
    this.#disposalListeners.add(listener);
    return () => {
      this.#disposalListeners.delete(listener);
    };
  }

  pointId(index: number): string | null {
    return this.graph.pointIds[index] ?? null;
  }

  /**
   * The family edge ordinal of an appended family link row, or null when the
   * row is an exact link (or the world has no families). Family rows follow the
   * exact links in the links table (see projection/src/arrow.ts).
   */
  familyEdgeAt(linkIndex: number): number | null {
    const { families } = this;
    if (families === null || linkIndex < this.graph.linkCount) return null;
    return families.renderedEdges[linkIndex - this.graph.linkCount] ?? null;
  }

  domainOf(index: number): Domain | null {
    const rank = this.graph.pointDomains[index];
    return rank === undefined ? null : (DOMAIN_ORDER[rank] ?? null);
  }

  highlight(index: number, enabled: readonly Relation[] = RELATION_ORDER): Highlight {
    return neighbourhood(this.graph, index, enabled);
  }

  counts(index: number): IncidentCounts {
    return incidentCounts(this.graph, index);
  }

  degreeOf(index: number, enabled: readonly Relation[] = RELATION_ORDER): number {
    return degree(this.graph, index, enabled);
  }

  /** First renderer index with at least one incident link, or null. */
  firstPointWithLinks(enabled: readonly Relation[] = RELATION_ORDER): number | null {
    for (let index = 0; index < this.graph.pointCount; index++) {
      if (degree(this.graph, index, enabled) > 0) return index;
    }
    return null;
  }

  /**
   * Disposes this session: fires its AbortController, removes every registered
   * listener, and drops its DuckDB tables. Idempotent.
   */
  async dispose(): Promise<void> {
    if (this.#disposed) return;
    this.#disposed = true;
    if (!this.#abort.signal.aborted) this.#abort.abort();
    for (const listener of this.#disposalListeners) listener();
    this.#disposalListeners.clear();
    await this.duckdb.connection.query(`DROP TABLE IF EXISTS ${this.pointsTable}`);
    await this.duckdb.connection.query(`DROP TABLE IF EXISTS ${this.linksTable}`);
  }
}
