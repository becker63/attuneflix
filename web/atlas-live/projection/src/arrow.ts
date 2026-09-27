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

export function buildViewerArrow(graph: ViewerGraph, layout?: PointLayout): ViewerArrowTables {
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
  const sourceIds = Array.from(graph.linkSourceIndices, (index) => graph.pointIds[index] ?? "");
  const targetIds = Array.from(graph.linkTargetIndices, (index) => graph.pointIds[index] ?? "");
  const links = new Table({
    index: makeVector(indexColumn(graph.linkCount)),
    relation: vectorFromArray(Array.from(graph.linkRelations, relationName), new Utf8()),
    row: makeVector(graph.linkRows),
    source: vectorFromArray(sourceIds, new Utf8()),
    target: vectorFromArray(targetIds, new Utf8()),
    sourceDomain: vectorFromArray(Array.from(graph.linkSourceDomains, domainName), new Utf8()),
    sourceId: makeVector(graph.linkSourceIds),
    targetDomain: vectorFromArray(Array.from(graph.linkTargetDomains, domainName), new Utf8()),
    targetId: makeVector(graph.linkTargetIds),
    sourceIndex: makeVector(graph.linkSourceIndices),
    targetIndex: makeVector(graph.linkTargetIndices),
  });
  return { points, links };
}
