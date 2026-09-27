/**
 * The application shell. The graph owns most of the viewport; a compact sidebar
 * holds the overlay control, the hovered entity's details, and the generated
 * legend. The session (graph data) is created before this renders and passed in.
 */
import * as stylex from "@stylexjs/stylex";

import { Details } from "./Details.tsx";
import { GraphView } from "./GraphView.tsx";
import { Header } from "./Header.tsx";
import { Legend } from "./Legend.tsx";
import { OverlayControl } from "./OverlayControl.tsx";
import type { GraphSession } from "./session.ts";

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
  error: {
    padding: 24,
    color: "#fca5a5",
    fontSize: 14,
  },
});

export function App({ session, error }: { session: GraphSession | null; error?: string | null }) {
  return (
    <main {...stylex.props(styles.root)}>
      <Header session={session} />
      <div {...stylex.props(styles.body)}>
        <div {...stylex.props(styles.graph)} data-testid="graph">
          {session === null ? (
            <p {...stylex.props(styles.error)}>
              {error === undefined || error === null
                ? "Loading the default world…"
                : `Could not load the default world: ${error}`}
            </p>
          ) : (
            <GraphView session={session} />
          )}
        </div>
        <aside {...stylex.props(styles.sidebar)}>
          <OverlayControl />
          <Details session={session} />
          <Legend />
        </aside>
      </div>
    </main>
  );
}
