/**
 * GraphSession: everything the viewer needs about one loaded world, held outside
 * React. It owns the ViewerGraph (stable indices, typed endpoints, CSR
 * adjacency), its structural layout, the provenance from the manifest, and the
 * DuckDB tables that feed the renderer. React state holds only identities and
 * revision counters.
 */
import type { Domain } from "../../projection/src/domain.ts";
import type { WorldAnchors } from "../../projection/src/anchors.ts";
import { DOMAIN_ORDER } from "../../projection/src/domain.ts";
import type { WorldFamilies } from "../../projection/src/families.ts";
import type { ViewerGraph } from "../../projection/src/graph.ts";
import type { WorldPhysical } from "../../projection/src/physical.ts";
import { RELATION_ORDER, type Relation } from "../../projection/src/relation.ts";
import { shouldRenderLinks } from "./datasets.ts";
import type { LocalDuckDB } from "./duckdb.ts";
import { projectedLinksArrow } from "./frontier/arrow.ts";
import { containmentTree, type ContainmentTree } from "./frontier/containment.ts";
import { collapse, expand, initialFrontier, pi, type VisibleFrontier } from "./frontier/frontier.ts";
import { computeProjectionMetrics, type ProjectionMetrics, type RegionMetrics } from "./frontier/metrics.ts";
import { projectFrontier, type FrontierProjection, type WireRelation } from "./frontier/wires.ts";
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

export interface FrontierViewSnapshot {
  readonly frontier: VisibleFrontier;
  readonly projection: FrontierProjection;
  readonly linksTable: string;
  /** Advances for expansion, collapse, and enabled-wire changes. */
  readonly revision: number;
}

export interface GraphSessionOptions {
  readonly duckdb: LocalDuckDB;
  readonly entry: WorldManifestEntry;
  readonly graph: ViewerGraph;
  /** The graph's structural layout; the points table's x/y columns come from it. */
  readonly layout: StructuralLayout;
  /** The world's families layer, or null for a world without families data. */
  readonly families?: WorldFamilies | null;
  readonly physical?: WorldPhysical | null;
  readonly anchors?: WorldAnchors | null;
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
  readonly physical: WorldPhysical | null;
  readonly anchors: WorldAnchors | null;
  readonly pointsTable: string;
  readonly linksTable: string;
  /** Increments when a new session replaces this one; stable for a loaded world. */
  readonly sessionRevision: number;
  /** Increments when the projected topology changes; overlays never touch it. */
  readonly topologyRevision = 1;
  readonly containment: ContainmentTree;

  #view: FrontierViewSnapshot;
  readonly #viewListeners = new Set<() => void>();
  readonly #projectedTables = new Set<string>();
  #viewSerial = 0;
  #pendingView: Promise<void> = Promise.resolve();
  #visibleMask: Uint8Array;
  #metrics: ProjectionMetrics | null = null;

  readonly #abort: AbortController;
  readonly #disposalListeners = new Set<() => void>();
  #disposed = false;

  constructor(options: GraphSessionOptions) {
    this.duckdb = options.duckdb;
    this.entry = options.entry;
    this.graph = options.graph;
    this.layout = options.layout;
    this.families = options.families ?? null;
    this.physical = options.physical ?? null;
    this.anchors = options.anchors ?? null;
    this.pointsTable = options.pointsTable ?? POINTS_TABLE;
    this.linksTable = options.linksTable ?? LINKS_TABLE;
    this.sessionRevision = options.sessionRevision ?? 1;
    this.#abort = options.abort ?? new AbortController();
    this.containment = containmentTree(this.graph);
    const frontier = initialFrontier();
    const projection = projectFrontier(this.graph, this.containment, frontier, ["imports", "calls"]);
    const table = `${this.linksTable}_frontier_0`;
    this.#view = { frontier, projection, linksTable: table, revision: 0 };
    this.#projectedTables.add(table);
    this.#visibleMask = this.#maskOf(projection);
  }

  subscribeView = (listener: () => void): (() => void) => {
    this.#viewListeners.add(listener);
    return () => this.#viewListeners.delete(listener);
  };

  getViewSnapshot = (): FrontierViewSnapshot => this.#view;

  /** The selected concrete node's own metrics, or its enclosing visible region. */
  metricsFor(index: number): RegionMetrics | null {
    if (index < 0 || index >= this.graph.pointCount) return null;
    this.#metrics ??= computeProjectionMetrics(this.graph, this.containment, this.#view.projection);
    const region = pi(this.containment, this.#view.frontier, index);
    const id = this.graph.pointIds[region];
    return id === undefined ? null : (this.#metrics.get(id) ?? null);
  }

  /** All metrics for the current projected frontier, cached until it changes. */
  projectionMetrics(): ProjectionMetrics {
    this.#metrics ??= computeProjectionMetrics(this.graph, this.containment, this.#view.projection);
    return this.#metrics;
  }

  isVisibleIndex(index: number): boolean {
    return this.#visibleMask[index] === 1;
  }

  /** Controller inserts this before publishing the session, so the first paint is coarse. */
  initialProjectedLinks() {
    return projectedLinksArrow(this.graph, this.#view.projection);
  }

  /** Expands or collapses a visible container without changing admitted graph or layout. */
  changeFrontier(id: string, action: "expand" | "collapse"): Promise<void> {
    return this.#enqueue(async () => {
      const next =
        action === "expand"
          ? expand(this.containment, this.#view.frontier, id)
          : collapse(this.containment, this.#view.frontier, id);
      if (next === this.#view.frontier) return;
      await this.#replaceView(next, this.#view.projection.enabled);
    });
  }

  /** Reveal a directly selected file or symbol with one projection update. */
  revealOrigin(id: string): Promise<void> {
    return this.#enqueue(async () => {
      const point = this.graph.indexById.get(id);
      if (point === undefined || this.#disposed) return;
      const ancestors: string[] = [];
      let parent = this.containment.containerOf[point] ?? -1;
      while (parent >= 0 && parent !== this.containment.root) {
        const ancestorId = this.graph.pointIds[parent];
        if (ancestorId !== undefined) ancestors.push(ancestorId);
        parent = this.containment.containerOf[parent] ?? -1;
      }
      let frontier = this.#view.frontier;
      for (const ancestor of ancestors.toReversed()) {
        frontier = expand(this.containment, frontier, ancestor);
      }
      if (frontier !== this.#view.frontier) await this.#replaceView(frontier, this.#view.projection.enabled);
    });
  }

  /** A relation filter changes the projected wires, never the basis graph. */
  setWireRelations(enabled: readonly WireRelation[]): Promise<void> {
    return this.#enqueue(async () => {
      if (enabled.join(",") === this.#view.projection.enabled.join(",")) return;
      await this.#replaceView(this.#view.frontier, enabled);
    });
  }

  #enqueue(change: () => Promise<void>): Promise<void> {
    const next = this.#pendingView.then(change, change);
    this.#pendingView = next.catch(() => undefined);
    return next;
  }

  async #replaceView(frontier: VisibleFrontier, enabled: readonly WireRelation[]): Promise<void> {
    if (this.#disposed) return;
    const projection = projectFrontier(this.graph, this.containment, frontier, enabled);
    const table = `${this.linksTable}_frontier_${++this.#viewSerial}`;
    await this.duckdb.connection.insertArrowTable(projectedLinksArrow(this.graph, projection), {
      name: table,
    });
    if (this.#disposed) {
      await this.duckdb.connection.query(`DROP TABLE IF EXISTS ${table}`);
      return;
    }
    this.#projectedTables.add(table);
    this.#visibleMask = this.#maskOf(projection);
    this.#metrics = null;
    this.#view = { frontier, projection, linksTable: table, revision: this.#view.revision + 1 };
    for (const listener of this.#viewListeners) listener();
  }

  #maskOf(projection: FrontierProjection): Uint8Array {
    const mask = new Uint8Array(this.graph.pointCount);
    for (const node of projection.nodes) mask[node.index] = 1;
    return mask;
  }

  /** Called after Cosmograph has rebuilt against the latest projected table. */
  async retireOldProjectedTables(): Promise<void> {
    for (const table of this.#projectedTables) {
      if (table === this.#view.linksTable) continue;
      await this.duckdb.connection.query(`DROP TABLE IF EXISTS ${table}`);
      this.#projectedTables.delete(table);
    }
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
    this.#viewListeners.clear();
    await this.#pendingView;
    for (const table of this.#projectedTables) {
      await this.duckdb.connection.query(`DROP TABLE IF EXISTS ${table}`);
    }
    this.#projectedTables.clear();
    await this.duckdb.connection.query(`DROP TABLE IF EXISTS ${this.pointsTable}`);
    await this.duckdb.connection.query(`DROP TABLE IF EXISTS ${this.linksTable}`);
  }
}
