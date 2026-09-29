/**
 * The neighbourhood depth control (1..3). Base UI's ToggleGroup is single-select
 * here, so the pressed toggle is the active depth, the current value is shown as
 * text, and the control is keyboard operable.
 */
import { Toggle } from "@base-ui/react/toggle";
import { ToggleGroup } from "@base-ui/react/toggle-group";
import * as stylex from "@stylexjs/stylex";
import { useAtomValue, useSetAtom } from "jotai";

import { neighbourhoodDepthAtom, setDepthAtom } from "./atoms.ts";
import { MAX_DEPTH, MIN_DEPTH } from "./selection.ts";

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
  group: {
    display: "flex",
    gap: 6,
  },
  toggle: {
    minWidth: 28,
    fontSize: 12,
    fontFamily: "inherit",
    paddingTop: 4,
    paddingBottom: 4,
    paddingLeft: 8,
    paddingRight: 8,
    borderRadius: 6,
    borderWidth: 1,
    borderStyle: "solid",
    borderColor: "#4b5563",
    backgroundColor: "rgba(255, 255, 255, 0.06)",
    color: "#e5e7eb",
    cursor: "pointer",
  },
  pressed: {
    borderColor: "#60a5fa",
    backgroundColor: "rgba(96, 165, 250, 0.28)",
    color: "#f9fafb",
  },
  value: {
    fontSize: 12,
    color: "#e5e7eb",
  },
});

const DEPTH_VALUES: readonly number[] = [MIN_DEPTH, 2, MAX_DEPTH];
const DEPTH_LABELS: readonly string[] = DEPTH_VALUES.map((depth) => String(depth));

/** Pre-built selection arrays so the controlled value keeps a stable identity. */
const DEPTH_SELECTIONS: Readonly<Record<number, readonly string[]>> = {
  1: ["1"],
  2: ["2"],
  3: ["3"],
};

function selectionFor(depth: number): readonly string[] {
  return DEPTH_SELECTIONS[depth] ?? DEPTH_SELECTIONS[1] ?? [];
}

export function DepthControl() {
  const depth = useAtomValue(neighbourhoodDepthAtom);
  const setDepth = useSetAtom(setDepthAtom);
  const change = (values: string[]): void => {
    const next = Number(values[0]);
    if (Number.isFinite(next)) setDepth(next);
  };
  return (
    <section aria-label="Neighbourhood depth" {...stylex.props(styles.root)}>
      <span {...stylex.props(styles.heading)}>Depth</span>
      <ToggleGroup
        value={selectionFor(depth)}
        onValueChange={change}
        aria-label="Neighbourhood depth"
        {...stylex.props(styles.group)}
      >
        {DEPTH_LABELS.map((label) => (
          <Toggle
            key={label}
            value={label}
            aria-label={`Depth ${label}`}
            {...stylex.props(styles.toggle, label === String(depth) && styles.pressed)}
          >
            {label}
          </Toggle>
        ))}
      </ToggleGroup>
      <span aria-live="polite" data-testid="depth-value" {...stylex.props(styles.value)}>
        Depth {depth}
      </span>
    </section>
  );
}
