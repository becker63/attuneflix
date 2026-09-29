/**
 * The application shell. The graph owns most of the viewport; a compact sidebar
 * holds the overlay control, the hovered entity's details, and the generated
 * legend. The dataset lifecycle (loading, ready, error) lives in the
 * SessionController, which React reads through `useSyncExternalStore`.
 */
import * as stylex from "@stylexjs/stylex";
import { useAtom } from "jotai";
import { useSyncExternalStore } from "react";

import type { SessionController } from "./controller.ts";
import { reuseShadingAtom } from "./atoms.ts";
import { datasetLabel } from "./datasets.ts";
import { Details } from "./Details.tsx";
import { DepthControl } from "./DepthControl.tsx";
import { FamilyEdges } from "./FamilyEdges.tsx";
import { GraphView } from "./GraphView.tsx";
import { Header } from "./Header.tsx";
import { Legend } from "./Legend.tsx";
import { RelationFilter } from "./RelationFilter.tsx";

const styles = stylex.create({
  root: {
    display: "flex",
    flexDirection: "column",
    height: "100vh",
    overflow: "hidden",
    fontFamily: "system-ui, sans-serif",
    backgroundColor: "#0b0d12",
    color: "#f4f4f5",
  },
  body: {
    display: "flex",
    flexGrow: 1,
    minHeight: 0,
  },
  graph: {
    flexGrow: 1,
    minWidth: 0,
    position: "relative",
  },
  overlayLayer: {
    position: "absolute",
    left: 16,
    top: 16,
    display: "flex",
    flexDirection: "column",
    gap: 8,
    alignItems: "flex-start",
    pointerEvents: "none",
  },
  loading: {
    paddingTop: 6,
    paddingBottom: 6,
    paddingLeft: 10,
    paddingRight: 10,
    borderRadius: 6,
    borderWidth: 1,
    borderStyle: "solid",
    borderColor: "#374151",
    backgroundColor: "rgba(15, 17, 23, 0.92)",
    color: "#e5e7eb",
    fontSize: 13,
  },
  error: {
    padding: 24,
    color: "#fca5a5",
    fontSize: 14,
  },
  errorBanner: {
    paddingTop: 6,
    paddingBottom: 6,
    paddingLeft: 10,
    paddingRight: 10,
    borderRadius: 6,
    borderWidth: 1,
    borderStyle: "solid",
    borderColor: "#7f1d1d",
    backgroundColor: "rgba(69, 10, 10, 0.92)",
    color: "#fca5a5",
    fontSize: 13,
    maxWidth: 560,
  },
  sidebar: {
    width: 280,
    flexShrink: 0,
    display: "flex",
    flexDirection: "column",
    gap: 18,
    padding: 16,
    overflowY: "auto",
    borderLeftWidth: 1,
    borderLeftStyle: "solid",
    borderLeftColor: "#1f2937",
    backgroundColor: "#0f1117",
  },
  reuseControl: {
    display: "flex",
    flexDirection: "column",
    gap: 6,
    paddingBottom: 12,
    borderBottomWidth: 1,
    borderBottomStyle: "solid",
    borderBottomColor: "#374151",
    fontSize: 12,
    color: "#d1d5db",
  },
  reuseButton: {
    alignSelf: "flex-start",
    borderWidth: 1,
    borderStyle: "solid",
    borderColor: "#4b5563",
    borderRadius: 4,
    paddingTop: 4,
    paddingBottom: 4,
    paddingLeft: 8,
    paddingRight: 8,
    backgroundColor: "#1f2937",
    color: "#e5e7eb",
    cursor: "pointer",
  },
});

export function App({ controller }: { controller: SessionController }) {
  const [shadeReuse, setShadeReuse] = useAtom(reuseShadingAtom);
  const state = useSyncExternalStore(controller.subscribe, controller.getSnapshot, controller.getSnapshot);
  const { session } = state;
  const loading = state.status === "loading" || state.status === "booting";
  const selected = state.options.find((option) => option.value === state.selectedValue);
  const loadingText =
    selected === undefined ? "Loading the world list…" : `Loading ${datasetLabel(selected)}…`;
  return (
    <main {...stylex.props(styles.root)}>
      <Header
        state={state}
        onSelect={(value) => {
          void controller.select(value);
        }}
      />
      <div {...stylex.props(styles.body)}>
        <div {...stylex.props(styles.graph)} data-testid="graph">
          {session === null ? null : (
            <GraphView key={`${session.entry.snapshotId}:${session.sessionRevision}`} session={session} />
          )}
          {loading ? (
            <div {...stylex.props(styles.overlayLayer)}>
              <output {...stylex.props(styles.loading)} data-testid="loading">
                {loadingText}
              </output>
            </div>
          ) : null}
          {state.error !== null && session !== null ? (
            <div {...stylex.props(styles.overlayLayer)}>
              <span {...stylex.props(styles.errorBanner)} role="alert" data-testid="switch-error">
                {state.error}
              </span>
            </div>
          ) : null}
          {session === null && !loading ? (
            <p {...stylex.props(styles.error)} role="alert" data-testid="error">
              {state.error ?? "No dataset loaded."}
            </p>
          ) : null}
        </div>
        <aside {...stylex.props(styles.sidebar)}>
          {session?.physical === null || session === null ? null : (
            <section {...stylex.props(styles.reuseControl)} aria-label="Physical reuse">
              <button
                type="button"
                role="switch"
                aria-checked={shadeReuse}
                data-testid="reuse-shading"
                {...stylex.props(styles.reuseButton)}
                onClick={() => setShadeReuse(!shadeReuse)}
              >
                Physical reuse shading {shadeReuse ? "on" : "off"}
              </button>
              <span>Oklab lightness · darker = less reuse · lighter = more reuse</span>
              <span>{session.physical.seeds.length} measured files and symbols · depth 7</span>
            </section>
          )}
          <RelationFilter />
          <DepthControl />
          <Details session={session} />
          <FamilyEdges session={session} />
          <Legend />
        </aside>
      </div>
    </main>
  );
}
