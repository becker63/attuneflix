/**
 * Deterministic initial point layout. Positions are a view concern, never
 * evidence: the projection does not compute them and the app never infers facts
 * from them.
 *
 * Points are placed in one band per domain (file, symbol, directory). Within a
 * band, the k-th point sits on a golden-angle spiral, which spreads points
 * without overlap and is fully deterministic (same graph -> identical layout).
 * The graph then renders with `enableSimulation: false`, so a dataset change is a
 * pure data swap with no layout recomputation.
 */
import type { ViewerGraph } from "../../projection/src/graph.ts";

const GOLDEN_ANGLE = Math.PI * (3 - Math.sqrt(5));
const BAND_RADIUS = 320;
const BAND_SPACING = 420;
const BAND_COUNT = 3;

/** Interleaved [x0, y0, x1, y1, ...], one pair per point, in renderer index order. */
export function computeLayout(graph: ViewerGraph): Float32Array {
  const xy = new Float32Array(graph.pointCount * 2);
  const totals = new Uint32Array(BAND_COUNT);
  for (const domainRank of graph.pointDomains) {
    if (domainRank < BAND_COUNT) totals[domainRank] = (totals[domainRank] ?? 0) + 1;
  }
  const seen = new Uint32Array(BAND_COUNT);
  for (let index = 0; index < graph.pointCount; index++) {
    const band = graph.pointDomains[index] ?? 0;
    const total = totals[band] ?? 1;
    const k = seen[band] ?? 0;
    seen[band] = k + 1;
    const radius = Math.sqrt((k + 0.5) / Math.max(total, 1)) * BAND_RADIUS;
    const angle = k * GOLDEN_ANGLE;
    const centerX = (band - (BAND_COUNT - 1) / 2) * BAND_SPACING;
    xy[index * 2] = centerX + radius * Math.cos(angle);
    xy[index * 2 + 1] = radius * Math.sin(angle);
  }
  return xy;
}
