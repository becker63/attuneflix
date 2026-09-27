/**
 * The one typed visual vocabulary. Every rendering decision (node fill, edge
 * colour) and the generated legend read this module, so the two can never drift:
 * a unit test asserts the legend entries and the render accessors read the same
 * data.
 *
 * Colour is never the only signal: every category and relation also carries a
 * non-colour glyph, and relations carry a dash pattern for the legend swatch.
 */
import type { Domain } from "../../projection/src/domain.ts";
import { RELATION_ORDER, type Relation } from "../../projection/src/relation.ts";

/** Overlays available in the viewer. Slice A ships only the Structure overlay. */
export const OVERLAY_ORDER = ["structure"] as const;

export type OverlayName = (typeof OVERLAY_ORDER)[number];

export const OVERLAY_LABELS: Record<OverlayName, string> = {
  structure: "Structure",
};

export interface CategoryStyle {
  /** Human label shown in the legend and details. */
  readonly label: string;
  /** Node fill colour, as a hex string understood by the renderer. */
  readonly color: string;
  /** Non-colour shape signal, shown next to the label. */
  readonly glyph: string;
  /** Swatch border pattern, so the legend is not colour-only. */
  readonly pattern: "solid" | "dashed" | "dotted";
}

export interface RelationStyle {
  readonly label: string;
  readonly color: string;
  readonly glyph: string;
  readonly dash: "solid" | "dashed" | "dotted";
}

const DOMAIN_STYLES: Record<Domain, CategoryStyle> = {
  file: { label: "File", color: "#4e79a7", glyph: "■", pattern: "solid" },
  symbol: { label: "Symbol", color: "#f28e2b", glyph: "●", pattern: "solid" },
  location: { label: "Directory", color: "#59a14f", glyph: "▲", pattern: "solid" },
};

const RELATION_STYLES: Record<Relation, RelationStyle> = {
  defines: { label: "defines", color: "#8ab4ff", glyph: "▸", dash: "solid" },
  imports: { label: "imports", color: "#c792ea", glyph: "⇢", dash: "dashed" },
  calls: { label: "calls", color: "#ffcb6b", glyph: "↻", dash: "dotted" },
  parent: { label: "parent", color: "#80cbc4", glyph: "⤴", dash: "solid" },
};

export const DOMAIN_ORDER_FOR_LEGEND: readonly Domain[] = ["file", "symbol", "location"];

export function domainStyle(domain: Domain): CategoryStyle {
  return DOMAIN_STYLES[domain];
}

export function relationStyle(relation: Relation): RelationStyle {
  return RELATION_STYLES[relation];
}

/** The renderer's map strategy: node fill keyed by the `domain` column. */
export function pointColorMap(): Record<Domain, string> {
  return {
    file: DOMAIN_STYLES.file.color,
    symbol: DOMAIN_STYLES.symbol.color,
    location: DOMAIN_STYLES.location.color,
  };
}

export function isRelationName(value: string): value is Relation {
  return (RELATION_ORDER as readonly string[]).includes(value);
}

/**
 * Edge colour accessor for the renderer, called with the value of the link's
 * `relation` column. Falls back to a neutral grey for an unexpected value so the
 * graph never renders an inventing colour.
 */
export function relationColor(value: string): string {
  return isRelationName(value) ? RELATION_STYLES[value].color : "#6b7280";
}

export interface LegendEntry {
  readonly kind: "category" | "relation";
  /** Stable key (domain or relation name). */
  readonly key: string;
  readonly label: string;
  readonly color: string;
  readonly glyph: string;
  readonly pattern: "solid" | "dashed" | "dotted";
}

/**
 * The legend for an overlay and a set of enabled relations. Both the overlay
 * categories and the relation entries are read from this module's styles, so the
 * legend cannot disagree with what is rendered.
 */
export function legendEntries(overlay: OverlayName, enabledRelations: readonly Relation[]): LegendEntry[] {
  const categories = DOMAIN_ORDER_FOR_LEGEND.map((domain): LegendEntry => {
    const style = DOMAIN_STYLES[domain];
    return {
      kind: "category",
      key: domain,
      label: style.label,
      color: style.color,
      glyph: style.glyph,
      pattern: style.pattern,
    };
  });
  const relations = RELATION_ORDER.filter((relation) => enabledRelations.includes(relation)).map(
    (relation): LegendEntry => {
      const style = RELATION_STYLES[relation];
      return {
        kind: "relation",
        key: relation,
        label: style.label,
        color: style.color,
        glyph: style.glyph,
        pattern: style.dash,
      };
    },
  );
  // `overlay` currently selects the same category set; keep it in the signature
  // so a future overlay cannot silently reuse another overlay's legend.
  void overlay;
  return [...categories, ...relations];
}
