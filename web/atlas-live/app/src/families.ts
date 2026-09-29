/**
 * The families view model: pure view logic over the projected WorldFamilies
 * (the science lives in the shipped tables; this module only presents it).
 * Family tints come from the visual vocabulary (one owner); the family-edge
 * listing and the drill-down resolution live here so the sidebar, the canvas
 * handlers and the diagnostics hook all read the same model.
 *
 * Bounded representation: the edge list and the drill-down's contributing exact
 * edges are capped (`TOP_FAMILY_EDGE_LIMIT`, `CONTRIBUTION_LINE_LIMIT`); the
 * remainder is reported as a count, never truncated silently.
 */
import {
  familyOfPoint,
  type FamilyEdge,
  type WorldFamilies,
  type WorldFamily,
} from "../../projection/src/families.ts";
import type { ViewerGraph } from "../../projection/src/graph.ts";
import { linkRelation } from "../../projection/src/graph.ts";
import type { Relation } from "../../projection/src/relation.ts";
import type { AtlasFamilyMembership } from "./diagnostics.ts";
import { NO_FAMILY_COLOR, familyColor } from "./vocabulary.ts";

/** How many family edges the sidebar lists (the rest are aggregated in the heading count). */
export const TOP_FAMILY_EDGE_LIMIT = 25;

/** How many contributing exact edges a drill-down lists (the rest read "+N more"). */
export const CONTRIBUTION_LINE_LIMIT = 25;

/** The tint of one point in the families overlay: its family colour, or the neutral no-family tint. */
export function familyTint(families: WorldFamilies, index: number): string {
  const ordinal = familyOfPoint(families, index);
  return ordinal < 0 ? NO_FAMILY_COLOR : familyColor(ordinal);
}

const tintAccessors = new WeakMap<WorldFamilies, (value: unknown, index?: number) => string>();

/**
 * The renderer's `pointColorByFn` for the families overlay, referentially
 * stable per WorldFamilies (Cosmograph diffs props by identity).
 */
export function familyPointColor(families: WorldFamilies): (value: unknown, index?: number) => string {
  const cached = tintAccessors.get(families);
  if (cached !== undefined) return cached;
  const fn = (_value: unknown, index?: number): string => familyTint(families, index ?? -1);
  tintAccessors.set(families, fn);
  return fn;
}

/**
 * The membership the inspector and the diagnostics hook show for one point,
 * with the honesty markers (F3): a fallback member joined its defining file's
 * seed family (no recorded frontier held it); a singleton family has exactly
 * one member. Files and directories carry their dominant rollup family and are
 * never fallback members.
 */
export function familyMembership(families: WorldFamilies, index: number): AtlasFamilyMembership | null {
  const ordinal = familyOfPoint(families, index);
  if (ordinal < 0) return null;
  const family = families.families[ordinal];
  if (family === undefined) return null;
  const symbolOrdinal = index - families.fileCount;
  const fallback =
    index >= families.fileCount && index < families.fileCount + families.symbolCount
      ? (families.memberFallback[symbolOrdinal] ?? 0) === 1
      : false;
  return {
    ordinal,
    familyId: family.familyId,
    name: family.name,
    members: family.members,
    singleton: family.singleton,
    fallback,
  };
}

/** The strongest rendered (cross-family) edges first; ties keep table order. */
export function topFamilyEdges(families: WorldFamilies, limit: number): FamilyEdge[] {
  const edges: FamilyEdge[] = [];
  for (const ordinal of families.renderedEdges) {
    const edge = families.edges[ordinal];
    if (edge !== undefined) edges.push(edge);
  }
  edges.sort((a, b) => b.multiplicity - a.multiplicity || a.edge - b.edge);
  return edges.slice(0, Math.max(0, limit));
}

/** A drilled family edge: the edge, both endpoint families, and its contributing exact links. */
export interface FamilyDrill {
  readonly edge: FamilyEdge;
  readonly source: WorldFamily;
  readonly target: WorldFamily;
  /** Exact link indices of the contributing world edges (bounded by multiplicity). */
  readonly links: readonly number[];
}

/** Resolves a family edge ordinal to its drill-down, or null when unknown. */
export function drillFamilyEdge(families: WorldFamilies, ordinal: number): FamilyDrill | null {
  const edge = families.edges[ordinal];
  if (edge === undefined) return null;
  const source = families.families[edge.sourceFamily];
  const target = families.families[edge.targetFamily];
  if (source === undefined || target === undefined) return null;
  return { edge, source, target, links: families.edgeContributionLinks.get(ordinal) ?? [] };
}

/** One human-readable line of a drill-down: an exact contributing edge. */
export interface ContributionLine {
  readonly link: number;
  readonly relation: Relation;
  /** Point labels of the two endpoints. */
  readonly source: string;
  readonly target: string;
  /** Namespaced point ids (`domain:entity_id`) of the two endpoints. */
  readonly sourceId: string;
  readonly targetId: string;
}

/** The first `limit` contributing edges as labelled lines, plus the remaining count. */
export function contributionLines(
  graph: ViewerGraph,
  links: readonly number[],
  limit: number,
): { lines: ContributionLine[]; remaining: number } {
  const shown = links.slice(0, Math.max(0, limit));
  const lines: ContributionLine[] = [];
  for (const link of shown) {
    const sourceIndex = graph.linkSourceIndices[link];
    const targetIndex = graph.linkTargetIndices[link];
    if (sourceIndex === undefined || targetIndex === undefined) continue;
    lines.push({
      link,
      relation: linkRelation(graph, link),
      source: graph.pointLabels[sourceIndex] ?? "",
      target: graph.pointLabels[targetIndex] ?? "",
      sourceId: graph.pointIds[sourceIndex] ?? "",
      targetId: graph.pointIds[targetIndex] ?? "",
    });
  }
  return { lines, remaining: links.length - lines.length };
}
