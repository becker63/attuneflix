/**
 * `window.__atlasLive`: the read-only diagnostics hook for Playwright and
 * agent-browser. It never contains secrets and never mutates app state.
 *
 * The documented fields (see web/atlas-live/README.md) are exposed as live
 * getters over an internal state object, so a reader always sees the current
 * value. `screenPositionOf` and `pointWithIncidentLinks` are read-only lookup
 * helpers for the browser tests; they compute from the renderer and the
 * projected graph and change nothing.
 */
import { RELATION_ORDER, type Relation } from "../../projection/src/relation.ts";
import type { RegionMetrics } from "./frontier/metrics.ts";
import type { MeasurementMode } from "./atoms.ts";

export interface AtlasCounts {
  readonly points: number;
  readonly links: number;
  readonly files: number;
  readonly symbols: number;
  readonly directories: number;
  readonly defines: number;
  readonly imports: number;
  readonly calls: number;
  readonly parent: number;
}

export interface AtlasDataset {
  readonly repository: string;
  readonly baseRevision: string;
  readonly synthetic: boolean;
}

export interface AtlasHighlight {
  readonly points: readonly string[];
  readonly links: readonly number[];
}

export interface AtlasCamera {
  readonly zoom: number | null;
}

/** The families-layer summary of the loaded world, or null when it has none. */
export interface AtlasFamilies {
  readonly familyCount: number;
  /** Families with exactly one member. */
  readonly singletonFamilies: number;
  /** Members no recorded frontier held (the defining-file seed fallback). */
  readonly fallbackMembers: number;
  /** Family edges in total (intra-family included). */
  readonly edges: number;
  /** Cross-family edges (the rendered family links). */
  readonly renderedEdges: number;
  /** Exact imports/calls edges that name no family edge (no callable endpoint). */
  readonly unattributedEdges: number;
}

/** The family membership of one point, or null when it has none. */
export interface AtlasFamilyMembership {
  readonly ordinal: number;
  readonly familyId: string;
  readonly name: string;
  readonly members: number;
  readonly singleton: boolean;
  /** True when this symbol joined via the defining-file seed fallback. */
  readonly fallback: boolean;
}

export interface AtlasOverlay {
  readonly name: "structure";
  readonly revision: number;
}

export interface AtlasShading {
  readonly name: MeasurementMode;
  readonly revision: number;
}

export interface AtlasFrontier {
  readonly expanded: readonly string[];
  readonly revision: number;
  readonly level: "repository" | "directory" | "file" | "symbol";
}

export interface AtlasProjected {
  readonly nodeCount: number;
  /** Enabled basis edges that cross frontier boundaries. */
  readonly edgeCount: number;
  /** Distinct drawn wires after aggregation. */
  readonly aggregatedEdgeCount: number;
  readonly internalizedCount: number;
}

export interface AtlasSelectedEdge {
  readonly source: string;
  readonly target: string;
  readonly relation: "imports" | "calls";
  readonly multiplicity: number;
  readonly provenanceCount: number;
  readonly uniqueSources: number;
  readonly uniqueTargets: number;
}

export interface DiagnosticsSource {
  /** Viewport coordinates ([x, y]) of a point's centre, or null if unknown. */
  screenPositionOf(index: number): [number, number] | null;
  /** Viewport endpoints of one projected wire, for read-only browser inspection. */
  projectedWireScreenEndpoints(index: number): { source: [number, number]; target: [number, number] } | null;
  /** A point index with at least one incident link, or null if none. */
  pointWithIncidentLinks(): number | null;
  /** The identity (`domain:localId`) of the point at this renderer index, or null. */
  pointIdOf(index: number): string | null;
  /** The current number of points in the loaded graph. */
  pointCount(): number;
  /** The family membership of a point, or null when the world or point has none. */
  familyOfPoint(index: number): AtlasFamilyMembership | null;
  /** Point ids on the visible frontier, in graph order. */
  visibleNodeIds(): readonly string[];
  regionMetrics(id: string): RegionMetrics | null;
}

interface DiagnosticsState {
  ready: boolean;
  loading: boolean;
  snapshotId: string | null;
  dataset: AtlasDataset | null;
  sessionRevision: number;
  topologyRevision: number;
  /** Number of live GraphSessions; exactly one once a dataset is loaded. */
  liveSessions: number;
  /** The DuckDB tables the current live session owns (never a disposed one's). */
  duckdbTables: readonly string[];
  /** Whether the renderer draws the current dataset's links (see LINK_RENDER_BUDGET). */
  renderLinks: boolean;
  overlay: AtlasOverlay;
  shading: AtlasShading;
  frontier: AtlasFrontier;
  projected: AtlasProjected;
  selectedEdge: AtlasSelectedEdge | null;
  selectedRegion: RegionMetrics | null;
  counts: AtlasCounts | null;
  hovered: string | null;
  hoveredIndex: number | null;
  highlighted: AtlasHighlight;
  selected: readonly string[];
  relationFilter: readonly Relation[];
  filterRevision: number;
  depth: number;
  camera: AtlasCamera;
  perf: Record<string, number>;
  /** Content hash of the current world's structural layout, or null before load. */
  layoutIdentity: string | null;
  /** Advances only when a new world's geometry is adopted; no view change touches it. */
  layoutRevision: number;
  /** The loaded world's families summary, or null when it ships no families data. */
  families: AtlasFamilies | null;
  /** The drilled-down family edge ordinal, or null. */
  drilledFamilyEdge: number | null;
  buildRevision: string;
  error: string | null;
}

declare const __ATLAS_BUILD_REVISION__: string;

const BUILD_REVISION = typeof __ATLAS_BUILD_REVISION__ === "string" ? __ATLAS_BUILD_REVISION__ : "dev";

const state: DiagnosticsState = {
  ready: false,
  loading: false,
  snapshotId: null,
  dataset: null,
  sessionRevision: 0,
  topologyRevision: 0,
  liveSessions: 0,
  duckdbTables: [],
  renderLinks: true,
  overlay: { name: "structure", revision: 0 },
  shading: { name: "structure", revision: 0 },
  frontier: { expanded: [], revision: 0, level: "repository" },
  projected: { nodeCount: 0, edgeCount: 0, aggregatedEdgeCount: 0, internalizedCount: 0 },
  selectedEdge: null,
  selectedRegion: null,
  counts: null,
  hovered: null,
  hoveredIndex: null,
  highlighted: { points: [], links: [] },
  selected: [],
  relationFilter: [...RELATION_ORDER],
  filterRevision: 0,
  depth: 1,
  camera: { zoom: null },
  perf: {},
  layoutIdentity: null,
  layoutRevision: 0,
  families: null,
  drilledFamilyEdge: null,
  buildRevision: BUILD_REVISION,
  error: null,
};

let source: DiagnosticsSource | null = null;

/** Merges a patch into the diagnostics state. Internal; the hook stays read-only. */
export function publish(patch: Partial<DiagnosticsState>): void {
  Object.assign(state, patch);
}

/** Merges timings into `perf`, so earlier fields (e.g. `duckDbMs`) survive later loads. */
export function publishPerf(timings: Readonly<Record<string, number>>): void {
  state.perf = { ...state.perf, ...timings };
}

export function setDiagnosticsSource(next: DiagnosticsSource | null): void {
  source = next;
}

export function installDiagnostics(): void {
  const hook = {
    get ready(): boolean {
      return state.ready;
    },
    get loading(): boolean {
      return state.loading;
    },
    get snapshotId(): string | null {
      return state.snapshotId;
    },
    get dataset(): AtlasDataset | null {
      return state.dataset;
    },
    get sessionRevision(): number {
      return state.sessionRevision;
    },
    get topologyRevision(): number {
      return state.topologyRevision;
    },
    get liveSessions(): number {
      return state.liveSessions;
    },
    get duckdbTables(): readonly string[] {
      return state.duckdbTables;
    },
    get renderLinks(): boolean {
      return state.renderLinks;
    },
    get overlay(): AtlasOverlay {
      return state.overlay;
    },
    get shading(): AtlasShading {
      return state.shading;
    },
    get frontier(): AtlasFrontier {
      return state.frontier;
    },
    get projected(): AtlasProjected {
      return state.projected;
    },
    get selectedEdge(): AtlasSelectedEdge | null {
      return state.selectedEdge;
    },
    get selectedRegion(): RegionMetrics | null {
      return state.selectedRegion;
    },
    get counts(): AtlasCounts | null {
      return state.counts;
    },
    get hovered(): string | null {
      return state.hovered;
    },
    get hoveredIndex(): number | null {
      return state.hoveredIndex;
    },
    get highlighted(): AtlasHighlight {
      return state.highlighted;
    },
    get selected(): readonly string[] {
      return state.selected;
    },
    get relationFilter(): readonly Relation[] {
      return state.relationFilter;
    },
    get filterRevision(): number {
      return state.filterRevision;
    },
    get depth(): number {
      return state.depth;
    },
    get camera(): AtlasCamera {
      return state.camera;
    },
    get perf(): Record<string, number> {
      return state.perf;
    },
    get layoutIdentity(): string | null {
      return state.layoutIdentity;
    },
    get layoutRevision(): number {
      return state.layoutRevision;
    },
    get families(): AtlasFamilies | null {
      return state.families;
    },
    get drilledFamilyEdge(): number | null {
      return state.drilledFamilyEdge;
    },
    get buildRevision(): string {
      return state.buildRevision;
    },
    get error(): string | null {
      return state.error;
    },
    screenPositionOf(index: number): [number, number] | null {
      return source?.screenPositionOf(index) ?? null;
    },
    projectedWireScreenEndpoints(index: number): { source: [number, number]; target: [number, number] } | null {
      return source?.projectedWireScreenEndpoints(index) ?? null;
    },
    pointWithIncidentLinks(): number | null {
      return source?.pointWithIncidentLinks() ?? null;
    },
    pointIdOf(index: number): string | null {
      return source?.pointIdOf(index) ?? null;
    },
    pointCount(): number {
      return source?.pointCount() ?? 0;
    },
    visibleNodeIds(): readonly string[] {
      return source?.visibleNodeIds() ?? [];
    },
    regionMetrics(id: string): RegionMetrics | null {
      return source?.regionMetrics(id) ?? null;
    },
    familyOfPoint(index: number): AtlasFamilyMembership | null {
      return source?.familyOfPoint(index) ?? null;
    },
  };
  Object.defineProperty(globalThis, "__atlasLive", {
    value: hook,
    writable: false,
    configurable: true,
    enumerable: true,
  });
}
