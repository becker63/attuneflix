/**
 * The overlay control. Slice A ships one node-colour overlay ("Structure", fill
 * by domain); the control makes the active overlay an explicit, focusable choice
 * that updates the diagnostics hook. Edge colour by relation is independent of
 * this overlay.
 */
import { Toggle } from "@base-ui/react/toggle";
import * as stylex from "@stylexjs/stylex";
import { useAtom } from "jotai";

import { overlayAtom } from "./atoms.ts";
import { publish } from "./diagnostics.ts";

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
  pressed: {
    borderColor: "#60a5fa",
    backgroundColor: "#1e3a8a",
    color: "#f9fafb",
  },
});

export function OverlayControl() {
  const [overlay, setOverlay] = useAtom(overlayAtom);
  const selectStructure = (): void => {
    setOverlay("structure");
    publish({ overlay: { name: "structure", revision: 1 } });
  };
  return (
    <div {...stylex.props(styles.root)}>
      <span {...stylex.props(styles.label)}>Overlay</span>
      <Toggle
        aria-label="Structure overlay"
        pressed={overlay === "structure"}
        onPressedChange={selectStructure}
        {...stylex.props(styles.toggle, overlay === "structure" && styles.pressed)}
      >
        Structure
      </Toggle>
    </div>
  );
}
