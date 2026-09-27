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
import type { OverlayName } from "./vocabulary.ts";

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

export interface AtlasOverlay {
  readonly name: OverlayName;
  readonly revision: number;
}

export interface DiagnosticsSource {
  /** Viewport coordinates ([x, y]) of a point's centre, or null if unknown. */
  screenPositionOf(index: number): [number, number] | null;
  /** A point index with at least one incident link, or null if none. */
  pointWithIncidentLinks(): number | null;
}

interface DiagnosticsState {
  ready: boolean;
  snapshotId: string | null;
  dataset: AtlasDataset | null;
  sessionRevision: number;
  topologyRevision: number;
  overlay: AtlasOverlay;
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
  buildRevision: string;
  error: string | null;
}

declare const __ATLAS_BUILD_REVISION__: string;

const BUILD_REVISION = typeof __ATLAS_BUILD_REVISION__ === "string" ? __ATLAS_BUILD_REVISION__ : "dev";

const state: DiagnosticsState = {
  ready: false,
  snapshotId: null,
  dataset: null,
  sessionRevision: 0,
  topologyRevision: 0,
  overlay: { name: "structure", revision: 1 },
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
  buildRevision: BUILD_REVISION,
  error: null,
};

let source: DiagnosticsSource | null = null;

/** Merges a patch into the diagnostics state. Internal; the hook stays read-only. */
export function publish(patch: Partial<DiagnosticsState>): void {
  Object.assign(state, patch);
}

export function setDiagnosticsSource(next: DiagnosticsSource | null): void {
  source = next;
}

export function installDiagnostics(): void {
  const hook = {
    get ready(): boolean {
      return state.ready;
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
    get overlay(): AtlasOverlay {
      return state.overlay;
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
    get buildRevision(): string {
      return state.buildRevision;
    },
    get error(): string | null {
      return state.error;
    },
    screenPositionOf(index: number): [number, number] | null {
      return source?.screenPositionOf(index) ?? null;
    },
    pointWithIncidentLinks(): number | null {
      return source?.pointWithIncidentLinks() ?? null;
    },
  };
  Object.defineProperty(globalThis, "__atlasLive", {
    value: hook,
    writable: false,
    configurable: true,
    enumerable: true,
  });
}
