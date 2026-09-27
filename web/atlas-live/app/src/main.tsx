/**
 * Entry point. Bootstraps the GraphSession (self-hosted DuckDB + the default
 * bundled world) outside React, publishes the initial diagnostics, then renders
 * the app. If bootstrapping fails the shell renders a readable error and the
 * diagnostics hook keeps it; no blank page.
 */
import { Provider, createStore } from "jotai";
import { StrictMode } from "react";
import { createRoot } from "react-dom/client";

// Side-effect CSS import: the linked stylesheet. @stylexjs/unplugin appends the
// compiled StyleX rules to this asset (see app/src/styles.css).
import "./styles.css";

import { App } from "./App.tsx";
import { createLocalDuckDB } from "./duckdb.ts";
import { installDiagnostics, publish } from "./diagnostics.ts";
import { GraphSession, LINKS_TABLE, POINTS_TABLE } from "./session.ts";
import { chooseDefaultWorld, fetchManifest, loadWorld } from "./world.ts";

function render(session: GraphSession | null, error: string | null): void {
  const container = document.getElementById("root");
  if (container === null) throw new Error("missing #root");
  const store = createStore();
  createRoot(container).render(
    <StrictMode>
      <Provider store={store}>
        <App error={error} session={session} />
      </Provider>
    </StrictMode>,
  );
}

async function boot(): Promise<GraphSession> {
  const start = performance.now();
  const db = await createLocalDuckDB();
  const afterDuckDb = performance.now();
  const manifest = await fetchManifest();
  const entry = chooseDefaultWorld(manifest);
  const loaded = await loadWorld(entry);
  const afterProjection = performance.now();
  await db.connection.insertArrowTable(loaded.tables.points, { name: POINTS_TABLE });
  await db.connection.insertArrowTable(loaded.tables.links, { name: LINKS_TABLE });
  const afterInsert = performance.now();
  const session = new GraphSession({ duckdb: db, entry, graph: loaded.graph });
  publish({
    snapshotId: loaded.graph.provenance.snapshotId,
    dataset: {
      repository: entry.repository,
      baseRevision: entry.baseRevision,
      synthetic: false,
    },
    sessionRevision: session.sessionRevision,
    topologyRevision: session.topologyRevision,
    counts: {
      points: entry.counts.points,
      links: entry.counts.links,
      files: entry.counts.files,
      symbols: entry.counts.symbols,
      directories: entry.counts.directories,
      defines: entry.counts.defines,
      imports: entry.counts.imports,
      calls: entry.counts.calls,
      parent: entry.counts.parent,
    },
    perf: {
      duckDbMs: Math.round(afterDuckDb - start),
      projectionMs: Math.round(afterProjection - afterDuckDb),
      insertMs: Math.round(afterInsert - afterProjection),
    },
  });
  return session;
}

async function run(): Promise<void> {
  installDiagnostics();
  try {
    const session = await boot();
    render(session, null);
  } catch (cause) {
    const message = cause instanceof Error ? cause.message : String(cause);
    publish({ ready: false, error: message });
    render(null, message);
  }
}

void run();
