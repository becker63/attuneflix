/**
 * The `window.__atlasLive` diagnostics hook, as the Playwright specs read it.
 * Declared once here and imported by every spec, so the global `Window`
 * augmentation is a single identical declaration (two specs declaring the same
 * property with different types fails the typecheck).
 */
export interface AtlasCounts {
  points: number;
  links: number;
  files: number;
  symbols: number;
  directories: number;
  defines: number;
  imports: number;
  calls: number;
  parent: number;
}

export interface AtlasHighlight {
  points: string[];
  links: number[];
}

export interface AtlasLiveHook {
  ready: boolean;
  loading: boolean;
  snapshotId: string | null;
  dataset: { repository: string; baseRevision: string; synthetic: boolean } | null;
  sessionRevision: number;
  topologyRevision: number;
  liveSessions: number;
  duckdbTables: readonly string[];
  renderLinks: boolean;
  counts: AtlasCounts | null;
  hovered: string | null;
  hoveredIndex: number | null;
  highlighted: AtlasHighlight;
  selected: readonly string[];
  filterRevision: number;
  camera: { zoom: number | null };
  perf: Record<string, number>;
  layoutIdentity: string | null;
  layoutRevision: number;
  buildRevision: string;
  error: string | null;
  screenPositionOf(index: number): [number, number] | null;
  pointWithIncidentLinks(): number | null;
  pointIdOf(index: number): string | null;
  pointCount(): number;
}

declare global {
  interface Window {
    __atlasLive?: AtlasLiveHook;
  }
}
