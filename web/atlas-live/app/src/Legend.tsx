/**
 * The legend, generated from the same typed visual vocabulary that drives
 * rendering. It lists the active overlay's categories and the enabled relations,
 * each with a text label, the render colour, and a non-colour glyph and swatch
 * pattern, so the legend is never colour-only and cannot drift from the graph.
 */
import * as stylex from "@stylexjs/stylex";
import { useAtomValue } from "jotai";

import { RELATION_ORDER } from "../../projection/src/relation.ts";
import { overlayAtom } from "./atoms.ts";
import { legendEntries } from "./vocabulary.ts";

const styles = stylex.create({
  root: {
    display: "flex",
    flexDirection: "column",
    gap: 6,
  },
  heading: {
    fontSize: 12,
    fontWeight: 600,
    textTransform: "uppercase",
    letterSpacing: 0.5,
    color: "#9ca3af",
  },
  entry: {
    display: "flex",
    alignItems: "center",
    gap: 8,
    fontSize: 12,
    color: "#e5e7eb",
  },
  swatch: {
    width: 14,
    height: 10,
    borderWidth: 2,
    flexShrink: 0,
  },
  solid: {
    borderStyle: "solid",
  },
  dashed: {
    borderStyle: "dashed",
  },
  dotted: {
    borderStyle: "dotted",
  },
  glyph: {
    width: 14,
    textAlign: "center",
    color: "#9ca3af",
  },
  label: {
    textTransform: "capitalize",
  },
});

const PATTERN_STYLES = {
  solid: styles.solid,
  dashed: styles.dashed,
  dotted: styles.dotted,
};

export function Legend() {
  const overlay = useAtomValue(overlayAtom);
  const entries = legendEntries(overlay, RELATION_ORDER);
  return (
    <section aria-label="Legend" {...stylex.props(styles.root)}>
      <h2 {...stylex.props(styles.heading)}>Legend</h2>
      {entries.map((entry) => {
        // The colour is a runtime vocabulary value, so it cannot live in a
        // compile-time StyleX style.
        // oxlint-disable-next-line react-perf/jsx-no-new-object-as-prop -- runtime vocabulary colour cannot be a StyleX style
        const swatchStyle = { borderColor: entry.color, backgroundColor: entry.color };
        return (
          <div key={`${entry.kind}:${entry.key}`} {...stylex.props(styles.entry)}>
            <span
              aria-hidden="true"
              {...stylex.props(styles.swatch, PATTERN_STYLES[entry.pattern])}
              style={swatchStyle}
            />
            <span {...stylex.props(styles.glyph)}>{entry.glyph}</span>
            <span {...stylex.props(styles.label)}>
              {entry.kind === "relation" ? `relation ${entry.label}` : entry.label}
            </span>
          </div>
        );
      })}
    </section>
  );
}
