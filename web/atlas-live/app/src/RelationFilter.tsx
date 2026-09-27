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

import { RELATION_ORDER, type Relation } from "../../projection/src/relation.ts";
import { setRelationMaskAtom, visibleRelationSetAtom } from "./atoms.ts";
import { relationMask } from "./selection.ts";
import { accentStyle } from "./swatch.ts";
import { isRelationName, relationStyle } from "./vocabulary.ts";

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
    flexWrap: "wrap",
    gap: 6,
  },
  toggle: {
    display: "inline-flex",
    alignItems: "center",
    gap: 6,
    fontSize: 12,
    fontFamily: "inherit",
    paddingTop: 4,
    paddingBottom: 4,
    paddingLeft: 8,
    paddingRight: 8,
    borderRadius: 6,
    borderWidth: 1,
    borderStyle: "solid",
    backgroundColor: "#111827",
    cursor: "pointer",
    opacity: 0.45,
    textDecoration: "line-through",
  },
  pressed: {
    backgroundColor: "#1e293b",
    opacity: 1,
    textDecoration: "none",
  },
  glyph: {
    fontVariantNumeric: "tabular-nums",
  },
});

function asRelations(values: readonly string[]): Relation[] {
  const relations: Relation[] = [];
  for (const value of values) {
    if (isRelationName(value)) relations.push(value);
  }
  return relations;
}

export function RelationFilter() {
  const enabled = useAtomValue(visibleRelationSetAtom);
  const setMask = useSetAtom(setRelationMaskAtom);
  const change = (values: string[]): void => {
    setMask(relationMask(asRelations(values)));
  };
  return (
    <section aria-label="Relation filter" {...stylex.props(styles.root)}>
      <span {...stylex.props(styles.heading)}>Relations</span>
      <ToggleGroup
        multiple
        value={enabled}
        onValueChange={change}
        aria-label="Enabled relations"
        {...stylex.props(styles.group)}
      >
        {RELATION_ORDER.map((relation) => {
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
        })}
      </ToggleGroup>
    </section>
  );
}
