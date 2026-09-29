/**
 * Stable per-view link accessors for the renderer. Cosmograph compares every
 * prop by identity, so an accessor's identity must change only when the view
 * state changes; the cache gives exactly one stable pair of functions per
 * (relation mask, render budget, overlay, drill-down, families instance).
 *
 * The links table holds the exact links first and, for worlds with families,
 * one appended row per rendered (cross-family) family edge. Behaviour:
 *
 * - Structure overlay (and every world without families): exactly as before —
 *   enabled exact links drawn, family rows (if any) fully transparent, zero
 *   width. A world without families has no family rows at all.
 * - Families overlay: exact links hide; family edges draw in their relation
 *   colour with width growing in log2 of the multiplicity (the aggregate's
 *   weight is visible, the exact clutter is gone).
 * - Drill-down (a clicked family edge): the drilled edge stays drawn and its
 *   contributing exact links reappear at normal width; everything else hides.
 *
 * When the dataset exceeds the link render budget (`renderLinks` false, see
 * `datasets.ts`), exact links stay hidden as before; family edges are few (one
 * per family pair) and keep drawing in the families overlay.
 */
import type { WorldFamilies } from "../../projection/src/families.ts";
import { isRelationEnabled, type RelationMask } from "./selection.ts";
import { isRelationName, relationColor, type OverlayName } from "./vocabulary.ts";

export type LinkColor = string | [number, number, number, number];
export type LinkColorFn = (value: string, index?: number) => LinkColor;
export type LinkWidthFn = (value: string, index?: number) => number;

/** Fully transparent; the link stays in the graph but paints nothing. */
const HIDDEN: [number, number, number, number] = [0, 0, 0, 0];
/** The renderer's default link width, used for every enabled exact link. */
const VISIBLE_WIDTH = 1;
/** The widest a family edge is drawn (multiplicity is log-scaled). */
const MAX_FAMILY_WIDTH = 8;
/** How much wider the drilled family edge draws than its normal width. */
const DRILL_WIDTH_FACTOR = 1.6;

/** Everything the link accessors read: pure view state plus the session's families. */
export interface LinkViewOptions {
  readonly mask: RelationMask;
  readonly renderLinks: boolean;
  readonly overlay: OverlayName;
  readonly families: WorldFamilies | null;
  /** The exact link count; rows at or beyond it are family edges. */
  readonly exactLinkCount: number;
  /** The drilled family edge ordinal, or null. */
  readonly drill: number | null;
}

function enabled(value: string, mask: RelationMask): boolean {
  return !isRelationName(value) || isRelationEnabled(mask, value);
}

/** Rendered width of a family edge: 1 + log2(1 + multiplicity), capped. */
export function familyEdgeWidth(multiplicity: number): number {
  return Math.min(1 + Math.log2(1 + Math.max(0, multiplicity)), MAX_FAMILY_WIDTH);
}

interface Accessors {
  readonly color: LinkColorFn;
  readonly width: LinkWidthFn;
}

function buildAccessors(options: LinkViewOptions): Accessors {
  const { mask, renderLinks, overlay, families, exactLinkCount, drill } = options;
  const drillLinks = new Set<number>();
  if (families !== null && drill !== null) {
    for (const link of families.edgeContributionLinks.get(drill) ?? []) drillLinks.add(link);
  }
  /** The family edge ordinal of an appended row, or null for an exact link. */
  const familyEdgeAt = (index: number): number | null => {
    if (families === null || index < exactLinkCount) return null;
    return families.renderedEdges[index - exactLinkCount] ?? null;
  };

  const color: LinkColorFn = (value, index = -1) => {
    const edge = familyEdgeAt(index);
    if (edge !== null) {
      // A family edge row.
      if (overlay !== "families") return HIDDEN;
      if (drill !== null) return edge === drill ? relationColor(value) : HIDDEN;
      return enabled(value, mask) ? relationColor(value) : HIDDEN;
    }
    // An exact link row.
    if (overlay === "families") {
      return drill !== null && drillLinks.has(index) ? relationColor(value) : HIDDEN;
    }
    if (!renderLinks || !enabled(value, mask)) return HIDDEN;
    return relationColor(value);
  };
  const width: LinkWidthFn = (value, index = -1) => {
    const edge = familyEdgeAt(index);
    if (edge !== null) {
      if (overlay !== "families") return 0;
      const multiplicity = families?.edges[edge]?.multiplicity ?? 1;
      if (drill !== null) return edge === drill ? familyEdgeWidth(multiplicity) * DRILL_WIDTH_FACTOR : 0;
      return enabled(value, mask) ? familyEdgeWidth(multiplicity) : 0;
    }
    if (overlay === "families") {
      return drill !== null && drillLinks.has(index) ? VISIBLE_WIDTH : 0;
    }
    if (!renderLinks || !enabled(value, mask)) return 0;
    return VISIBLE_WIDTH;
  };
  return { color, width };
}

type CacheKey = `${RelationMask}:${0 | 1}:${OverlayName}:${number}`;

function cacheKey(options: LinkViewOptions): CacheKey {
  return `${options.mask}:${options.renderLinks ? 1 : 0}:${options.overlay}:${options.drill ?? -1}`;
}

const plainCache = new Map<CacheKey, Accessors>();
const familiesCache = new WeakMap<WorldFamilies, Map<CacheKey, Accessors>>();

function cachedAccessors(options: LinkViewOptions): Accessors {
  const key = cacheKey(options);
  const { families } = options;
  let cache: Map<CacheKey, Accessors>;
  if (families === null) {
    cache = plainCache;
  } else {
    const existing = familiesCache.get(families);
    if (existing !== undefined) {
      cache = existing;
    } else {
      cache = new Map<CacheKey, Accessors>();
      familiesCache.set(families, cache);
    }
  }
  const existing = cache.get(key);
  if (existing !== undefined) return existing;
  const built = buildAccessors(options);
  cache.set(key, built);
  return built;
}

/** The stable link colour accessor for this exact view state. */
export function linkColorAccessor(options: LinkViewOptions): LinkColorFn {
  return cachedAccessors(options).color;
}

/** The stable link width accessor for this exact view state. */
export function linkWidthAccessor(options: LinkViewOptions): LinkWidthFn {
  return cachedAccessors(options).width;
}

/** Structure-overlay colour accessor without a families layer (the pre-families behaviour). */
export function linkColorFn(mask: RelationMask, renderLinks = true): LinkColorFn {
  return linkColorAccessor({
    mask,
    renderLinks,
    overlay: "structure",
    families: null,
    exactLinkCount: Number.MAX_SAFE_INTEGER,
    drill: null,
  });
}

/** Structure-overlay width accessor without a families layer (the pre-families behaviour). */
export function linkWidthFn(mask: RelationMask, renderLinks = true): LinkWidthFn {
  return linkWidthAccessor({
    mask,
    renderLinks,
    overlay: "structure",
    families: null,
    exactLinkCount: Number.MAX_SAFE_INTEGER,
    drill: null,
  });
}
