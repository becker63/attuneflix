/**
 * Arrow-table view of a ViewerGraph, used by the app's GraphSession to feed
 * Cosmograph through DuckDB. Both tables carry an `index` column equal to the
 * row position (the renderer index), and the links table carries the resolved
 * `sourceIndex` / `targetIndex` columns alongside the typed endpoints.
 */
import { Int32, Table, Utf8, makeVector, vectorFromArray } from "apache-arrow";

import { DOMAIN_ORDER, type Domain } from "./domain.ts";
import type { ViewerGraph } from "./graph.ts";
import { RELATION_ORDER, type Relation } from "./relation.ts";

export interface ViewerArrowTables {
  readonly points: Table;
  readonly links: Table;
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

export function buildViewerArrow(graph: ViewerGraph): ViewerArrowTables {
  const points = new Table({
    index: makeVector(indexColumn(graph.pointCount)),
    id: vectorFromArray([...graph.pointIds], new Utf8()),
    domain: vectorFromArray(Array.from(graph.pointDomains, domainName), new Utf8()),
    entityId: makeVector(graph.pointEntityIds),
    label: vectorFromArray([...graph.pointLabels], new Utf8()),
    path: vectorFromArray(graph.pointPaths, new Utf8()),
    name: vectorFromArray(graph.pointNames, new Utf8()),
    startByte: vectorFromArray(nullableInt32(graph.pointStartBytes), new Int32()),
    endByte: vectorFromArray(nullableInt32(graph.pointEndBytes), new Int32()),
  });
  const links = new Table({
    index: makeVector(indexColumn(graph.linkCount)),
    relation: vectorFromArray(Array.from(graph.linkRelations, relationName), new Utf8()),
    row: makeVector(graph.linkRows),
    sourceDomain: vectorFromArray(Array.from(graph.linkSourceDomains, domainName), new Utf8()),
    sourceId: makeVector(graph.linkSourceIds),
    targetDomain: vectorFromArray(Array.from(graph.linkTargetDomains, domainName), new Utf8()),
    targetId: makeVector(graph.linkTargetIds),
    sourceIndex: makeVector(graph.linkSourceIndices),
    targetIndex: makeVector(graph.linkTargetIndices),
  });
  return { points, links };
}
