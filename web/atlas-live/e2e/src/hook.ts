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

/** The families-layer summary of the loaded world, or null when it has none. */
export interface AtlasFamilies {
  familyCount: number;
  singletonFamilies: number;
  fallbackMembers: number;
  edges: number;
  renderedEdges: number;
  unattributedEdges: number;
}

/** The family membership of one point, or null when it has none. */
export interface AtlasFamilyMembership {
  ordinal: number;
  familyId: string;
  name: string;
  members: number;
  singleton: boolean;
  fallback: boolean;
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
  overlay: { name: string; revision: number };
  camera: { zoom: number | null };
  perf: Record<string, number>;
  layoutIdentity: string | null;
  layoutRevision: number;
  families: AtlasFamilies | null;
  drilledFamilyEdge: number | null;
  buildRevision: string;
  error: string | null;
  screenPositionOf(index: number): [number, number] | null;
  pointWithIncidentLinks(): number | null;
  pointIdOf(index: number): string | null;
  pointCount(): number;
  familyOfPoint(index: number): AtlasFamilyMembership | null;
}

declare global {
  interface Window {
    __atlasLive?: AtlasLiveHook;
  }
}
