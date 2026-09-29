/**
 * Arrow-table view of a ViewerGraph, used by the app's GraphSession to feed
 * Cosmograph through DuckDB. Both tables carry an `index` column equal to the
 * row position (the renderer index); the links table also carries the namespaced
 * `source` / `target` point ids (required by the renderer's validator) alongside
 * the resolved `sourceIndex` / `targetIndex` columns and the typed endpoints.
 *
 * Point x/y coordinates are a view concern, not evidence: when a caller supplies
 * a layout the points table gains `x` / `y` columns; without one the renderer is
 * expected to compute its own positions.
 */
import { Int32, Table, Utf8, makeVector, vectorFromArray } from "apache-arrow";

import { DOMAIN_ORDER, type Domain } from "./domain.ts";
import type { WorldFamilies } from "./families.ts";
import type { ViewerGraph } from "./graph.ts";
import { RELATION_ORDER, type Relation } from "./relation.ts";

export interface ViewerArrowTables {
  readonly points: Table;
  readonly links: Table;
}

/** Interleaved [x0, y0, x1, y1, ...] point coordinates, one pair per point. */
export interface PointLayout {
  readonly xy: Float32Array;
}

/** Options for the Arrow build: point coordinates and the families layer. */
export interface ViewerArrowOptions {
  readonly xy?: Float32Array;
  /**
   * The world's families layer. When present, the links table gains one row per
   * rendered (cross-family) family edge, appended after the exact links: the row
   * connects the two families' seed-file anchors, carries the edge's relation
   * and typed anchor endpoints, and has `row` -1 (no exact relations row). The
   * exact prefix is byte-identical to the no-families build.
   */
  readonly families?: WorldFamilies;
}

function domainName(rank: number): Domain {
  const domain = DOMAIN_ORDER[rank];
  if (domain === undefined) throw new Error(`invalid domain rank: ${rank}`);
  return domain;
}

function relationName(rank: number): Relation {
  const relation = RELATION_ORDER[rank];
  if (relation === undefined) throw new Error(`invalid relation rank: ${rank}`);
  return relation;
}

function indexColumn(length: number): Uint32Array {
  const index = new Uint32Array(length);
  for (let i = 0; i < length; i++) index[i] = i;
  return index;
}

/** -1 sentinel to null, for the nullable symbol byte-span columns. */
function nullableInt32(values: Int32Array): (number | null)[] {
  return Array.from(values, (value) => (value < 0 ? null : value));
}

/** Splits interleaved x/y into two Float32 columns. */
function coordinateColumns(layout: PointLayout): { x: Float32Array; y: Float32Array } {
  const x = new Float32Array(layout.xy.length / 2);
  const y = new Float32Array(layout.xy.length / 2);
  for (let i = 0; i < x.length; i++) {
    x[i] = layout.xy[i * 2] ?? 0;
    y[i] = layout.xy[i * 2 + 1] ?? 0;
  }
  return { x, y };
}

export function buildViewerArrow(graph: ViewerGraph, options?: ViewerArrowOptions): ViewerArrowTables {
  const layout: PointLayout | undefined = options?.xy === undefined ? undefined : { xy: options.xy };
  const families = options?.families;
  const base = {
    index: makeVector(indexColumn(graph.pointCount)),
    id: vectorFromArray([...graph.pointIds], new Utf8()),
    domain: vectorFromArray(Array.from(graph.pointDomains, domainName), new Utf8()),
    entityId: makeVector(graph.pointEntityIds),
    label: vectorFromArray([...graph.pointLabels], new Utf8()),
    path: vectorFromArray(graph.pointPaths, new Utf8()),
    name: vectorFromArray(graph.pointNames, new Utf8()),
    startByte: vectorFromArray(nullableInt32(graph.pointStartBytes), new Int32()),
    endByte: vectorFromArray(nullableInt32(graph.pointEndBytes), new Int32()),
  };
  const coordinates =
    layout === undefined
      ? {}
      : (() => {
          const { x, y } = coordinateColumns(layout);
          return { x: makeVector(x), y: makeVector(y) };
        })();
  const points = new Table({ ...base, ...coordinates });
  // Family edges append after the exact links; each connects the two families'
  // seed-file anchors and carries `row` -1 (it aggregates many exact rows).
  const rendered = families?.renderedEdges ?? [];
  const linkCount = graph.linkCount + rendered.length;
  const linkIndex = indexColumn(linkCount);
  const linkRelation: string[] = Array.from(graph.linkRelations, relationName);
  const linkRow = Array.from(graph.linkRows);
  const sourceIds: string[] = Array.from(graph.linkSourceIndices, (index) => graph.pointIds[index] ?? "");
  const targetIds: string[] = Array.from(graph.linkTargetIndices, (index) => graph.pointIds[index] ?? "");
  const sourceDomains: string[] = Array.from(graph.linkSourceDomains, domainName);
  const sourceIdsExact = Array.from(graph.linkSourceIds);
  const targetDomains: string[] = Array.from(graph.linkTargetDomains, domainName);
  const targetIdsExact = Array.from(graph.linkTargetIds);
  const sourceIndices = Array.from(graph.linkSourceIndices);
  const targetIndices = Array.from(graph.linkTargetIndices);
  if (families !== undefined) {
    for (const ordinal of rendered) {
      const edge = families.edges[ordinal];
      if (edge === undefined) throw new Error(`family edge index out of range: ${ordinal}`);
      const sourceFamily = families.families[edge.sourceFamily];
      const targetFamily = families.families[edge.targetFamily];
      if (sourceFamily === undefined || targetFamily === undefined) {
        throw new Error(`family edge ${ordinal} names an unknown family`);
      }
      linkRelation.push(edge.relation);
      linkRow.push(-1);
      sourceIds.push(graph.pointIds[edge.sourceAnchor] ?? "");
      targetIds.push(graph.pointIds[edge.targetAnchor] ?? "");
      sourceDomains.push("file");
      sourceIdsExact.push(sourceFamily.seedFile);
      targetDomains.push("file");
      targetIdsExact.push(targetFamily.seedFile);
      sourceIndices.push(edge.sourceAnchor);
      targetIndices.push(edge.targetAnchor);
    }
  }
  const links = new Table({
    index: makeVector(linkIndex),
    relation: vectorFromArray(linkRelation, new Utf8()),
    row: makeVector(Int32Array.from(linkRow)),
    source: vectorFromArray(sourceIds, new Utf8()),
    target: vectorFromArray(targetIds, new Utf8()),
    sourceDomain: vectorFromArray(sourceDomains, new Utf8()),
    sourceId: makeVector(Int32Array.from(sourceIdsExact)),
    targetDomain: vectorFromArray(targetDomains, new Utf8()),
    targetId: makeVector(Int32Array.from(targetIdsExact)),
    sourceIndex: makeVector(Uint32Array.from(sourceIndices)),
    targetIndex: makeVector(Uint32Array.from(targetIndices)),
  });
  return { points, links };
}
