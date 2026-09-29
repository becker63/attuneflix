/** Measured depth-seven anchor evidence beside a depth-one-to-three graph trace. */
import * as stylex from "@stylexjs/stylex";
import { useAtomValue, useSetAtom } from "jotai";
import { useEffect, useMemo, useSyncExternalStore } from "react";

import type { AnchorMass, AnchorScenario } from "../../projection/src/anchors.ts";
import { landscapeDepthAtom, selectedAnchorPathAtom } from "./atoms.ts";
import { incomingAnchorTrace } from "./frontier/anchorTrace.ts";
import { inspectWire } from "./frontier/inspector.ts";
import type { ProjectedDependency } from "./frontier/wires.ts";
import type { GraphSession } from "./session.ts";

const styles = stylex.create({
  root: { display: "flex", flexDirection: "column", gap: 11, color: "#eee3ea", fontSize: 13 },
  heading: { margin: 0, fontSize: 17, color: "#fff4fa" },
  note: { margin: 0, color: "#cbbbc7", lineHeight: 1.4 },
  list: { display: "flex", flexDirection: "column", gap: 3 },
  button: {
    width: "100%",
    display: "flex",
    justifyContent: "space-between",
    gap: 10,
    borderWidth: 1,
    borderStyle: "solid",
    borderColor: "rgba(255,255,255,.15)",
    borderRadius: 4,
    paddingTop: 8,
    paddingBottom: 8,
    paddingLeft: 8,
    paddingRight: 8,
    backgroundColor: "rgba(255,255,255,.04)",
    color: "#f5e8ef",
    fontFamily: "inherit",
    fontSize: 12,
    textAlign: "left",
    cursor: "pointer",
  },
  selected: { borderColor: "#f4c783", backgroundColor: "#5b3048" },
  path: { overflowWrap: "anywhere" },
  number: { flexShrink: 0, fontVariantNumeric: "tabular-nums", fontWeight: 700 },
  section: {
    borderTopWidth: 1,
    borderTopStyle: "solid",
    borderTopColor: "rgba(255,255,255,.2)",
    paddingTop: 10,
    display: "flex",
    flexDirection: "column",
    gap: 6,
  },
  subheading: { margin: 0, fontSize: 13, color: "#ffe1ee" },
  stat: { display: "flex", justifyContent: "space-between", gap: 10, fontVariantNumeric: "tabular-nums" },
  value: { textAlign: "right", color: "#fff4fa" },
  small: { color: "#cbbbc7", fontSize: 11, lineHeight: 1.4 },
  choices: { display: "flex", gap: 6 },
  depth: {
    borderWidth: 1,
    borderStyle: "solid",
    borderColor: "rgba(255,255,255,.25)",
    borderRadius: 4,
    backgroundColor: "rgba(255,255,255,.05)",
    color: "#f5e8ef",
    fontFamily: "inherit",
    fontSize: 12,
    paddingTop: 6,
    paddingBottom: 6,
    paddingLeft: 10,
    paddingRight: 10,
    cursor: "pointer",
  },
  summary: { cursor: "pointer", fontWeight: 600 },
});

function percent(value: number): string {
  return `${(value * 100).toFixed(2)}%`;
}
function ratio(value: number): string {
  return `${value.toFixed(2)}×`;
}
function signed(before: number, after: number): string {
  const delta = after - before;
  return `${delta >= 0 ? "+" : ""}${delta.toFixed(2)}×`;
}
function massLine(mass: AnchorMass | undefined, kind: "unique" | "weighted"): string {
  if (mass === undefined) return "unmeasured";
  return kind === "unique"
    ? `${percent(mass.uniqueFraction)} · ${mass.uniqueContaining.toLocaleString()} / ${mass.uniqueLiveStates.toLocaleString()}`
    : `${percent(mass.weightedFraction)} · ${mass.weightedContaining.toLocaleString()} / ${mass.liveObservations.toLocaleString()}`;
}
function pointLabel(session: GraphSession, id: string): string {
  const index = session.graph.indexById.get(id);
  return index === undefined
    ? id
    : (session.graph.pointPaths[index] ??
        session.graph.pointNames[index] ??
        session.graph.pointLabels[index] ??
        id);
}
function scenario(
  rows: readonly AnchorScenario[],
  path: string,
  domain: "file" | "symbol",
): AnchorScenario | undefined {
  return rows.find((row) => row.path === path && row.domain === domain);
}

/** Compare peer regions; nested children remain selectable on the graph. */
function rankedPeers(masses: readonly AnchorMass[], measuredBoundary: string | null): readonly AnchorMass[] {
  const eligible = masses.filter(
    (row) => row.domain === "symbol" && row.path.includes("/") && row.weightedContaining > 0,
  );
  const shallowest = eligible.reduce((depth, row) => Math.min(depth, row.path.split("/").length), Infinity);
  const peers = eligible
    .filter((row) => row.path.split("/").length === shallowest)
    .toSorted((a, b) => a.rank - b.rank || a.path.localeCompare(b.path))
    .slice(0, 8);
  const boundary = masses.find((row) => row.domain === "symbol" && row.path === measuredBoundary);
  return boundary === undefined
    ? peers
    : [boundary, ...peers.filter((row) => row.path !== boundary.path)].slice(0, 8);
}

export function AnchorPanel({ session }: { session: GraphSession }) {
  const data = session.anchors;
  const view = useSyncExternalStore(session.subscribeView, session.getViewSnapshot, session.getViewSnapshot);
  const depth = useAtomValue(landscapeDepthAtom);
  const setDepth = useSetAtom(landscapeDepthAtom);
  const selectedPath = useAtomValue(selectedAnchorPathAtom);
  const setSelectedPath = useSetAtom(selectedAnchorPathAtom);
  const measuredBoundary = data?.scenarios.find((row) => row.intervention === "masked")?.path ?? null;
  const ranking = useMemo(() => rankedPeers(data?.masses ?? [], measuredBoundary), [data, measuredBoundary]);
  const selected = selectedPath === null ? null : (data?.byPath.get(selectedPath) ?? null);
  const directoryStart = session.graph.fileCount + session.graph.symbolCount;
  const anchorIndex =
    selectedPath === null
      ? -1
      : session.graph.pointPaths.findIndex((path, index) => index >= directoryStart && path === selectedPath);
  const anchorId = anchorIndex < 0 ? null : (session.graph.pointIds[anchorIndex] ?? null);
  useEffect(() => {
    if (anchorId !== null) void session.revealOrigin(anchorId);
  }, [session, anchorId]);
  const trace = useMemo(
    () => (anchorId === null ? null : incomingAnchorTrace(view.projection, anchorId, depth)),
    [view.projection, anchorId, depth],
  );
  const directEvidence = useMemo(
    () =>
      trace === null
        ? []
        : [...trace.wireIndices]
            .map((index) => view.projection.wires[index])
            .filter(
              (wire): wire is ProjectedDependency => wire !== undefined && wire.target === trace.anchorId,
            )
            .slice(0, 12)
            .map((wire) => inspectWire(session.graph, wire, 2)),
    [trace, view.projection, session.graph],
  );
  const file = selected?.find((row) => row.domain === "file");
  const symbol = selected?.find((row) => row.domain === "symbol");
  const baselineFile = data === null ? undefined : scenario(data.scenarios, "", "file");
  const baselineSymbol = data === null ? undefined : scenario(data.scenarios, "", "symbol");
  const maskedFile =
    selectedPath === null || data === null ? undefined : scenario(data.scenarios, selectedPath, "file");
  const maskedSymbol =
    selectedPath === null || data === null ? undefined : scenario(data.scenarios, selectedPath, "symbol");

  if (data === null) return null;
  return (
    <section aria-label="Anchor concentration" data-testid="anchor-panel" {...stylex.props(styles.root)}>
      <h2 {...stylex.props(styles.heading)}>Anchor concentration</h2>
      <p {...stylex.props(styles.note)}>
        Where the measured live Atlas states repeatedly contain a repository region.
      </p>
      <div {...stylex.props(styles.list)} aria-label="Ranked architectural anchors">
        {ranking.map((row, index) => (
          <button
            key={row.path}
            type="button"
            data-testid="anchor-option"
            aria-pressed={selectedPath === row.path}
            onClick={() => setSelectedPath(row.path)}
            {...stylex.props(styles.button, selectedPath === row.path && styles.selected)}
          >
            <span {...stylex.props(styles.path)}>
              {String(index + 1).padStart(2, "0")} · {row.path}
            </span>
            <span {...stylex.props(styles.number)}>{percent(row.weightedFraction)}</span>
          </button>
        ))}
      </div>
      <span {...stylex.props(styles.small)}>
        The measured counterfactual boundary appears first; then peer regions are ranked by live Symbol
        observation mass. Nested paths remain selectable on the graph; the typed artifact retains every
        directory candidate.
      </span>
      {selectedPath !== null && (
        <button type="button" {...stylex.props(styles.depth)} onClick={() => setSelectedPath(null)}>
          Clear anchor highlight
        </button>
      )}
      {selectedPath === null ? null : (
        <>
          <div {...stylex.props(styles.section)}>
            <h3 {...stylex.props(styles.subheading, styles.path)}>{selectedPath}</h3>
            <div {...stylex.props(styles.stat)}>
              <span>Contained files</span>
              <strong {...stylex.props(styles.value)}>
                {symbol?.containedFiles.toLocaleString() ?? "—"}
              </strong>
            </div>
            <div {...stylex.props(styles.stat)}>
              <span>Crossing dependencies</span>
              <strong {...stylex.props(styles.value)}>{symbol?.crossingEdges.toLocaleString() ?? "—"}</strong>
            </div>
            <span {...stylex.props(styles.small)}>
              Depth-7 frozen 16-seed panel · non-empty File and Symbol states counted separately
            </span>
            <div {...stylex.props(styles.stat)}>
              <span>Symbol · unique states</span>
              <strong {...stylex.props(styles.value)}>{massLine(symbol, "unique")}</strong>
            </div>
            <div {...stylex.props(styles.stat)}>
              <span>Symbol · observations</span>
              <strong {...stylex.props(styles.value)}>{massLine(symbol, "weighted")}</strong>
            </div>
            <div {...stylex.props(styles.stat)}>
              <span>File · unique states</span>
              <strong {...stylex.props(styles.value)}>{massLine(file, "unique")}</strong>
            </div>
            <div {...stylex.props(styles.stat)}>
              <span>File · observations</span>
              <strong {...stylex.props(styles.value)}>{massLine(file, "weighted")}</strong>
            </div>
          </div>
          <div {...stylex.props(styles.section)}>
            <h3 {...stylex.props(styles.subheading)}>Visible incoming dependency paths</h3>
            <div {...stylex.props(styles.choices)} aria-label="Anchor trace depth">
              {([1, 2, 3] as const).map((value) => (
                <button
                  key={value}
                  type="button"
                  aria-pressed={depth === value}
                  onClick={() => setDepth(value)}
                  {...stylex.props(styles.depth, depth === value && styles.selected)}
                >
                  {value}°
                </button>
              ))}
            </div>
            <div {...stylex.props(styles.stat)}>
              <span>Reaching visible nodes</span>
              <strong {...stylex.props(styles.value)}>
                {trace?.incomingIds.size.toLocaleString() ?? "0"}
              </strong>
            </div>
            <div {...stylex.props(styles.stat)}>
              <span>Direct sources / backing edges</span>
              <strong {...stylex.props(styles.value)}>
                {trace?.directSources.size.toLocaleString() ?? "0"} /{" "}
                {trace?.directBackingEdges.toLocaleString() ?? "0"}
              </strong>
            </div>
            <span {...stylex.props(styles.small)}>
              Projected Imports/Calls only. The highlighted wires retain exact backing-edge multiplicity and
              provenance. Containment alone creates no dependency.
            </span>
            <details>
              <summary {...stylex.props(styles.summary)}>Contributing visible sources</summary>
              {[...(trace?.directSources ?? [])].slice(0, 12).map((id) => (
                <div key={id} {...stylex.props(styles.path, styles.small)}>
                  {pointLabel(session, id)}
                </div>
              ))}
              {(trace?.directSources.size ?? 0) > 12 && (
                <span {...stylex.props(styles.small)}>+{(trace?.directSources.size ?? 0) - 12} more</span>
              )}
            </details>
            <details>
              <summary {...stylex.props(styles.summary)}>Backing dependency evidence</summary>
              {directEvidence.map((wire) => (
                <div
                  key={`${wire.sourceId}:${wire.targetId}:${wire.relation}`}
                  {...stylex.props(styles.path, styles.small)}
                >
                  {wire.source} → {wire.target} · {wire.relation} · {wire.multiplicity.toLocaleString()} exact
                  rows
                  {wire.contributions.map((row) => (
                    <div key={row.row}>
                      row {row.row}: {row.source} → {row.target}
                    </div>
                  ))}
                  {wire.remaining > 0 && <span>+{wire.remaining.toLocaleString()} backing rows</span>}
                </div>
              ))}
              {(trace?.directSources.size ?? 0) > 12 && (
                <span {...stylex.props(styles.small)}>
                  Showing 12 projected wires; the total above includes every contributing wire.
                </span>
              )}
            </details>
          </div>
          <div {...stylex.props(styles.section)}>
            <h3 {...stylex.props(styles.subheading)}>Extinction and recurrence</h3>
            {baselineFile !== undefined && (
              <>
                <div {...stylex.props(styles.stat)}>
                  <span>File extinct</span>
                  <strong {...stylex.props(styles.value)}>
                    {baselineFile.extinctObservations.toLocaleString()} /{" "}
                    {baselineFile.observations.toLocaleString()} · {percent(baselineFile.extinctFraction)}
                  </strong>
                </div>
                <div {...stylex.props(styles.stat)}>
                  <span>File total / live recurrence</span>
                  <strong {...stylex.props(styles.value)}>
                    {ratio(baselineFile.totalRecurrence)} / {ratio(baselineFile.liveRecurrence)}
                  </strong>
                </div>
              </>
            )}
            {baselineSymbol !== undefined && (
              <div {...stylex.props(styles.stat)}>
                <span>Symbol total / live recurrence</span>
                <strong {...stylex.props(styles.value)}>
                  {ratio(baselineSymbol.totalRecurrence)} / {ratio(baselineSymbol.liveRecurrence)}
                </strong>
              </div>
            )}
            {maskedFile !== undefined &&
            maskedSymbol !== undefined &&
            baselineFile !== undefined &&
            baselineSymbol !== undefined ? (
              <>
                <span {...stylex.props(styles.small)}>
                  Boundary-mask counterfactual · same depth-7 evaluator;{" "}
                  {maskedSymbol.maskedImports.toLocaleString()} imports and{" "}
                  {maskedSymbol.maskedCalls.toLocaleString()} calls removed
                </span>
                <div {...stylex.props(styles.stat)}>
                  <span>File live recurrence Δ</span>
                  <strong {...stylex.props(styles.value)}>
                    {signed(baselineFile.liveRecurrence, maskedFile.liveRecurrence)}
                  </strong>
                </div>
                <div {...stylex.props(styles.stat)}>
                  <span>Symbol live recurrence Δ</span>
                  <strong {...stylex.props(styles.value)}>
                    {signed(baselineSymbol.liveRecurrence, maskedSymbol.liveRecurrence)}
                  </strong>
                </div>
                <div {...stylex.props(styles.stat)}>
                  <span>Symbol live states</span>
                  <strong {...stylex.props(styles.value)}>
                    {baselineSymbol.uniqueLiveStates.toLocaleString()} →{" "}
                    {maskedSymbol.uniqueLiveStates.toLocaleString()}
                  </strong>
                </div>
                <span {...stylex.props(styles.small)}>
                  A boundary mask changes the admitted graph for this experiment; it does not alter the frozen
                  repository. These structural effects do not measure task contention.
                </span>
              </>
            ) : (
              <span {...stylex.props(styles.small)}>
                No boundary-mask experiment is recorded for this anchor.
              </span>
            )}
          </div>
        </>
      )}
    </section>
  );
}
