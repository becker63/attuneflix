/** Deterministic viewport selection for large projected dependency graphs. */
import { LINK_RENDER_BUDGET } from "./datasets.ts";

export interface ScreenWire {
  readonly sourceIndex: number;
  readonly targetIndex: number;
  readonly multiplicity: number;
}

export interface ScreenPoint {
  readonly x: number;
  readonly y: number;
}

/** Keep the fitted overview quiet; progressively admit more exact wires on zoom. */
export function zoomWireBudget(zoomRatio: number): number {
  if (!Number.isFinite(zoomRatio) || zoomRatio < 1.25) return 0;
  return Math.min(LINK_RENDER_BUDGET, Math.floor(900 * zoomRatio));
}

function inside(point: ScreenPoint, width: number, height: number): boolean {
  return point.x >= 0 && point.x <= width && point.y >= 0 && point.y <= height;
}

/** Liang–Barsky clipping: true when the segment actually enters the viewport. */
function crossesViewport(source: ScreenPoint, target: ScreenPoint, width: number, height: number): boolean {
  const dx = target.x - source.x;
  const dy = target.y - source.y;
  const boundaries: readonly [number, number][] = [
    [-dx, source.x],
    [dx, width - source.x],
    [-dy, source.y],
    [dy, height - source.y],
  ];
  let entry = 0;
  let exit = 1;
  for (const [p, q] of boundaries) {
    if (p === 0) {
      if (q < 0) return false;
      continue;
    }
    const fraction = q / p;
    if (p < 0) entry = Math.max(entry, fraction);
    else exit = Math.min(exit, fraction);
    if (entry > exit) return false;
  }
  return true;
}

/**
 * Select only exact projected wires near the current camera. At a dense zoom,
 * prefer wires attached to on-screen nodes, then higher multiplicity, then
 * canonical wire order. The fixed budget bounds software-WebGL redraw cost.
 */
export function viewportWires(
  wires: readonly ScreenWire[],
  screenOf: (index: number) => ScreenPoint | null,
  width: number,
  height: number,
  budget: number,
): ReadonlySet<number> {
  if (budget <= 0 || width <= 0 || height <= 0) return new Set();
  const pointCache = new Map<number, ScreenPoint | null>();
  const point = (index: number): ScreenPoint | null => {
    if (!pointCache.has(index)) pointCache.set(index, screenOf(index));
    return pointCache.get(index) ?? null;
  };
  const candidates: { index: number; attached: boolean; multiplicity: number }[] = [];
  for (let index = 0; index < wires.length; index++) {
    const wire = wires[index];
    if (wire === undefined) continue;
    const source = point(wire.sourceIndex);
    const target = point(wire.targetIndex);
    if (source === null || target === null) continue;
    const attached = inside(source, width, height) || inside(target, width, height);
    if (!attached && !crossesViewport(source, target, width, height)) continue;
    candidates.push({ index, attached, multiplicity: wire.multiplicity });
  }
  candidates.sort(
    (a, b) =>
      Number(b.attached) - Number(a.attached) ||
      b.multiplicity - a.multiplicity ||
      a.index - b.index,
  );
  return new Set(candidates.slice(0, budget).map(({ index }) => index));
}
