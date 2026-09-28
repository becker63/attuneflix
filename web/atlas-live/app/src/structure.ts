/**
 * The structural repository layout: one deterministic coordinate for every
 * entity of a world (files, symbols, and directory anchors), computed once per
 * world from the repository decomposition alone.
 *
 * Positions are a view concern, never evidence: the projection does not compute
 * them and the app never infers facts from them. Hierarchy determines position;
 * relationships do not. The layout reads only the exact ViewerGraph's structural
 * facts (directory locations and their `parent` edges, file paths, `defines`)
 * and never imports, calls, or any view state (filters, overlays, depth,
 * selection), so no view change can move a point. The renderer runs with
 * `enableSimulation: false`; nothing here is a force simulation.
 *
 * Decomposition:
 * - Directory tree: the `parent` edges between directory locations. The root is
 *   the lowest-ordinal directory without a parent; a directory the root cannot
 *   reach (malformed input) is attached to the root, so the tree is total.
 * - File membership: the file path's containing directory (everything before
 *   the last "/", as `Repository.Location.directory` derives it) matched against
 *   the exported directory paths. A path matching no directory, and every file of
 *   a world without a locations table, belongs to the root. No directory is ever
 *   invented.
 * - Symbol membership: the symbol's `defines` edge from its file; a symbol
 *   without one falls back to the file with the same path, else the root anchor.
 *
 * Coordinates: nested rectangle packing (a treemap-like layout built bottom-up).
 * Every file gets one FILE_CELL x FILE_CELL cell, so a subtree's area grows
 * with its file count. A directory's own files form a near-square block of
 * cells; the block and the child directories' regions are shelf-packed
 * (tallest first, ties by directory ordinal) REGION_GAP apart, and the region
 * is that packing plus half a gap of margin. So each directory owns one
 * contiguous rectangle holding exactly its subtree, and sibling regions are
 * disjoint and exactly one gap apart. A file sits at its cell's centre; its
 * symbols get slots on a sub-grid inside that cell (the centre slot, if any, is
 * left to the file). A directory's anchor is its region's centre. Cell, gap and
 * margin are integers, so almost every coordinate is exact in binary floating
 * point.
 */
import type { ViewerGraph } from "../../projection/src/graph.ts";
import {
  centerOf,
  centreCell,
  grid,
  gridCell,
  height,
  inset,
  packShelves,
  width,
  type Grid,
  type Rect,
  type Size,
} from "./geometry.ts";

export type { Rect };

/** Versions the algorithm; part of every layout identity. */
export const STRUCTURE_VERSION = "structure-v1";

/** Edge length of one file's square cell, in layout units. */
export const FILE_CELL = 10;

/** The gap between sibling regions (and between a region's files and its subdirectories). */
export const REGION_GAP = 4;

/** Margin between a region's edge and its content: half a gap. */
const REGION_MARGIN = REGION_GAP / 2;

/** Fraction of a file cell's shorter side kept clear around its symbol sub-grid. */
const SYMBOL_MARGIN = 0.1;

export interface RepositoryStructure {
  /** Directory ordinal (0 .. directoryCount-1) of the repository root. */
  readonly root: number;
  /** Directory ordinal -> parent directory ordinal; -1 for the root. */
  readonly directoryParent: Int32Array;
  /** File index -> containing directory ordinal. */
  readonly fileDirectory: Int32Array;
  /** Symbol ordinal -> defining file index; -1 when no file defines it. */
  readonly symbolFile: Int32Array;
}

export interface StructuralLayout {
  /** Content hash of the decomposition and the algorithm version. */
  readonly identity: string;
  readonly structure: RepositoryStructure;
  /** Interleaved [x0, y0, x1, y1, ...], one pair per point, in renderer index order. */
  readonly xy: Float32Array;
  /** Directory ordinal -> region rectangle (contains all files of its subtree). */
  readonly directoryRegions: readonly Rect[];
  /** File index -> the file's grid cell (contains its symbol slots). */
  readonly fileCells: readonly Rect[];
}

/** Renderer index of a directory ordinal (directories follow files and symbols). */
export function directoryPointIndex(graph: ViewerGraph, ordinal: number): number {
  return graph.fileCount + graph.symbolCount + ordinal;
}

function containingDirectory(path: string): string {
  const slash = path.lastIndexOf("/");
  return slash < 0 ? "" : path.slice(0, slash);
}

/** Exported directory paths are "src" (Flix) or "src/" (fixtures); compare without the slash. */
function normalizeDirectory(path: string): string {
  return path.endsWith("/") ? path.slice(0, -1) : path;
}

/** Members grouped by owner, in ascending member order; owners of -1 are skipped. */
function groupBy(owners: Int32Array, ownerCount: number): number[][] {
  const groups: number[][] = Array.from({ length: ownerCount }, () => []);
  for (const [member, owner] of owners.entries()) {
    if (owner >= 0) groups[owner]?.push(member);
  }
  return groups;
}

/** Directory ordinals in breadth-first order from the root (parents before children). */
function breadthFirst(root: number, children: readonly (readonly number[])[]): number[] {
  const order = [root];
  for (let head = 0; head < order.length; head++) {
    for (const child of children[order[head] ?? 0] ?? []) order.push(child);
  }
  return order;
}

function directoryTree(graph: ViewerGraph): { root: number; directoryParent: Int32Array } {
  const count = graph.directoryCount;
  const base = directoryPointIndex(graph, 0);
  const out = graph.adjacency.parent.out;
  const directoryParent = new Int32Array(count).fill(-1);
  for (let ordinal = 0; ordinal < count; ordinal++) {
    const start = out.offsets[base + ordinal] ?? 0;
    const end = out.offsets[base + ordinal + 1] ?? 0;
    for (let k = start; k < end; k++) {
      const target = (out.points[k] ?? 0) - base;
      if (target >= 0 && target < count && target !== ordinal) {
        directoryParent[ordinal] = target;
        break;
      }
    }
  }
  const parentless = directoryParent.indexOf(-1);
  const root = parentless < 0 ? 0 : parentless;
  directoryParent[root] = -1;

  // Attach every directory the root cannot reach (a second parentless directory
  // or a parent cycle) to the root, in ordinal order.
  const children = groupBy(directoryParent, count);
  const reached = new Uint8Array(count);
  const visit = (start: number): void => {
    const queue = [start];
    reached[start] = 1;
    for (let head = 0; head < queue.length; head++) {
      for (const child of children[queue[head] ?? 0] ?? []) {
        if (reached[child] === 0) {
          reached[child] = 1;
          queue.push(child);
        }
      }
    }
  };
  visit(root);
  for (let ordinal = 0; ordinal < count; ordinal++) {
    if (reached[ordinal] === 0) {
      directoryParent[ordinal] = root;
      visit(ordinal);
    }
  }
  return { root, directoryParent };
}

/** Derives the repository decomposition (tree, file and symbol membership). */
export function decomposeRepository(graph: ViewerGraph): RepositoryStructure {
  const { fileCount, symbolCount } = graph;
  const { root, directoryParent } = directoryTree(graph);

  const directoryByPath = new Map<string, number>();
  for (let ordinal = 0; ordinal < graph.directoryCount; ordinal++) {
    const path = graph.pointPaths[directoryPointIndex(graph, ordinal)];
    if (path === null || path === undefined) continue;
    const key = normalizeDirectory(path);
    if (!directoryByPath.has(key)) directoryByPath.set(key, ordinal);
  }
  const fileDirectory = new Int32Array(fileCount);
  for (let file = 0; file < fileCount; file++) {
    const path = graph.pointPaths[file];
    const ordinal =
      path === null || path === undefined ? undefined : directoryByPath.get(containingDirectory(path));
    fileDirectory[file] = ordinal ?? root;
  }

  const definesIn = graph.adjacency.defines.in;
  const symbolFile = new Int32Array(symbolCount).fill(-1);
  let fileByPath: Map<string, number> | null = null;
  for (let symbol = 0; symbol < symbolCount; symbol++) {
    const index = fileCount + symbol;
    const start = definesIn.offsets[index] ?? 0;
    const end = definesIn.offsets[index + 1] ?? 0;
    for (let k = start; k < end; k++) {
      const source = definesIn.points[k] ?? fileCount;
      if (source < fileCount) {
        symbolFile[symbol] = source;
        break;
      }
    }
    if (symbolFile[symbol] !== -1) continue;
    if (fileByPath === null) {
      fileByPath = new Map();
      for (let file = fileCount - 1; file >= 0; file--) {
        const path = graph.pointPaths[file];
        if (path !== null && path !== undefined) fileByPath.set(path, file);
      }
    }
    const path = graph.pointPaths[index];
    symbolFile[symbol] = path === null || path === undefined ? -1 : (fileByPath.get(path) ?? -1);
  }
  return { root, directoryParent, fileDirectory, symbolFile };
}

/** Two-lane 32-bit FNV-1a over 32-bit words: a fast synchronous content hash. */
class ContentHash {
  #a = 0x811c9dc5;
  #b = 0x050c5d1f;

  word(value: number): void {
    for (let shift = 0; shift < 32; shift += 8) {
      const byte = (value >>> shift) & 0xff;
      this.#a = Math.imul(this.#a ^ byte, 0x01000193);
      this.#b = Math.imul(this.#b ^ byte, 0x5bd1e995);
    }
  }

  words(values: Int32Array): void {
    this.word(values.length);
    for (const value of values) this.word(value);
  }

  text(value: string): void {
    this.word(value.length);
    for (let i = 0; i < value.length; i++) this.word(value.charCodeAt(i));
  }

  hex(): string {
    return (this.#a >>> 0).toString(16).padStart(8, "0") + (this.#b >>> 0).toString(16).padStart(8, "0");
  }
}

function layoutIdentity(graph: ViewerGraph, structure: RepositoryStructure): string {
  const hash = new ContentHash();
  hash.text(STRUCTURE_VERSION);
  hash.word(graph.fileCount);
  hash.word(graph.symbolCount);
  hash.word(graph.directoryCount);
  hash.word(structure.root);
  hash.words(structure.directoryParent);
  hash.words(structure.fileDirectory);
  hash.words(structure.symbolFile);
  return `${STRUCTURE_VERSION}:${hash.hex()}`;
}

function place(xy: Float32Array, index: number, point: readonly [number, number]): void {
  xy[index * 2] = point[0];
  xy[index * 2 + 1] = point[1];
}

/** Places a file's symbols on a sub-grid of its cell, leaving the centre slot to the file. */
function placeSymbols(xy: Float32Array, fileCount: number, cell: Rect, symbols: readonly number[]): void {
  if (symbols.length === 0) return;
  const inner = inset(cell, SYMBOL_MARGIN * Math.min(width(cell), height(cell)));
  const slots = grid(symbols.length + 1, inner);
  const reserved = centreCell(slots);
  let slot = 0;
  for (const symbol of symbols) {
    if (slot === reserved) slot += 1;
    place(xy, fileCount + symbol, centerOf(gridCell(slots, slot)));
    slot += 1;
  }
}

/** The near-square grid of FILE_CELL cells holding a directory's own files. */
function fileBlock(files: number): { cols: number; rows: number; size: Size } {
  const cols = Math.ceil(Math.sqrt(files));
  const rows = Math.ceil(files / cols);
  return { cols, rows, size: { w: cols * FILE_CELL, h: rows * FILE_CELL } };
}

/** One packed item of a directory: its own-files block (key -1) or a child directory. */
interface Item {
  readonly key: number;
  readonly size: Size;
}

/** Computes the structural layout of a world. Pure; prefer the memoized `structuralLayout`. */
export function computeStructuralLayout(graph: ViewerGraph): StructuralLayout {
  const structure = decomposeRepository(graph);
  const { fileCount, directoryCount } = graph;
  const { root, directoryParent, fileDirectory, symbolFile } = structure;
  const children = groupBy(directoryParent, directoryCount);
  const ownFiles = groupBy(fileDirectory, directoryCount);
  const fileSymbols = groupBy(symbolFile, fileCount);
  const order = breadthFirst(root, children);

  // Bottom-up: pack each directory's block and child regions; children first.
  const sizes: Size[] = Array.from({ length: directoryCount }, () => ({ w: 0, h: 0 }));
  const packed: { items: Item[]; offsets: readonly (readonly [number, number])[] }[] = [];
  for (let i = order.length - 1; i >= 0; i--) {
    const ordinal = order[i] ?? 0;
    const items: Item[] = [];
    const files = ownFiles[ordinal]?.length ?? 0;
    if (files > 0) items.push({ key: -1, size: fileBlock(files).size });
    for (const child of children[ordinal] ?? [])
      items.push({ key: child, size: sizes[child] ?? { w: 0, h: 0 } });
    items.sort((a, b) => b.size.h - a.size.h || b.size.w - a.size.w || a.key - b.key);
    const packing = packShelves(
      items.map((item) => item.size),
      REGION_GAP,
      REGION_MARGIN,
    );
    sizes[ordinal] = packing.size;
    packed[ordinal] = { items, offsets: packing.offsets };
  }

  // Top-down: the root is centred on the origin; every item is placed at its
  // offset inside its parent's region.
  const xy = new Float32Array(graph.pointCount * 2);
  const directoryRegions: (Rect | undefined)[] = [];
  const fileCells: (Rect | undefined)[] = [];
  const rootSize = sizes[root] ?? { w: 0, h: 0 };
  directoryRegions[root] = {
    x0: -rootSize.w / 2,
    y0: -rootSize.h / 2,
    x1: rootSize.w / 2,
    y1: rootSize.h / 2,
  };
  for (const ordinal of order) {
    const region = directoryRegions[ordinal];
    const packing = packed[ordinal];
    if (region === undefined || packing === undefined) continue;
    for (const [k, item] of packing.items.entries()) {
      const [dx, dy] = packing.offsets[k] ?? [0, 0];
      const x0 = region.x0 + dx;
      const y0 = region.y0 + dy;
      const rect = { x0, y0, x1: x0 + item.size.w, y1: y0 + item.size.h };
      if (item.key >= 0) {
        directoryRegions[item.key] = rect;
        continue;
      }
      const files = ownFiles[ordinal] ?? [];
      const block = fileBlock(files.length);
      const cells: Grid = { rect, cols: block.cols, rows: block.rows };
      for (const [n, file] of files.entries()) {
        const cell = gridCell(cells, n);
        fileCells[file] = cell;
        place(xy, file, centerOf(cell));
        placeSymbols(xy, fileCount, cell, fileSymbols[file] ?? []);
      }
    }
  }

  for (let ordinal = 0; ordinal < directoryCount; ordinal++) {
    const region = directoryRegions[ordinal];
    if (region !== undefined) place(xy, directoryPointIndex(graph, ordinal), centerOf(region));
  }
  const rootCentre = centerOf(directoryRegions[root] ?? { x0: 0, y0: 0, x1: 0, y1: 0 });
  for (const [symbol, file] of symbolFile.entries()) {
    if (file < 0) place(xy, fileCount + symbol, rootCentre);
  }

  return {
    identity: layoutIdentity(graph, structure),
    structure,
    xy,
    directoryRegions: complete(directoryRegions, directoryCount, "directory"),
    fileCells: complete(fileCells, fileCount, "file"),
  };
}

/** Every directory is reachable from the root and every file has a directory, so all are placed. */
function complete(rects: readonly (Rect | undefined)[], count: number, what: string): Rect[] {
  const out: Rect[] = [];
  for (let i = 0; i < count; i++) {
    const rect = rects[i];
    if (rect === undefined) throw new Error(`structural layout left ${what} ${i} unplaced`);
    out.push(rect);
  }
  return out;
}

const memo = new WeakMap<ViewerGraph, StructuralLayout>();

/** The structural layout of a world, computed at most once per ViewerGraph. */
export function structuralLayout(graph: ViewerGraph): StructuralLayout {
  const cached = memo.get(graph);
  if (cached !== undefined) return cached;
  const layout = computeStructuralLayout(graph);
  memo.set(graph, layout);
  return layout;
}
