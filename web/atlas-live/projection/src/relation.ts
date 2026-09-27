import type { Domain } from "./domain.ts";

/**
 * The four stored basis relations, in canonical viewer order. This order (the
 * metadata column order: defines, imports, calls, parent) fixes the link order of
 * every projected graph: links are ordered by relation, then by row order within
 * the relation.
 */
export const RELATION_ORDER = ["defines", "imports", "calls", "parent"] as const;

export type Relation = (typeof RELATION_ORDER)[number];

export function relationRank(relation: Relation): number {
  return RELATION_ORDER.indexOf(relation);
}

export function isRelation(value: string): value is Relation {
  return (RELATION_ORDER as readonly string[]).includes(value);
}

/**
 * The only legal (relation, source_domain, target_domain) triples, as enforced by
 * the Repository table decoder (`src/Repository/Table.flix`).
 */
const ENDPOINT_DOMAINS: Record<Relation, readonly [Domain, Domain]> = {
  defines: ["file", "symbol"],
  imports: ["file", "file"],
  calls: ["symbol", "symbol"],
  parent: ["location", "location"],
};

export function endpointDomains(relation: Relation): readonly [Domain, Domain] {
  return ENDPOINT_DOMAINS[relation];
}
