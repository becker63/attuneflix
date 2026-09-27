/**
 * GraphSession: everything the viewer needs about one loaded world, held outside
 * React. It owns the ViewerGraph (stable indices, typed endpoints, CSR
 * adjacency), the provenance from the manifest, and the DuckDB tables that feed
 * the renderer. React state holds only identities and revision counters.
 */
import type { Domain } from "../../projection/src/domain.ts";
import { DOMAIN_ORDER } from "../../projection/src/domain.ts";
import type { ViewerGraph } from "../../projection/src/graph.ts";
import { RELATION_ORDER, type Relation } from "../../projection/src/relation.ts";
import type { LocalDuckDB } from "./duckdb.ts";
import {
  degree,
  incidentCounts,
  neighbourhood,
  type Highlight,
  type IncidentCounts,
} from "./neighbourhood.ts";
import type { WorldManifestEntry } from "./world.ts";

export const POINTS_TABLE = "atlas_live_points";
export const LINKS_TABLE = "atlas_live_links";

export interface GraphSessionOptions {
  readonly duckdb: LocalDuckDB;
  readonly entry: WorldManifestEntry;
  readonly graph: ViewerGraph;
  readonly pointsTable?: string;
  readonly linksTable?: string;
}

export class GraphSession {
  /** The self-hosted DuckDB used by the renderer (its `WasmDuckDBConnection`). */
  readonly duckdb: LocalDuckDB;
  readonly entry: WorldManifestEntry;
  readonly graph: ViewerGraph;
  readonly pointsTable: string;
  readonly linksTable: string;
  /** Increments when a new session replaces this one; stable for a loaded world. */
  readonly sessionRevision = 1;
  /** Increments when the projected topology changes; overlays never touch it. */
  readonly topologyRevision = 1;

  constructor(options: GraphSessionOptions) {
    this.duckdb = options.duckdb;
    this.entry = options.entry;
    this.graph = options.graph;
    this.pointsTable = options.pointsTable ?? POINTS_TABLE;
    this.linksTable = options.linksTable ?? LINKS_TABLE;
  }

  get pointCount(): number {
    return this.graph.pointCount;
  }

  get linkCount(): number {
    return this.graph.linkCount;
  }

  pointId(index: number): string | null {
    return this.graph.pointIds[index] ?? null;
  }

  domainOf(index: number): Domain | null {
    const rank = this.graph.pointDomains[index];
    return rank === undefined ? null : (DOMAIN_ORDER[rank] ?? null);
  }

  highlight(index: number, enabled: readonly Relation[] = RELATION_ORDER): Highlight {
    return neighbourhood(this.graph, index, enabled);
  }

  counts(index: number): IncidentCounts {
    return incidentCounts(this.graph, index);
  }

  degreeOf(index: number, enabled: readonly Relation[] = RELATION_ORDER): number {
    return degree(this.graph, index, enabled);
  }

  /** First renderer index with at least one incident link, or null. */
  firstPointWithLinks(enabled: readonly Relation[] = RELATION_ORDER): number | null {
    for (let index = 0; index < this.graph.pointCount; index++) {
      if (degree(this.graph, index, enabled) > 0) return index;
    }
    return null;
  }

  /** Drops this session's DuckDB tables. Call when the dataset changes or unmounts. */
  async dispose(): Promise<void> {
    await this.duckdb.connection.query(`DROP TABLE IF EXISTS ${this.pointsTable}`);
    await this.duckdb.connection.query(`DROP TABLE IF EXISTS ${this.linksTable}`);
  }
}
