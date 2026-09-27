/**
 * Stable per-filter link accessors for the renderer. Cosmograph compares every
 * prop by identity, so an accessor's identity must change only when the filter
 * changes; the cache gives exactly one stable pair of functions per relation
 * mask. A disabled relation's link is drawn fully transparent (alpha 0) and with
 * width 0, so the topology is untouched: the same points and links stay loaded.
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

const colorFns = new Map<RelationMask, LinkColorFn>();
const widthFns = new Map<RelationMask, LinkWidthFn>();

function isHidden(value: string, mask: RelationMask): boolean {
  return isRelationName(value) && !isRelationEnabled(mask, value);
}

export function linkColorFn(mask: RelationMask): LinkColorFn {
  const existing = colorFns.get(mask);
  if (existing !== undefined) return existing;
  const fn: LinkColorFn = (value) => (isHidden(value, mask) ? HIDDEN : relationColor(value));
  colorFns.set(mask, fn);
  return fn;
}

export function linkWidthFn(mask: RelationMask): LinkWidthFn {
  const existing = widthFns.get(mask);
  if (existing !== undefined) return existing;
  const fn: LinkWidthFn = (value) => (isHidden(value, mask) ? 0 : VISIBLE_WIDTH);
  widthFns.set(mask, fn);
  return fn;
}
