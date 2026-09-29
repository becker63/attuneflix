/**
 * The overlay control. "Structure" fills nodes by domain; "Families" fills them
 * by family tint and swaps exact links for family edges. Families is offered
 * only while the loaded world ships families data (the toggle stays disabled
 * otherwise), so a world without families renders exactly as before. Edge
 * colour by relation is independent of this overlay.
 */
import { Toggle } from "@base-ui/react/toggle";
import * as stylex from "@stylexjs/stylex";
import { useAtomValue, useSetAtom } from "jotai";

import { familiesAtom, overlayAtom, setOverlayAtom } from "./atoms.ts";
import { OVERLAY_LABELS, OVERLAY_ORDER, type OverlayName } from "./vocabulary.ts";

const styles = stylex.create({
  root: {
    display: "flex",
    alignItems: "center",
    gap: 8,
  },
  label: {
    fontSize: 12,
    color: "#9ca3af",
  },
  toggle: {
    fontSize: 12,
    paddingTop: 4,
    paddingBottom: 4,
    paddingLeft: 10,
    paddingRight: 10,
    borderRadius: 6,
    borderWidth: 1,
    borderStyle: "solid",
    borderColor: "#4b5563",
    backgroundColor: "#111827",
    color: "#e5e7eb",
    cursor: "pointer",
  },
  disabled: {
    color: "#6b7280",
    cursor: "not-allowed",
  },
  pressed: {
    borderColor: "#60a5fa",
    backgroundColor: "#1e3a8a",
    color: "#f9fafb",
  },
});

export function OverlayControl() {
  const overlay = useAtomValue(overlayAtom);
  const setOverlay = useSetAtom(setOverlayAtom);
  const families = useAtomValue(familiesAtom);
  const selectable = (name: OverlayName): boolean => name !== "families" || families !== null;
  return (
    <div {...stylex.props(styles.root)}>
      <span {...stylex.props(styles.label)}>Overlay</span>
      {OVERLAY_ORDER.map((name) => (
        <Toggle
          key={name}
          aria-label={`${OVERLAY_LABELS[name]} overlay`}
          pressed={overlay === name}
          disabled={!selectable(name)}
          onPressedChange={() => setOverlay(name)}
          {...stylex.props(
            styles.toggle,
            !selectable(name) && styles.disabled,
            overlay === name && styles.pressed,
          )}
        >
          {OVERLAY_LABELS[name]}
        </Toggle>
      ))}
    </div>
  );
}
