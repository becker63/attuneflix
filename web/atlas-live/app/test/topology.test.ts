/** Structure supplies territories; recorded families order occupants within them. */
import path from "node:path";

import { describe, expect, it } from "vitest";

import { decodeFamiliesFiles, projectFamilies } from "../../projection/src/families.ts";
import { projectWorld } from "../../projection/src/project.ts";
import { readFamiliesDir, readWorldDir } from "../../projection/src/world_dir.ts";
import { containsPoint, containsRect } from "../src/geometry.ts";
import { structuralLayout } from "../src/structure.ts";
import { unifiedTopologyLayout } from "../src/topology.ts";

const PREACT = "6e2bef41bf19f638be084df8cb82127e4832d4abbafa8ca20ebd5db9be3ac8a9";
const PREACT_DIR = path.join("../projection/layout_worlds", PREACT);

describe("unified topology layout", () => {
  it("groups recorded families within structural territories without changing evidence or directory geometry", async () => {
    const graph = await projectWorld(await readWorldDir(PREACT_DIR));
    const families = projectFamilies(await decodeFamiliesFiles(await readFamiliesDir(PREACT_DIR)), graph);
    const structural = structuralLayout(graph);
    const original = new Float32Array(structural.xy);
    const integrated = unifiedTopologyLayout(structural, families);
    const repeat = unifiedTopologyLayout(structural, families);

    expect(integrated.identity).toMatch(/^topology-v1:[0-9a-f]{16}$/);
    expect(repeat.identity).toBe(integrated.identity);
    expect(new Uint8Array(repeat.xy.buffer)).toEqual(new Uint8Array(integrated.xy.buffer));
    expect(structural.xy).toEqual(original);
    expect(integrated.directoryRegions).toBe(structural.directoryRegions);
    expect(integrated.structure).toBe(structural.structure);

    let changedFiles = 0;
    for (let file = 0; file < graph.fileCount; file++) {
      const cell = integrated.fileCells[file];
      const directory = integrated.structure.fileDirectory[file] ?? -1;
      const region = integrated.directoryRegions[directory];
      if (cell === undefined || region === undefined) throw new Error("missing territory");
      expect(containsRect(region, cell)).toBe(true);
      expect(containsPoint(cell, integrated.xy[file * 2] ?? NaN, integrated.xy[file * 2 + 1] ?? NaN)).toBe(true);
      if (cell !== structural.fileCells[file]) changedFiles++;
    }
    for (let symbol = 0; symbol < graph.symbolCount; symbol++) {
      const file = integrated.structure.symbolFile[symbol] ?? -1;
      if (file < 0) continue;
      const cell = integrated.fileCells[file];
      if (cell === undefined) throw new Error("missing file cell");
      expect(containsPoint(cell, integrated.xy[(graph.fileCount + symbol) * 2] ?? NaN, integrated.xy[(graph.fileCount + symbol) * 2 + 1] ?? NaN)).toBe(true);
    }
    expect(changedFiles, "family ordering changes actual file placements").toBeGreaterThan(0);

    let priorPairs = 0;
    let groupedPairs = 0;
    const filesByDirectory: number[][] = Array.from({ length: graph.directoryCount }, () => []);
    for (let file = 0; file < graph.fileCount; file++) {
      filesByDirectory[integrated.structure.fileDirectory[file] ?? 0]?.push(file);
    }
    const adjacentSameFamily = (files: number[], cells: typeof integrated.fileCells): number => {
      const ordered = files.toSorted((a, b) => {
        const left = cells[a];
        const right = cells[b];
        if (left === undefined || right === undefined) throw new Error("missing slot");
        return left.y0 - right.y0 || left.x0 - right.x0;
      });
      let same = 0;
      for (let index = 1; index < ordered.length; index++) {
        const left = families.fileDominant[ordered[index - 1] ?? -1] ?? -1;
        const right = families.fileDominant[ordered[index] ?? -1] ?? -1;
        if (left >= 0 && left === right) same++;
      }
      return same;
    };
    for (const files of filesByDirectory) {
      priorPairs += adjacentSameFamily(files, structural.fileCells);
      groupedPairs += adjacentSameFamily(files, integrated.fileCells);
    }
    expect(groupedPairs, "the layout groups more same-family neighbours").toBeGreaterThan(priorPairs);
  });
});
