/** Directed projected-wire paths entering a selected visible anchor. */
import type { StructuralDepth } from "./parallelism.ts";
import type { FrontierProjection } from "./wires.ts";

export interface AnchorTrace {
  readonly anchorId: string;
  readonly incomingIds: ReadonlySet<string>;
  readonly wireIndices: ReadonlySet<number>;
  readonly directSources: ReadonlySet<string>;
  readonly directBackingEdges: number;
}

/**
 * Shortest incoming dependency paths through depth 1–3. The projection holds
 * imports/calls only; containment and defines never enter this trace.
 */
export function incomingAnchorTrace(
  projection: FrontierProjection,
  anchorId: string,
  depth: StructuralDepth,
): AnchorTrace {
  if (!projection.nodes.some((node) => node.id === anchorId)) {
    return {
      anchorId,
      incomingIds: new Set(),
      wireIndices: new Set(),
      directSources: new Set(),
      directBackingEdges: 0,
    };
  }
  const distances = new Map<string, number>([[anchorId, 0]]);
  const directSources = new Set<string>();
  let directBackingEdges = 0;
  for (const wire of projection.wires) {
    if (wire.target === anchorId) {
      directSources.add(wire.source);
      directBackingEdges += wire.multiplicity;
    }
  }
  for (let step = 1; step <= depth; step++) {
    for (const wire of projection.wires) {
      if (distances.get(wire.target) === step - 1 && !distances.has(wire.source)) {
        distances.set(wire.source, step);
      }
    }
  }
  const incomingIds = new Set([...distances.keys()].filter((id) => id !== anchorId));
  const wireIndices = new Set<number>();
  projection.wires.forEach((wire, index) => {
    const source = distances.get(wire.source);
    const target = distances.get(wire.target);
    if (source !== undefined && target !== undefined && source === target + 1 && source <= depth) {
      wireIndices.add(index);
    }
  });
  return { anchorId, incomingIds, wireIndices, directSources, directBackingEdges };
}
