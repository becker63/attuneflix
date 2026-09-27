import type { Relation } from "./relation.ts";

/**
 * Every way projection can reject its input. The viewer never fabricates
 * endpoints or labels; inconsistent evidence is a typed error.
 */
export type ProjectionErrorDetail =
  | {
      readonly kind: "invalid-schema";
      readonly table: string;
      readonly message: string;
    }
  | {
      readonly kind: "snapshot-mismatch";
      readonly table: string;
      readonly row: number;
      readonly expected: string;
      readonly actual: string;
    }
  | {
      readonly kind: "count-mismatch";
      readonly what: string;
      readonly expected: number;
      readonly actual: number;
    }
  | {
      readonly kind: "invalid-relation";
      readonly row: number;
      readonly relation: string;
      readonly sourceDomain: string;
      readonly targetDomain: string;
    }
  | {
      readonly kind: "unresolved-endpoint";
      readonly relation: Relation;
      readonly row: number;
      readonly side: "source" | "target";
      readonly domain: string;
      readonly id: number;
    }
  | {
      readonly kind: "invalid-locations";
      readonly message: string;
    };

export class ProjectionError extends Error {
  readonly detail: ProjectionErrorDetail;

  constructor(detail: ProjectionErrorDetail) {
    super(describe(detail));
    this.name = "ProjectionError";
    this.detail = detail;
  }

  get kind(): ProjectionErrorDetail["kind"] {
    return this.detail.kind;
  }
}

function describe(detail: ProjectionErrorDetail): string {
  switch (detail.kind) {
    case "invalid-schema":
      return `invalid ${detail.table} table: ${detail.message}`;
    case "snapshot-mismatch":
      return `snapshot_id mismatch in ${detail.table} row ${detail.row}: expected ${detail.expected}, got ${detail.actual}`;
    case "count-mismatch":
      return `count mismatch for ${detail.what}: expected ${detail.expected}, got ${detail.actual}`;
    case "invalid-relation":
      return `invalid relation row ${detail.row}: ${detail.relation} ${detail.sourceDomain} -> ${detail.targetDomain}`;
    case "unresolved-endpoint":
      return `unresolved ${detail.side} endpoint in ${detail.relation} row ${detail.row}: ${detail.domain}:${detail.id}`;
    case "invalid-locations":
      return `invalid locations table: ${detail.message}`;
    default:
      return unreachable(detail);
  }
}

function unreachable(value: never): never {
  throw new Error(`unreachable: ${String(value)}`);
}
