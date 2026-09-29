/**
 * The relation filter: one toggle per stored relation. Disabling a relation
 * only changes how it is drawn (its links become transparent and zero-width) and
 * which adjacency the derived neighbourhood reads; it never changes the loaded
 * topology. Base UI's ToggleGroup gives every toggle a real button with a
 * pressed state, so the filter is keyboard operable and not colour-only.
 */
import { Toggle } from "@base-ui/react/toggle";
import { ToggleGroup } from "@base-ui/react/toggle-group";
import * as stylex from "@stylexjs/stylex";
import { useAtomValue, useSetAtom } from "jotai";
import { useMemo } from "react";

import type { Relation } from "../../projection/src/relation.ts";
import { setRelationMaskAtom, visibleRelationSetAtom } from "./atoms.ts";
import { relationMask } from "./selection.ts";
import { accentStyle } from "./swatch.ts";
import { isRelationName, relationStyle } from "./vocabulary.ts";

const styles = stylex.create({
  root: {
    display: "flex",
    flexDirection: "column",
    gap: 8,
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
    marginTop: 10,
    fontSize: 12,
    fontWeight: 600,
    color: "#e8c5d8",
  },
  note: {
    fontSize: 12,
    lineHeight: 1.4,
    color: "#c9bac5",
  },
  group: {
    display: "grid",
    gridTemplateColumns: "repeat(2, minmax(0, 1fr))",
    gap: 8,
  },
  toggle: {
    display: "inline-flex",
    alignItems: "center",
    gap: 8,
    width: "100%",
    minHeight: 38,
    fontSize: 13,
    fontFamily: "inherit",
    fontWeight: 600,
    paddingTop: 7,
    paddingBottom: 7,
    paddingLeft: 10,
    paddingRight: 10,
    borderRadius: 6,
    borderWidth: 1,
    borderStyle: "solid",
    backgroundColor: "rgba(255, 255, 255, 0.04)",
    cursor: "pointer",
    opacity: 0.6,
  },
  pressed: {
    backgroundColor: "rgba(255, 255, 255, 0.12)",
    opacity: 1,
  },
  glyph: {
    fontVariantNumeric: "tabular-nums",
  },
});

const WIRE_RELATIONS: readonly Relation[] = ["imports", "calls"];
const PATH_RELATIONS: readonly Relation[] = ["defines", "parent"];

function asRelations(values: readonly string[]): Relation[] {
  const relations: Relation[] = [];
  for (const value of values) {
    if (isRelationName(value)) relations.push(value);
  }
  return relations;
}

export function RelationFilter() {
  const enabled = useAtomValue(visibleRelationSetAtom);
  const wireValues = useMemo(() => enabled.filter((relation) => WIRE_RELATIONS.includes(relation)), [enabled]);
  const pathValues = useMemo(() => enabled.filter((relation) => PATH_RELATIONS.includes(relation)), [enabled]);
  const setMask = useSetAtom(setRelationMaskAtom);
  const change = (group: readonly Relation[], values: string[]): void => {
    setMask(relationMask([...enabled.filter((relation) => !group.includes(relation)), ...asRelations(values)]));
  };
  const toggles = (group: readonly Relation[]) =>
    group.map((relation) => {
      const style = relationStyle(relation);
      const pressed = enabled.includes(relation);
      return (
        <Toggle
          key={relation}
          value={relation}
          aria-label={`${style.label} edges`}
          {...stylex.props(styles.toggle, pressed && styles.pressed)}
          style={accentStyle(style.color)}
        >
          <span aria-hidden="true" {...stylex.props(styles.glyph)}>
            {style.glyph}
          </span>
          {style.label}
        </Toggle>
      );
    });
  return (
    <section aria-label="Relation filter" {...stylex.props(styles.root)}>
      <span {...stylex.props(styles.heading)}>Connections</span>
      <span {...stylex.props(styles.note)}>Colored wires between regions and entities.</span>
      <ToggleGroup
        multiple
        value={wireValues}
        onValueChange={(values) => change(WIRE_RELATIONS, values)}
        aria-label="Visible connections"
        {...stylex.props(styles.group)}
      >
        {toggles(WIRE_RELATIONS)}
      </ToggleGroup>
      <span {...stylex.props(styles.subheading)}>Inspection paths</span>
      <span {...stylex.props(styles.note)}>Definition and parent facts guide highlights; they do not draw wires.</span>
      <ToggleGroup
        multiple
        value={pathValues}
        onValueChange={(values) => change(PATH_RELATIONS, values)}
        aria-label="Inspection paths"
        {...stylex.props(styles.group)}
      >
        {toggles(PATH_RELATIONS)}
      </ToggleGroup>
    </section>
  );
}
