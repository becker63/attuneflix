/**
 * One layout for structure and recorded families. Directory rectangles remain
 * the exact structural territories; within each directory, files with the same
 * dominant family occupy neighbouring cells. Symbols are similarly ordered
 * within their defining file. No entity crosses a containment boundary and no
 * evidence row changes. Worlds without families keep their structural layout.
 */
import type { WorldFamilies } from "../../projection/src/families.ts";
import { centerOf, type Rect } from "./geometry.ts";
import type { StructuralLayout } from "./structure.ts";

export type LayoutFamilies = Pick<WorldFamilies, "fileDominant" | "symbolFamily">;

/** A deterministic identity over the structure and the two recorded assignments. */
function topologyIdentity(base: StructuralLayout, families: LayoutFamilies): string {
  let first = 0x811c9dc5;
  let second = 0x050c5d1f;
  const byte = (value: number): void => {
    first = Math.imul(first ^ value, 0x01000193);
    second = Math.imul(second ^ value, 0x5bd1e995);
  };
  const word = (value: number): void => {
    for (let shift = 0; shift < 32; shift += 8) byte((value >>> shift) & 0xff);
  };
  for (let index = 0; index < base.identity.length; index++) word(base.identity.charCodeAt(index));
  for (const values of [families.fileDominant, families.symbolFamily]) {
    word(values.length);
    for (const value of values) word(value);
  }
  return `topology-v1:${(first >>> 0).toString(16).padStart(8, "0")}${(second >>> 0).toString(16).padStart(8, "0")}`;
}

function compareCells(a: Rect, b: Rect): number {
  return a.y0 - b.y0 || a.x0 - b.x0;
}

function familyRank(value: number): number {
  return value < 0 ? Number.MAX_SAFE_INTEGER : value;
}

function place(xy: Float32Array, index: number, x: number, y: number): void {
  xy[index * 2] = x;
  xy[index * 2 + 1] = y;
}

/**
 * Applies recorded families to the existing structural slots. This is a view
 * permutation, not a scientific clustering step. The structural geometry and
 * all directory anchors stay fixed; only occupants of sibling slots change.
 */
export function unifiedTopologyLayout(base: StructuralLayout, families: LayoutFamilies): StructuralLayout {
  const { fileDirectory, symbolFile } = base.structure;
  if (families.fileDominant.length !== fileDirectory.length || families.symbolFamily.length !== symbolFile.length) {
    throw new Error("family assignment counts do not match the structural layout");
  }
  const fileCount = fileDirectory.length;
  const xy = new Float32Array(base.xy);
  const fileCells = [...base.fileCells];
  const filesByDirectory: number[][] = Array.from({ length: base.directoryRegions.length }, () => []);
  const symbolsByFile: number[][] = Array.from({ length: fileCount }, () => []);
  for (let file = 0; file < fileCount; file++) filesByDirectory[fileDirectory[file] ?? 0]?.push(file);
  for (let symbol = 0; symbol < symbolFile.length; symbol++) {
    const file = symbolFile[symbol] ?? -1;
    if (file >= 0) symbolsByFile[file]?.push(symbol);
  }

  for (const files of filesByDirectory) {
    if (files.length === 0) continue;
    const cells: Rect[] = [];
    for (const file of files) {
      const cell = base.fileCells[file];
      if (cell === undefined) throw new Error("structural layout has a missing file cell");
      cells.push(cell);
    }
    const orderedCells = cells.toSorted(compareCells);
    const orderedFiles = files.toSorted((a, b) =>
      familyRank(families.fileDominant[a] ?? -1) - familyRank(families.fileDominant[b] ?? -1) || a - b,
    );
    for (const [slot, file] of orderedFiles.entries()) {
      const oldCell = base.fileCells[file];
      const newCell = orderedCells[slot];
      if (oldCell === undefined || newCell === undefined) continue;
      fileCells[file] = newCell;
      const [fileX, fileY] = centerOf(newCell);
      place(xy, file, fileX, fileY);

      // Reuse the structural symbol slots, translated with their file, then
      // assign nearby slots to members of the same recorded family.
      const oldX = (oldCell.x0 + oldCell.x1) / 2;
      const oldY = (oldCell.y0 + oldCell.y1) / 2;
      const symbols = symbolsByFile[file] ?? [];
      const slots = symbols
        .map((symbol) => ({ x: base.xy[(fileCount + symbol) * 2] ?? oldX, y: base.xy[(fileCount + symbol) * 2 + 1] ?? oldY }))
        .toSorted((a, b) => a.y - b.y || a.x - b.x);
      const orderedSymbols = symbols.toSorted((a, b) =>
        familyRank(families.symbolFamily[a] ?? -1) - familyRank(families.symbolFamily[b] ?? -1) || a - b,
      );
      for (const [position, symbol] of orderedSymbols.entries()) {
        const original = slots[position];
        if (original !== undefined) place(xy, fileCount + symbol, fileX + original.x - oldX, fileY + original.y - oldY);
      }
    }
  }

  return {
    identity: topologyIdentity(base, families),
    structure: base.structure,
    xy,
    directoryRegions: base.directoryRegions,
    fileCells,
  };
}
