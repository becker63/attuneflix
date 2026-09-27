/**
 * Stable per-filter link accessors for the renderer. Cosmograph compares every
 * prop by identity, so an accessor's identity must change only when the filter
 * changes; the cache gives exactly one stable pair of functions per relation
 * mask. A disabled relation's link is drawn fully transparent (alpha 0) and with
 * width 0, so the topology is untouched: the same points and links stay loaded.
 *
 * When the dataset exceeds the link render budget (`renderLinks` false, see
 * `datasets.ts`), every link is drawn the same fully transparent, zero-width
 * way regardless of relation. That is the SwiftShader choice for the largest
 * worlds and the synthetic stress fixture: the links stay loaded and queryable
 * (the details panel still counts them, the relation filter still governs the
 * neighbourhood), but a hover redraw never pays the multi-second link geometry
 * pass.
 */
import { isRelationEnabled, type RelationMask } from "./selection.ts";
import { isRelationName, relationColor } from "./vocabulary.ts";

export type LinkColor = string | [number, number, number, number];
export type LinkColorFn = (value: string, index?: number) => LinkColor;
export type LinkWidthFn = (value: string, index?: number) => number;

/** Fully transparent; the link stays in the graph but paints nothing. */
const HIDDEN: [number, number, number, number] = [0, 0, 0, 0];
/** The renderer's default link width, used for every enabled link. */
const VISIBLE_WIDTH = 1;

type CacheKey = `${RelationMask}:${0 | 1}`;

function cacheKey(mask: RelationMask, renderLinks: boolean): CacheKey {
  return `${mask}:${renderLinks ? 1 : 0}`;
}

const colorFns = new Map<CacheKey, LinkColorFn>();
const widthFns = new Map<CacheKey, LinkWidthFn>();

function isHidden(value: string, mask: RelationMask, renderLinks: boolean): boolean {
  if (!renderLinks) return true;
  return isRelationName(value) && !isRelationEnabled(mask, value);
}

export function linkColorFn(mask: RelationMask, renderLinks = true): LinkColorFn {
  const key = cacheKey(mask, renderLinks);
  const existing = colorFns.get(key);
  if (existing !== undefined) return existing;
  const fn: LinkColorFn = (value) => (isHidden(value, mask, renderLinks) ? HIDDEN : relationColor(value));
  colorFns.set(key, fn);
  return fn;
}

export function linkWidthFn(mask: RelationMask, renderLinks = true): LinkWidthFn {
  const key = cacheKey(mask, renderLinks);
  const existing = widthFns.get(key);
  if (existing !== undefined) return existing;
  const fn: LinkWidthFn = (value) => (isHidden(value, mask, renderLinks) ? 0 : VISIBLE_WIDTH);
  widthFns.set(key, fn);
  return fn;
}
