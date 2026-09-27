/**
 * The legend, generated from the same typed visual vocabulary that drives
 * rendering. It lists the active overlay's categories and every relation, each
 * with a text label, the render colour, and a non-colour glyph and swatch
 * pattern. A relation the filter has disabled is marked as off in text and by
 * state, so the legend reflects the filter and is never colour-only.
 */
import * as stylex from "@stylexjs/stylex";
import { useAtomValue } from "jotai";

import { activeLegendAtom } from "./atoms.ts";
import { swatchStyle } from "./swatch.ts";

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
  disabledEntry: {
    color: "#6b7280",
  },
  disabledLabel: {
    marginLeft: "auto",
    fontSize: 10,
    textTransform: "uppercase",
    letterSpacing: 0.5,
    color: "#9ca3af",
  },
  disabledSwatch: {
    opacity: 0.3,
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
  const entries = useAtomValue(activeLegendAtom);
  return (
    <section aria-label="Legend" {...stylex.props(styles.root)}>
      <h2 {...stylex.props(styles.heading)}>Legend</h2>
      {entries.map((entry) => {
        const disabled = entry.disabled === true;
        return (
          <div
            key={`${entry.kind}:${entry.key}`}
            aria-disabled={disabled}
            data-disabled={disabled ? "true" : "false"}
            {...stylex.props(styles.entry, disabled && styles.disabledEntry)}
          >
            <span
              aria-hidden="true"
              {...stylex.props(
                styles.swatch,
                PATTERN_STYLES[entry.pattern],
                disabled && styles.disabledSwatch,
              )}
              style={swatchStyle(entry.color)}
            />
            <span {...stylex.props(styles.glyph)}>{entry.glyph}</span>
            <span {...stylex.props(styles.label)}>
              {entry.kind === "relation" ? `relation ${entry.label}` : entry.label}
            </span>
            {disabled ? <span {...stylex.props(styles.disabledLabel)}>off</span> : null}
          </div>
        );
      })}
    </section>
  );
}
