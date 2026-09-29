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
  defines: { label: "defines", color: "#F28EC8", glyph: "▸", dash: "solid" },
  imports: { label: "imports", color: "#59E3F6", glyph: "⇢", dash: "dashed" },
  calls: { label: "calls", color: "#FFB84D", glyph: "↻", dash: "dotted" },
  parent: { label: "parent", color: "#76EA59", glyph: "⤴", dash: "solid" },
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

/** The neutral tint of a point with no family (a file without callables, an empty directory). */
export const NO_FAMILY_COLOR = "#3f4756";

/** One hex channel, two digits (module scope: it captures nothing). */
function hexChannel(value: number): string {
  return Math.round(value * 255)
    .toString(16)
    .padStart(2, "0");
}

function hslToHex(hue: number, saturation: number, lightness: number): string {
  const s = saturation / 100;
  const l = lightness / 100;
  const a = s * Math.min(l, 1 - l);
  const channel = (n: number): number => {
    const k = (n + hue / 30) % 12;
    return l - a * Math.max(-1, Math.min(k - 3, Math.min(9 - k, 1)));
  };
  return `#${hexChannel(channel(0))}${hexChannel(channel(8))}${hexChannel(channel(4))}`;
}

/**
 * The deterministic tint of one family: a golden-angle hue rotation at fixed
 * saturation and lightness, so neighbouring family ordinals land far apart on
 * the colour wheel and the palette is a pure function of the family ordinal.
 */
export function familyColor(ordinal: number): string {
  const hue = (((ordinal * 137.508) % 360) + 360) % 360;
  return hslToHex(hue, 62, 58);
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
  /** True for a relation the filter has disabled (rendered as off, not removed). */
  readonly disabled?: boolean;
}

export interface LegendOptions {
  /**
   * When true, every relation appears, with the disabled ones flagged, so the
   * legend reflects the filter state instead of hiding it.
   */
  readonly includeDisabledRelations?: boolean;
}

/**
 * The legend for the one graph and enabled relations. Family hue is always
 * included when the world has families; scalar shading only changes lightness.
 * There are too many families for per-family entries, so the family categories
 * are a sample hue and the neutral for points without family evidence.
 */
export function legendEntries(
  familiesPresent: boolean,
  enabledRelations: readonly Relation[],
  options?: LegendOptions,
): LegendEntry[] {
  const categories: LegendEntry[] =
    familiesPresent
      ? [
          {
            kind: "category",
            key: "family",
            label: "Family tint",
            color: familyColor(1),
            glyph: "◆",
            pattern: "solid",
          },
          {
            kind: "category",
            key: "no-family",
            label: "No family",
            color: NO_FAMILY_COLOR,
            glyph: "·",
            pattern: "dotted",
          },
        ]
      : DOMAIN_ORDER_FOR_LEGEND.map((domain): LegendEntry => {
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
  const relations = (options?.includeDisabledRelations === true ? RELATION_ORDER : enabledRelations).map(
    (relation): LegendEntry => {
      const style = RELATION_STYLES[relation];
      const disabled = !enabledRelations.includes(relation);
      return {
        kind: "relation",
        key: relation,
        label: style.label,
        color: style.color,
        glyph: style.glyph,
        pattern: style.dash,
        disabled,
      };
    },
  );
  // Scalar shading never changes these category or relation identities.
  return [...categories, ...relations];
}
