/**
 * Identity-stable inline-style objects for the runtime colours of the visual
 * vocabulary. StyleX cannot express a colour read at runtime, and a fresh object
 * on every render would trip `react-perf/jsx-no-new-object-as-prop`, so the
 * styles are built once from the vocabulary's fixed colour set.
 */
import type { CSSProperties } from "react";

import { RELATION_ORDER } from "../../projection/src/relation.ts";
import { DOMAIN_ORDER_FOR_LEGEND, domainStyle, relationStyle } from "./vocabulary.ts";

const NEUTRAL = "#6b7280";

const swatches = new Map<string, CSSProperties>();
const accents = new Map<string, CSSProperties>();

function register(color: string): void {
  swatches.set(color, { borderColor: color, backgroundColor: color });
  accents.set(color, { borderColor: color, color });
}

register(NEUTRAL);
for (const relation of RELATION_ORDER) register(relationStyle(relation).color);
for (const domain of DOMAIN_ORDER_FOR_LEGEND) register(domainStyle(domain).color);

const NEUTRAL_SWATCH: CSSProperties = { borderColor: NEUTRAL, backgroundColor: NEUTRAL };
const NEUTRAL_ACCENT: CSSProperties = { borderColor: NEUTRAL, color: NEUTRAL };

/** Filled swatch (border + fill) used by the legend. */
export function swatchStyle(color: string): CSSProperties {
  return swatches.get(color) ?? NEUTRAL_SWATCH;
}

/** Outlined accent (border + text colour) used by the filter controls. */
export function accentStyle(color: string): CSSProperties {
  return accents.get(color) ?? NEUTRAL_ACCENT;
}
