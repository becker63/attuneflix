/**
 * Rectangle geometry for the structural layout: shelf packing of nested
 * rectangles, row-major grids, and rectangle predicates. Everything is
 * `+ - * /`, `Math.sqrt` and `Math.ceil`, which IEEE 754 rounds identically on
 * every engine, so identical inputs give bit-identical rectangles.
 */

export interface Rect {
  readonly x0: number;
  readonly y0: number;
  readonly x1: number;
  readonly y1: number;
}

export interface Size {
  readonly w: number;
  readonly h: number;
}

export interface Packing {
  /** The packed rectangle, including `pad` on every side. */
  readonly size: Size;
  /** Top-left offset of each item within the packed rectangle, in input order. */
  readonly offsets: readonly (readonly [number, number])[];
}

export interface Grid {
  readonly rect: Rect;
  readonly cols: number;
  readonly rows: number;
}

export function width(rect: Rect): number {
  return rect.x1 - rect.x0;
}

export function height(rect: Rect): number {
  return rect.y1 - rect.y0;
}

export function centerOf(rect: Rect): readonly [number, number] {
  return [(rect.x0 + rect.x1) / 2, (rect.y0 + rect.y1) / 2];
}

/** Moves `amount` inward on every side (outward when negative). */
export function inset(rect: Rect, amount: number): Rect {
  return { x0: rect.x0 + amount, y0: rect.y0 + amount, x1: rect.x1 - amount, y1: rect.y1 - amount };
}

/** Whether `inner` lies within `outer`, allowing `epsilon` of rounding slack. */
export function containsRect(outer: Rect, inner: Rect, epsilon = 0): boolean {
  return (
    inner.x0 >= outer.x0 - epsilon &&
    inner.y0 >= outer.y0 - epsilon &&
    inner.x1 <= outer.x1 + epsilon &&
    inner.y1 <= outer.y1 + epsilon
  );
}

export function containsPoint(rect: Rect, x: number, y: number, epsilon = 0): boolean {
  return x >= rect.x0 - epsilon && x <= rect.x1 + epsilon && y >= rect.y0 - epsilon && y <= rect.y1 + epsilon;
}

/** Whether two rectangles share no interior point. */
export function disjoint(a: Rect, b: Rect): boolean {
  return a.x1 <= b.x0 || b.x1 <= a.x0 || a.y1 <= b.y0 || b.y1 <= a.y0;
}

/**
 * Next-fit shelf packing: items go left to right, `gap` apart, onto shelves no
 * wider than the square root of the total gapped area (or the widest item);
 * a new shelf starts `gap` below the tallest item of the previous one. With the
 * items sorted by decreasing height this is the classic NFDH packing, which
 * keeps the result near-square. Items never overlap and stay `gap` apart.
 */
export function packShelves(items: readonly Size[], gap: number, pad: number): Packing {
  let area = 0;
  let widest = 0;
  for (const item of items) {
    area += (item.w + gap) * (item.h + gap);
    widest = Math.max(widest, item.w);
  }
  const limit = Math.max(widest, Math.sqrt(area));
  const offsets: [number, number][] = [];
  let x = 0;
  let y = 0;
  let shelf = 0;
  let contentWidth = 0;
  for (const item of items) {
    if (x > 0 && x + item.w > limit) {
      y += shelf + gap;
      x = 0;
      shelf = 0;
    }
    offsets.push([pad + x, pad + y]);
    contentWidth = Math.max(contentWidth, x + item.w);
    x += item.w + gap;
    shelf = Math.max(shelf, item.h);
  }
  return { size: { w: contentWidth + 2 * pad, h: y + shelf + 2 * pad }, offsets };
}

/** The near-square row-major grid with at least `count` cells that fills `rect`. */
export function grid(count: number, rect: Rect): Grid {
  const n = Math.max(1, count);
  const w = width(rect);
  const h = height(rect);
  const ideal = h > 0 ? Math.ceil(Math.sqrt((n * w) / h)) : n;
  const cols = Math.min(n, Math.max(1, ideal));
  return { rect, cols, rows: Math.ceil(n / cols) };
}

/** The k-th cell of a grid, row-major from the top-left. */
export function gridCell(g: Grid, k: number): Rect {
  const col = k % g.cols;
  const row = (k - col) / g.cols;
  const cw = width(g.rect) / g.cols;
  const ch = height(g.rect) / g.rows;
  const x0 = g.rect.x0 + col * cw;
  const y0 = g.rect.y0 + row * ch;
  return {
    x0,
    y0,
    x1: col === g.cols - 1 ? g.rect.x1 : x0 + cw,
    y1: row === g.rows - 1 ? g.rect.y1 : y0 + ch,
  };
}

/** The index of the grid cell centred on the grid's centre, or -1 if none is. */
export function centreCell(g: Grid): number {
  if (g.cols % 2 === 0 || g.rows % 2 === 0) return -1;
  return ((g.rows - 1) / 2) * g.cols + (g.cols - 1) / 2;
}
