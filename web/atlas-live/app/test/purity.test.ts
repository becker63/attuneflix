/**
 * Separation and honesty laws of the frontier layer:
 *
 * - VAL-PRES-007: evidence vs view separation is explicit. The view types are
 *   exactly VisibleFrontier / ProjectedNode / ProjectedDependency /
 *   ProjectionMetrics; src/frontier/ is pure TypeScript (no React, renderer,
 *   state-library, or DOM imports; ViewerGraph only as a type); the projection
 *   never mutates the evidence graph or the frontier inputs.
 * - VAL-PRES-008: the frontend never invents semantics. Every projected node,
 *   wire, and metric of the controlled fixture equals an oracle computed in
 *   this test directly from the admitted basis tables (entities / relations /
 *   locations), never via the frontier modules.
 * - VAL-METRIC-011: no hard-coded qualitative classes. A source scan of the
 *   shipped app/src and projection/src trees fails on the brief's
 *   classification vocabulary in class-label position.
 * - VAL-WIRE-016: relation-kind presentation has one source. The colour/glyph
 *   literals of vocabulary.ts's relation styles appear in no other shipped
 *   app module.
 */
import { readdirSync, readFileSync } from "node:fs";
import path from "node:path";

import { describe, expect, it } from "vitest";

import { RELATION_ORDER } from "../../projection/src/relation.ts";
import type { WorldTables } from "../../projection/src/tables.ts";
import { containmentTree } from "../src/frontier/containment.ts";
import { collapse, expand, initialFrontier, projectedNodes } from "../src/frontier/frontier.ts";
import { computeProjectionMetrics } from "../src/frontier/metrics.ts";
import { projectFrontier } from "../src/frontier/wires.ts";
import { relationStyle } from "../src/vocabulary.ts";
import { FIXTURE_IDS, frontierFixtureGraph, frontierFixtureTables } from "./frontierFixture.ts";

const ID = FIXTURE_IDS;
const BOTH = ["imports", "calls"] as const;

/** Paths of every shipped source file under the given roots, relative to cwd. */
function shippedSources(roots: readonly string[]): string[] {
  const out: string[] = [];
  const walk = (dir: string): void => {
    for (const entry of readdirSync(dir, { withFileTypes: true })) {
      const full = path.join(dir, entry.name);
      if (entry.isDirectory()) walk(full);
      else if (entry.name.endsWith(".ts") || entry.name.endsWith(".tsx")) out.push(full);
    }
  };
  for (const root of roots) walk(root);
  return out.toSorted((a, b) => a.localeCompare(b));
}

describe("frontier layer purity (VAL-PRES-007)", () => {
  const frontierSources = shippedSources(["src/frontier"]);

  it("ships the four view types and imports the evidence graph only as a type", () => {
    expect(frontierSources.length).toBeGreaterThan(0);
    const corpus = frontierSources.map((file) => readFileSync(file, "utf8")).join("\n");
    for (const viewType of ["VisibleFrontier", "ProjectedNode", "ProjectedDependency", "ProjectionMetrics"]) {
      expect(corpus, `${viewType} is an exported view type`).toMatch(
        new RegExp(`export (?:interface|type) ${viewType}\\b`),
      );
    }
    for (const file of frontierSources) {
      const source = readFileSync(file, "utf8");
      for (const match of source.matchAll(/import\s+([^;]*?)\s+from\s+["']([^"']+)["']/g)) {
        const clause = match[1] ?? "";
        const specifier = match[2] ?? "";
        // The evidence graph's TYPE crosses the boundary as a type only; pure
        // functions (pointId) may be value imports.
        if (specifier.includes("projection/src/graph") && clause.includes("ViewerGraph")) {
          expect(clause, `${file} imports ViewerGraph as a type`).toMatch(
            /^\s*type\s|\btype\s+ViewerGraph\b/,
          );
        }
      }
    }
  });

  it("has no React, renderer, state, or DOM dependency", () => {
    const forbidden = /^(react|react-dom|jotai|vite)(\/|$)|^@(cosmograph|duckdb|stylexjs|base-ui)\//;
    const domGlobals = /\b(document|window|localStorage|HTMLElement|navigator)\b/;
    for (const file of frontierSources) {
      const source = readFileSync(file, "utf8");
      for (const match of source.matchAll(/from\s+["']([^"']+)["']/g)) {
        expect(forbidden.test(match[1] ?? ""), `${file} imports ${match[1] ?? ""}`).toBe(false);
      }
      expect(domGlobals.test(source), `${file} touches a DOM global`).toBe(false);
    }
  });

  it("never mutates the evidence graph or the frontier inputs", () => {
    const graph = frontierFixtureGraph();
    const tree = containmentTree(graph);
    const fingerprint = (): unknown => ({
      pointIds: [...graph.pointIds],
      linkRows: Array.from(graph.linkRows),
      sources: Array.from(graph.linkSourceIndices),
      targets: Array.from(graph.linkTargetIndices),
      relations: Array.from(graph.linkRelations),
      counts: { ...graph.relationCounts },
    });
    const before = fingerprint();
    const initial = initialFrontier();
    let frontier = expand(tree, initial, ID.a);
    frontier = expand(tree, frontier, ID.xFile);
    computeProjectionMetrics(graph, tree, projectFrontier(graph, tree, frontier, BOTH));
    frontier = collapse(tree, frontier, ID.a);
    computeProjectionMetrics(graph, tree, projectFrontier(graph, tree, frontier, BOTH));
    expect(fingerprint()).toEqual(before);
    // The initial frontier object is untouched by the whole sequence.
    expect(initial.expanded).toEqual([]);
    expect(initial.revision).toBe(0);
    expect(frontier.expanded).toEqual([]);
  });
});

/** Containing directory of a path, per the evidence path convention. */
function containingPath(p: string): string {
  const slash = p.lastIndexOf("/");
  return slash < 0 ? "" : p.slice(0, slash);
}

function oracleRelationRank(relation: string): number {
  return relation === "imports" ? 0 : 1;
}

/**
 * Recomputes the default-frontier projection of the fixture from the raw
 * admitted tables alone: top-level regions from locations/entity paths, wires
 * from the relation rows, counters from region membership. Reads no frontier
 * module.
 */
function fixtureOracle(tables: WorldTables): {
  nodes: string[];
  wires: Array<[string, string, string, number, number[]]>;
  internalized: number;
  counters: Map<string, { internal: number; egress: number; ingress: number }>;
} {
  const locations = tables.locations;
  if (locations === null) throw new Error("fixture ships locations");
  const directoryPathById = new Map<number, string>();
  for (const row of locations) {
    if (row.kind === "directory") directoryPathById.set(row.locationId, row.path);
  }
  const fileIdByPath = new Map<string, string>();
  for (const entity of tables.entities) {
    if (entity.domain === "file") fileIdByPath.set(entity.path, `file:${entity.entityId}`);
  }
  const regionOfPath = (p: string): string => {
    let directory = containingPath(p);
    if (directory === "") {
      const file = fileIdByPath.get(p);
      if (file === undefined) throw new Error(`no file for ${p}`);
      return file;
    }
    let parent = containingPath(directory);
    while (parent !== "") {
      directory = parent;
      parent = containingPath(directory);
    }
    for (const [id, candidate] of directoryPathById) {
      if (candidate === directory) return `location:${id}`;
    }
    throw new Error(`no directory for ${directory}`);
  };
  const nodes = new Set<string>();
  // Every root-child directory is a node, even one that holds no entity.
  for (const [id, directoryPath] of directoryPathById) {
    if (directoryPath !== "" && containingPath(directoryPath) === "") nodes.add(`location:${id}`);
  }
  for (const entity of tables.entities) nodes.add(regionOfPath(entity.path));
  const counters = new Map<string, { internal: number; egress: number; ingress: number }>();
  const counter = (region: string): { internal: number; egress: number; ingress: number } => {
    const existing = counters.get(region);
    if (existing !== undefined) return existing;
    const created = { internal: 0, egress: 0, ingress: 0 };
    counters.set(region, created);
    return created;
  };
  for (const node of nodes) counter(node);
  const pathOf = new Map<string, string>();
  for (const entity of tables.entities) pathOf.set(`${entity.domain}:${entity.entityId}`, entity.path);
  const aggregated = new Map<
    string,
    { relation: string; source: string; target: string; ordinals: number[] }
  >();
  let internalized = 0;
  for (const [row, data] of tables.relations.entries()) {
    if (data.relation !== "imports" && data.relation !== "calls") continue;
    const source = regionOfPath(pathOf.get(`${data.sourceDomain}:${data.sourceId}`) ?? "");
    const target = regionOfPath(pathOf.get(`${data.targetDomain}:${data.targetId}`) ?? "");
    if (source === target) {
      internalized += 1;
      counter(source).internal += 1;
      continue;
    }
    counter(source).egress += 1;
    counter(target).ingress += 1;
    const key = `${data.relation}|${source}|${target}`;
    const wire = aggregated.get(key) ?? { relation: data.relation, source, target, ordinals: [] };
    wire.ordinals.push(row);
    aggregated.set(key, wire);
  }
  const pointIndex = (id: string): number => {
    const [domain, raw] = id.split(":");
    const entityId = Number(raw);
    if (domain === "file") return entityId;
    if (domain === "symbol") return tables.metadata.fileCount + entityId;
    return tables.metadata.symbolCount + entityId;
  };
  const wires = [...aggregated.values()]
    .toSorted(
      (a, b) =>
        oracleRelationRank(a.relation) - oracleRelationRank(b.relation) ||
        pointIndex(a.source) - pointIndex(b.source) ||
        pointIndex(a.target) - pointIndex(b.target),
    )
    .map((wire): [string, string, string, number, number[]] => [
      wire.relation,
      wire.source,
      wire.target,
      wire.ordinals.length,
      wire.ordinals,
    ]);
  return { nodes: [...nodes], wires, internalized, counters };
}

describe("never-invented semantics: the basis-fact oracle (VAL-PRES-008)", () => {
  it("equals the frontier projection and metrics on the fixture, node for node", () => {
    const tables = frontierFixtureTables();
    const expected = fixtureOracle(tables);
    const graph = frontierFixtureGraph();
    const tree = containmentTree(graph);
    const projection = projectFrontier(graph, tree, initialFrontier(), BOTH);

    // Nodes: exactly the oracle's region set.
    expect(projection.nodes.map((node) => node.id).toSorted((a, b) => a.localeCompare(b))).toEqual(
      expected.nodes.toSorted((a, b) => a.localeCompare(b)),
    );
    // Wires: same triples, multiplicities, and row ordinals.
    expect(
      projection.wires.map((wire) => [
        wire.relation,
        wire.source,
        wire.target,
        wire.multiplicity,
        wire.provenance,
      ]),
    ).toEqual(expected.wires);
    expect(projection.internalized).toBe(expected.internalized);

    // Metrics: the oracle's membership counters equal the module's vectors.
    const metrics = computeProjectionMetrics(graph, tree, projection);
    for (const [region, counter] of expected.counters) {
      const actual = metrics.get(region);
      if (actual === undefined) throw new Error(`no metrics for ${region}`);
      expect(actual.internal, `${region}.internal`).toBe(counter.internal);
      expect(actual.egress, `${region}.egress`).toBe(counter.egress);
      expect(actual.ingress, `${region}.ingress`).toBe(counter.ingress);
    }
  });

  it("derives nodes from evidence ids only — no filename or path classification", () => {
    // The projection's node ids are exactly the admitted point ids; kinds come
    // from the admitted domains, never from path patterns.
    const graph = frontierFixtureGraph();
    const tree = containmentTree(graph);
    for (const node of projectedNodes(tree, initialFrontier())) {
      expect(graph.pointIds[node.index]).toBe(node.id);
      const domain =
        node.index < graph.fileCount
          ? "file"
          : node.index < graph.fileCount + graph.symbolCount
            ? "symbol"
            : "location";
      expect(node.kind).toBe(domain === "location" ? "directory" : domain);
    }
  });
});

describe("no hard-coded qualitative classes (VAL-METRIC-011)", () => {
  // The brief's §10 classification vocabulary. The unambiguous class words are
  // banned anywhere in shipped code; the overloaded word "source" is banned in
  // classification position (assigned as a kind/class/category/label value).
  const CLASS_WORDS = /\b(islands?|gateways?|hubs?|mixers?|sinks?)\b/i;
  const CLASS_ASSIGNMENT =
    /(?:kind|class|category|label|type)\s*[=:]\s*["'`](?:island|gateway|hub|sink|source|mixer)s?["'`]/i;

  it("finds no classification vocabulary in shipped app/src or projection/src", () => {
    const files = shippedSources(["src", "../projection/src"]);
    expect(files.length).toBeGreaterThan(10);
    for (const file of files) {
      const source = readFileSync(file, "utf8");
      const classMatch = CLASS_WORDS.exec(source);
      expect(classMatch, `${file} uses qualitative class word '${classMatch?.[0] ?? ""}'`).toBeNull();
      const assignment = CLASS_ASSIGNMENT.exec(source);
      expect(assignment, `${file} assigns a qualitative class: '${assignment?.[0] ?? ""}'`).toBeNull();
    }
  });
});

describe("single shared relation vocabulary (VAL-WIRE-016)", () => {
  it("keeps the relation colour and glyph literals inside vocabulary.ts", () => {
    const literals = new Set<string>();
    for (const relation of RELATION_ORDER) {
      const style = relationStyle(relation);
      literals.add(style.color);
      literals.add(style.glyph);
    }
    for (const file of shippedSources(["src"])) {
      if (file.endsWith(path.join("src", "vocabulary.ts"))) continue;
      const source = readFileSync(file, "utf8");
      for (const literal of literals) {
        expect(source.includes(literal), `${file} redefines the relation literal ${literal}`).toBe(false);
      }
    }
  });
});
