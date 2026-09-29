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
import { accentStyle, swatchStyle } from "./swatch.ts";
import type { LegendEntry } from "./vocabulary.ts";

const styles = stylex.create({
  root: {
    display: "flex",
    flexDirection: "column",
    gap: 9,
    paddingTop: 16,
    borderTopWidth: 1,
    borderTopStyle: "solid",
    borderTopColor: "rgba(255, 255, 255, 0.18)",
  },
  heading: {
    fontSize: 13,
    fontWeight: 700,
    color: "#fff4fa",
  },
  subheading: {
    marginTop: 4,
    fontSize: 12,
    fontWeight: 600,
    color: "#e8c5d8",
  },
  entry: {
    display: "flex",
    alignItems: "center",
    gap: 8,
    minHeight: 25,
    fontSize: 13,
    color: "#f1e7ee",
  },
  disabledEntry: {
    color: "#a69aa3",
  },
  disabledLabel: {
    marginLeft: "auto",
    fontSize: 11,
    textTransform: "uppercase",
    letterSpacing: 0.5,
    color: "#9ca3af",
  },
  disabledSwatch: {
    opacity: 0.3,
  },
  swatch: {
    width: 22,
    height: 14,
    borderWidth: 3,
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
    width: 22,
    textAlign: "center",
    fontSize: 17,
    fontWeight: 700,
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

function LegendRow({ entry }: { entry: LegendEntry }) {
  const disabled = entry.disabled === true;
  return (
    <div
      aria-disabled={disabled}
      data-disabled={disabled ? "true" : "false"}
      {...stylex.props(styles.entry, disabled && styles.disabledEntry)}
    >
      <span
        aria-hidden="true"
        {...stylex.props(styles.swatch, PATTERN_STYLES[entry.pattern], disabled && styles.disabledSwatch)}
        style={swatchStyle(entry.color)}
      />
      <span aria-hidden="true" {...stylex.props(styles.glyph)} style={accentStyle(entry.color)}>
        {entry.glyph}
      </span>
      <span {...stylex.props(styles.label)}>{entry.label}</span>
      {disabled ? <span {...stylex.props(styles.disabledLabel)}>off</span> : null}
    </div>
  );
}

export function Legend() {
  const entries = useAtomValue(activeLegendAtom);
  return (
    <section aria-label="Legend" {...stylex.props(styles.root)}>
      <h2 {...stylex.props(styles.heading)}>Legend</h2>
      <span {...stylex.props(styles.subheading)}>Nodes</span>
      {entries.filter((entry) => entry.kind === "category").map((entry) => (
        <LegendRow key={entry.key} entry={entry} />
      ))}
      <span {...stylex.props(styles.subheading)}>Relations</span>
      {entries.filter((entry) => entry.kind === "relation").map((entry) => (
        <LegendRow key={entry.key} entry={entry} />
      ))}
    </section>
  );
}
