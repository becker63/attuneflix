/** Renderer table for the current view. The admitted ViewerGraph stays intact. */
import { Table, Utf8, makeVector, vectorFromArray } from "apache-arrow";

import { DOMAIN_ORDER } from "../../../projection/src/domain.ts";
import type { ViewerGraph } from "../../../projection/src/graph.ts";
import type { FrontierProjection } from "./wires.ts";

export function projectedLinksArrow(graph: ViewerGraph, projection: FrontierProjection): Table {
  const { wires } = projection;
  return new Table({
    index: makeVector(Uint32Array.from(wires, (_wire, index) => index)),
    relation: vectorFromArray(wires.map((wire) => wire.relation), new Utf8()),
    row: makeVector(Int32Array.from(wires, () => -1)),
    source: vectorFromArray(wires.map((wire) => wire.source), new Utf8()),
    target: vectorFromArray(wires.map((wire) => wire.target), new Utf8()),
    sourceDomain: vectorFromArray(
      wires.map((wire) => DOMAIN_ORDER[graph.pointDomains[wire.sourceIndex] ?? -1] ?? ""),
      new Utf8(),
    ),
    sourceId: makeVector(Int32Array.from(wires, (wire) => graph.pointEntityIds[wire.sourceIndex] ?? -1)),
    targetDomain: vectorFromArray(
      wires.map((wire) => DOMAIN_ORDER[graph.pointDomains[wire.targetIndex] ?? -1] ?? ""),
      new Utf8(),
    ),
    targetId: makeVector(Int32Array.from(wires, (wire) => graph.pointEntityIds[wire.targetIndex] ?? -1)),
    sourceIndex: makeVector(Uint32Array.from(wires, (wire) => wire.sourceIndex)),
    targetIndex: makeVector(Uint32Array.from(wires, (wire) => wire.targetIndex)),
    multiplicity: makeVector(Uint32Array.from(wires, (wire) => wire.multiplicity)),
  });
}
