/**
 * Entry point. Installs the diagnostics hook, creates the SessionController
 * (which bootstraps the self-hosted DuckDB, loads the manifest and the default
 * world, and owns every later dataset switch), and renders the app. The
 * controller publishes the diagnostics; this module adopts each new session's
 * graph into the Jotai store, which prunes any pinned selection id the new graph
 * does not contain. If the first load fails the shell renders a readable error
 * and the diagnostics hook keeps it; no blank page.
 */
import { Provider, createStore } from "jotai";
import { StrictMode } from "react";
import { createRoot } from "react-dom/client";

// Side-effect CSS import: the linked stylesheet. @stylexjs/unplugin appends the
// compiled StyleX rules to this asset (see app/src/styles.css).
import "./styles.css";

import { App } from "./App.tsx";
import { adoptGraphAtom, sessionRevisionAtom, topologyRevisionAtom } from "./atoms.ts";
import { SessionController } from "./controller.ts";
import { installDiagnostics } from "./diagnostics.ts";
import type { GraphSession } from "./session.ts";

function mount(controller: SessionController): void {
  const container = document.getElementById("root");
  if (container === null) throw new Error("missing #root");
  const store = createStore();
  let adopted: GraphSession | null = null;
  controller.subscribe(() => {
    const { session } = controller.getSnapshot();
    if (session === null || session === adopted) return;
    adopted = session;
    // The loaded graph is the reactive identity the derived atoms read; adopting
    // it also drops any pinned selection ids the graph does not contain.
    store.set(adoptGraphAtom, session.graph);
    store.set(sessionRevisionAtom, session.sessionRevision);
    store.set(topologyRevisionAtom, session.topologyRevision);
  });
  createRoot(container).render(
    <StrictMode>
      <Provider store={store}>
        <App controller={controller} />
      </Provider>
    </StrictMode>,
  );
}

async function run(): Promise<void> {
  installDiagnostics();
  const controller = new SessionController();
  mount(controller);
  await controller.start();
}

void run();
