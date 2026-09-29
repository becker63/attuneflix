/**
 * The application shell. The graph owns most of the viewport; a readable sidebar
 * holds the measurement controls, the hovered entity's details, and the generated
 * legend. The dataset lifecycle (loading, ready, error) lives in the
 * SessionController, which React reads through `useSyncExternalStore`.
 */
import * as stylex from "@stylexjs/stylex";
import { useAtomValue, useSetAtom } from "jotai";
import { useEffect, useSyncExternalStore } from "react";

import type { SessionController } from "./controller.ts";
import { landscapeModeAtom, landscapeOriginsAtom, measurementModeAtom, setMeasurementModeAtom } from "./atoms.ts";
import { datasetLabel } from "./datasets.ts";
import { Details } from "./Details.tsx";
import { DepthControl } from "./DepthControl.tsx";
import { GraphView } from "./GraphView.tsx";
import { Header } from "./Header.tsx";
import { Legend } from "./Legend.tsx";
import { metricShadeRange } from "./metricShade.ts";
import { ParallelismPanel } from "./ParallelismPanel.tsx";
import { reuseShadeRange, shadeOklab } from "./physical.ts";
import { RelationFilter } from "./RelationFilter.tsx";
import { WorldComparison } from "./WorldComparison.tsx";

const REUSE_GRADIENT = `linear-gradient(to right, ${shadeOklab("#a78bfa", 0)}, ${shadeOklab("#a78bfa", 0.5)}, ${shadeOklab("#a78bfa", 1)})`;
const REUSE_GRADIENT_STYLE = { background: REUSE_GRADIENT };

const styles = stylex.create({
  root: {
    display: "flex",
    flexDirection: "column",
    height: "100vh",
    overflow: "hidden",
    fontFamily: "system-ui, sans-serif",
    backgroundColor: "transparent",
    color: "#f4f4f5",
    padding: 12,
    gap: 12,
  },
  body: {
    display: "flex",
    flexGrow: 1,
    minHeight: 0,
    gap: 12,
  },
  graph: {
    flexGrow: 1,
    minWidth: 0,
    position: "relative",
    overflow: "hidden",
    borderRadius: 10,
    backgroundColor: "rgba(0, 0, 0, 0.86)",
    boxShadow: "#00000f 0 0 10px",
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
    borderRadius: 10,
    borderWidth: 1,
    borderStyle: "solid",
    borderColor: "#374151",
    backgroundColor: "rgba(0, 0, 0, 0.7)",
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
    width: 360,
    flexShrink: 0,
    display: "flex",
    flexDirection: "column",
    gap: 22,
    padding: 20,
    overflowY: "auto",
    borderRadius: 10,
    backgroundColor: "rgba(0, 0, 0, 0.78)",
    boxShadow: "#00000f 0 0 10px",
  },
  parallelSidebar: { gap: 14, padding: 16 },
  sidebarDisclosure: { borderTopWidth: 1, borderTopStyle: "solid",
    borderTopColor: "rgba(255,255,255,.2)", paddingTop: 8, fontSize: 13 },
  sidebarSummary: { cursor: "pointer", fontWeight: 600, color: "#eee3ea" },
  reuseControl: {
    display: "flex",
    flexDirection: "column",
    gap: 10,
    paddingBottom: 18,
    borderBottomWidth: 1,
    borderBottomStyle: "solid",
    borderBottomColor: "#374151",
    fontSize: 13,
    lineHeight: 1.4,
    color: "#e5dce3",
  },
  controlHeading: {
    fontSize: 13,
    fontWeight: 700,
    letterSpacing: 0.4,
    color: "#fff4fa",
  },
  shadeChoices: {
    display: "grid",
    gridTemplateColumns: "repeat(2, minmax(0, 1fr))",
    gap: 8,
  },
  reuseScale: {
    margin: 0,
    width: "100%",
    height: 20,
    borderRadius: 4,
    borderWidth: 1,
    borderStyle: "solid",
    borderColor: "rgba(255, 255, 255, 0.35)",
  },
  reuseScaleLabels: {
    display: "flex",
    justifyContent: "space-between",
    fontVariantNumeric: "tabular-nums",
    color: "#d1d5db",
  },
  reuseButton: {
    minHeight: 42,
    textAlign: "left",
    fontFamily: "inherit",
    fontSize: 13,
    fontWeight: 600,
    borderWidth: 1,
    borderStyle: "solid",
    borderColor: "rgba(255, 255, 255, 0.22)",
    borderRadius: 6,
    paddingTop: 9,
    paddingBottom: 9,
    paddingLeft: 10,
    paddingRight: 10,
    backgroundColor: "rgba(255, 255, 255, 0.05)",
    color: "#e8dce4",
    cursor: "pointer",
  },
  shadeSelected: {
    borderColor: "#f0a4c8",
    backgroundColor: "#5b3048",
    color: "#fff4fa",
  },
});

export function App({ controller }: { controller: SessionController }) {
  const landscapeMode = useAtomValue(landscapeModeAtom);
  const setLandscapeMode = useSetAtom(landscapeModeAtom);
  const setLandscapeOrigins = useSetAtom(landscapeOriginsAtom);
  const measurementMode = useAtomValue(measurementModeAtom);
  const setMeasurementMode = useSetAtom(setMeasurementModeAtom);
  const state = useSyncExternalStore(controller.subscribe, controller.getSnapshot, controller.getSnapshot);
  const { session } = state;
  const loading = state.status === "loading" || state.status === "booting";
  const selected = state.options.find((option) => option.value === state.selectedValue);
  useEffect(() => {
    if (session !== null) setLandscapeOrigins({ a: null, b: null });
  }, [session, setLandscapeOrigins]);
  useEffect(() => {
    if (session !== null && session.physical === null && measurementMode === "physical") {
      setMeasurementMode("structure");
    }
  }, [session, measurementMode, setMeasurementMode]);
  const loadingText =
    selected === undefined ? "Loading the world list…" : `Loading ${datasetLabel(selected)}…`;
  const scalarRange =
    session === null ? null : metricShadeRange(session.projectionMetrics(), measurementMode);
  const physicalRange = session?.physical ? reuseShadeRange(session.physical) : null;
  const shadingLabel = measurementMode === "structure"
    ? session?.families === null ? "Structure" : "Family + structure"
    : measurementMode === "physical" ? "Physical reuse"
    : measurementMode === "locality" ? "Locality" : "Reach";
  const shadeChoices = session === null ? null : <div {...stylex.props(styles.shadeChoices)}>
    {(["structure", "locality", "reach", "physical"] as const).map((mode) => (
      <button
        key={mode}
        type="button"
        aria-pressed={measurementMode === mode}
        data-testid={mode === "physical" ? "reuse-shading" : undefined}
        disabled={mode === "physical" && session.physical === null}
        {...stylex.props(styles.reuseButton, measurementMode === mode && styles.shadeSelected)}
        onClick={() => setMeasurementMode(mode)}
      >
        {mode === "structure"
          ? session.families === null ? "Structure" : "Family + structure"
          : mode === "locality" ? "Locality"
          : mode === "reach" ? "Reach" : "Physical reuse"}
      </button>
    ))}
  </div>;
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
        <aside {...stylex.props(styles.sidebar, landscapeMode === "parallelism" && styles.parallelSidebar)}>
          {session === null ? null : <section {...stylex.props(styles.reuseControl)} aria-label="Atlas Live mode">
            <span {...stylex.props(styles.controlHeading)}>Explore the same graph</span>
            <div {...stylex.props(styles.shadeChoices)}>
              {(["structure", "parallelism"] as const).map((mode) => <button key={mode} type="button"
                data-testid={`${mode}-mode`} aria-pressed={landscapeMode === mode}
                {...stylex.props(styles.reuseButton, landscapeMode === mode && styles.shadeSelected)}
                onClick={() => setLandscapeMode(mode)}>
                {mode === "structure" ? "Structure + families" : "Structural separation"}
              </button>)}
            </div>
          </section>}
          {session === null ? null : (
            <section {...stylex.props(styles.reuseControl)} aria-label="Graph shading">
              {landscapeMode === "parallelism" ? <details {...stylex.props(styles.sidebarDisclosure)}>
                <summary {...stylex.props(styles.sidebarSummary)}>Color · {shadingLabel}</summary>
                {shadeChoices}
              </details> : <>
                <span {...stylex.props(styles.controlHeading)}>Color the graph</span>
                {shadeChoices}
              </>}
              {landscapeMode === "structure" && <span>
                {session.families === null
                  ? "One graph · structural placement"
                  : "One graph · family hue and structural placement"}
              </span>}
              {landscapeMode === "structure" && measurementMode === "structure" ? (
                <span>Families tint the fixed structural layout wherever recorded.</span>
              ) : null}
              {landscapeMode === "structure" && measurementMode === "physical" && session.physical !== null && physicalRange !== null ? (
                <>
                  <span>Physical transition reuse</span>
                  <figure
                    {...stylex.props(styles.reuseScale)}
                    style={REUSE_GRADIENT_STYLE}
                    aria-label="Dark to bright Oklab scale for low to high physical transition reuse"
                  />
                  <span {...stylex.props(styles.reuseScaleLabels)}>
                    <span>{(physicalRange.low * 100).toFixed(2)}% · less</span>
                    <span>{(((physicalRange.low + physicalRange.high) / 2) * 100).toFixed(2)}%</span>
                    <span>{(physicalRange.high * 100).toFixed(2)}% · more</span>
                  </span>
                  <span>
                    Colors rescale to each world's 5th–95th percentiles; inspected nodes show exact values.
                    Compare worlds by the percentages below.
                  </span>
                  <span>{session.physical.seeds.length} measured files and symbols · depth 7</span>
                </>
              ) : null}
              {landscapeMode === "parallelism" || scalarRange === null ? null : (
                <>
                  <span>
                    {measurementMode === "locality"
                      ? "Internal share of region edges"
                      : "Directed regions reached within 3 hops"}
                  </span>
                  <figure
                    {...stylex.props(styles.reuseScale)}
                    style={REUSE_GRADIENT_STYLE}
                    aria-label="Dark to bright Oklab metric scale"
                  />
                  <span {...stylex.props(styles.reuseScaleLabels)}>
                    <span>
                      {measurementMode === "locality"
                        ? `${(scalarRange.low * 100).toFixed(1)}%`
                        : scalarRange.low.toLocaleString()}{" "}
                      · less
                    </span>
                    <span>
                      {measurementMode === "locality"
                        ? `${(scalarRange.high * 100).toFixed(1)}%`
                        : scalarRange.high.toLocaleString()}{" "}
                      · more
                    </span>
                  </span>
                  <span>
                    The displayed range is the 5th–95th percentile; the inspector shows exact metrics.
                  </span>
                </>
              )}
            </section>
          )}
          {session !== null && landscapeMode === "parallelism" ? <ParallelismPanel session={session} /> : null}
          {landscapeMode === "parallelism" ? <details {...stylex.props(styles.sidebarDisclosure)}>
            <summary {...stylex.props(styles.sidebarSummary)}>Compare repositories</summary>
            <WorldComparison state={state} onSelect={(value) => { void controller.select(value); }} />
          </details> : <WorldComparison
            state={state}
            onSelect={(value) => { void controller.select(value); }}
          />}
          <RelationFilter showInspectionPaths={landscapeMode === "structure"} />
          {landscapeMode === "parallelism" ? <details {...stylex.props(styles.sidebarDisclosure)}>
            <summary {...stylex.props(styles.sidebarSummary)}>Graph legend</summary>
            <Legend />
          </details> : <Legend />}
          {landscapeMode === "structure" ? <DepthControl /> : null}
          {landscapeMode === "structure" ? <Details session={session} /> : null}
        </aside>
      </div>
    </main>
  );
}
