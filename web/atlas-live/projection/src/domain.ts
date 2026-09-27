/** Entity domains in viewer point order: files, then symbols, then directory locations. */
export const DOMAIN_ORDER = ["file", "symbol", "location"] as const;

export type Domain = (typeof DOMAIN_ORDER)[number];

export function domainRank(domain: Domain): number {
  return DOMAIN_ORDER.indexOf(domain);
}

export function isDomain(value: string): value is Domain {
  return (DOMAIN_ORDER as readonly string[]).includes(value);
}
