/**
 * The one persistent Cosmograph instance. It is fed by the session's Arrow tables
 * through our own DuckDB connection (table names, precomputed index columns), so
 * the renderer never resolves ids itself and never re-ingests data for an
 * overlay or a relation filter.
 *
 * Emphasis uses the renderer's selection/greyout channel with the sets computed
 * from the projected adjacency: hover, the pinned selection (re-applied whenever
 * the pointer leaves a point), and the active filter and depth all come from
 * Jotai atoms, so clicking a point pins it independently of hover.
 */
import { Cosmograph } from "@cosmograph/react";
import * as stylex from "@stylexjs/stylex";
import { useAtomValue, useSetAtom } from "jotai";
import { useEffect, useMemo, useRef, useState, useSyncExternalStore } from "react";

import { RELATION_ORDER } from "../../projection/src/relation.ts";
import {
  clearSelectionAtom,
  drillFamilyEdgeAtom,
  drilledFamilyEdgeAtom,
  emphasisAtom,
  filterRevisionAtom,
  hoveredIndexAtom,
  landscapeDepthAtom,
  landscapeModeAtom,
  landscapeOriginsAtom,
  landscapeThresholdAtom,
  measurementModeAtom,
  measurementRevisionAtom,
  neighbourhoodDepthAtom,
  readyAtom,
  selectWireAtom,
  selectedWireAtom,
  selectOnlyAtom,
  selectLandscapeOriginAtom,
  selectedAtom,
  toggleSelectedAtom,
  visibleRelationSetAtom,
} from "./atoms.ts";
import { publish, setDiagnosticsSource } from "./diagnostics.ts";
import { LINK_RENDER_BUDGET } from "./datasets.ts";
import { reapplyEmphasis, setEmphasis } from "./emphasis.ts";
import { familyMembership, familyPointColor } from "./families.ts";
import { frontierLevel } from "./frontier/frontier.ts";
import { inspectWire } from "./frontier/inspector.ts";
import { convergenceGraph, greedySeparatedSet, neighborhoodIds, neighborhoodIndex } from "./frontier/parallelism.ts";
import { isWireRelation, projectedWireWidth } from "./frontier/wires.ts";
import {
  clearMountedCosmograph,
  mountedCosmograph,
  onBackgroundClick,
  onGraphMount,
  onGraphDrag,
  onGraphRebuilt,
  onLinkClick,
  onPointClick,
  onPointMouseOut,
  onPointMouseOver,
  onZoom,
  setGraphHandlers,
  type MountedCosmograph,
} from "./graphHandlers.ts";
import { highlightIds } from "./neighbourhood.ts";
import { metricShadeRange, metricValue, scalarPosition, type ScalarRange } from "./metricShade.ts";
import {
  basePointColor,
  physicalPointColor,
  regionReuse,
  reuseShadePosition,
  shadeOklab,
} from "./physical.ts";
import { sortedSelection } from "./selection.ts";
import type { GraphSession } from "./session.ts";
import { pointColorMap, relationColor } from "./vocabulary.ts";
import { viewportWires, zoomWireBudget } from "./zoomWires.ts";
import type { MeasurementMode } from "./atoms.ts";

const styles = stylex.create({
  root: {
    position: "relative",
    width: "100%",
    height: "100%",
  },
  graph: { width: "100%", height: "100%" },
  regions: { position: "absolute", pointerEvents: "none", overflow: "hidden" },
  edgeNotice: {
    position: "absolute",
    right: 16,
    top: 16,
    maxWidth: 240,
    paddingTop: 7,
    paddingBottom: 7,
    paddingLeft: 10,
    paddingRight: 10,
    borderRadius: 5,
    backgroundColor: "rgba(15, 8, 14, 0.88)",
    color: "#f5dbe9",
    fontSize: 12,
    lineHeight: 1.4,
    pointerEvents: "none",
  },
  landscapeKey: {
    position: "absolute",
    left: 12,
    top: 16,
    zIndex: 1,
    display: "flex",
    flexDirection: "column",
    gap: 5,
    width: 112,
    padding: 8,
    borderWidth: 1,
    borderStyle: "solid",
    borderColor: "rgba(255,255,255,.25)",
    borderRadius: 4,
    backgroundColor: "rgba(15,8,14,.93)",
    color: "#f3f5f7",
    fontSize: 11,
    lineHeight: 1.3,
    pointerEvents: "none",
  },
  landscapeKeyRow: { display: "flex", alignItems: "center", gap: 8 },
  landscapeKeySwatch: { width: 13, height: 13, flexShrink: 0, borderRadius: 2 },
  landscapeKeyDetail: { color: "#cbbbc7", fontSize: 11 },
});

const POINT_COLORS = pointColorMap();
const BACKGROUND = "#160c14";
const HIDDEN_LINK: [number, number, number, number] = [0, 0, 0, 0];
const REGION_LABEL_HIT_STYLE = { cursor: "pointer" } as const;
const LANDSCAPE_MARKER_BUDGET = 1500;
const LANDSCAPE_A_COLOR = "#86c7ed";
const LANDSCAPE_B_COLOR = "#dda5df";
const LANDSCAPE_SHARED_COLOR = "#f4c783";
const LANDSCAPE_SET_COLOR = "#f3f5f7";
const LANDSCAPE_A_SWATCH_STYLE = { backgroundColor: LANDSCAPE_A_COLOR };
const LANDSCAPE_B_SWATCH_STYLE = { backgroundColor: LANDSCAPE_B_COLOR };
const LANDSCAPE_SHARED_SWATCH_STYLE = { backgroundColor: LANDSCAPE_SHARED_COLOR };
const LANDSCAPE_SET_SWATCH_STYLE = { backgroundColor: LANDSCAPE_SET_COLOR };

interface ScreenRegion {
  readonly ordinal: number;
  readonly x: number;
  readonly y: number;
  readonly width: number;
  readonly height: number;
  readonly color: string;
  readonly label: string;
}

interface AxisAnchor {
  readonly index: number;
  readonly value: number;
}

interface LayoutAnchors {
  readonly minX: AxisAnchor;
  readonly maxX: AxisAnchor;
  readonly minY: AxisAnchor;
  readonly maxY: AxisAnchor;
}

interface WireWindow {
  readonly revision: number;
  readonly zoomed: boolean;
  readonly indices: ReadonlySet<number>;
}

/** Cosmograph rescales explicit point coordinates; visible point positions calibrate the regions. */
function layoutAnchors(session: GraphSession): LayoutAnchors {
  const xy = session.layout.xy;
  let minX: AxisAnchor = { index: 0, value: Infinity };
  let maxX: AxisAnchor = { index: 0, value: -Infinity };
  let minY: AxisAnchor = { index: 0, value: Infinity };
  let maxY: AxisAnchor = { index: 0, value: -Infinity };
  for (let index = 0; index < session.graph.pointCount; index++) {
    const x = xy[index * 2] ?? 0;
    const y = xy[index * 2 + 1] ?? 0;
    if (x < minX.value) minX = { index, value: x };
    if (x > maxX.value) maxX = { index, value: x };
    if (y < minY.value) minY = { index, value: y };
    if (y > maxY.value) maxY = { index, value: y };
  }
  return { minX, maxX, minY, maxY };
}

function topLevelRegions(
  session: GraphSession,
  instance: MountedCosmograph,
  anchors: LayoutAnchors,
  mode: MeasurementMode,
  range: ScalarRange | null,
): ScreenRegion[] {
  const screen = (anchor: AxisAnchor): readonly [number, number] | null => {
    const position = instance.getPointPositionByIndex(anchor.index);
    return position === undefined ? null : (instance.spaceToScreenPosition(position) ?? null);
  };
  const minX = screen(anchors.minX);
  const maxX = screen(anchors.maxX);
  const minY = screen(anchors.minY);
  const maxY = screen(anchors.maxY);
  if (minX === null || maxX === null || minY === null || maxY === null) return [];
  const xScale = (maxX[0] - minX[0]) / (anchors.maxX.value - anchors.minX.value);
  const yScale = (maxY[1] - minY[1]) / (anchors.maxY.value - anchors.minY.value);
  if (!Number.isFinite(xScale) || !Number.isFinite(yScale)) return [];
  const xOf = (value: number): number => minX[0] + (value - anchors.minX.value) * xScale;
  const yOf = (value: number): number => minY[1] + (value - anchors.minY.value) * yScale;
  const { directoryRegions, structure } = session.layout;
  const reuse =
    mode === "physical" && session.physical !== null ? regionReuse(session.layout, session.physical) : null;
  const regions: ScreenRegion[] = [];
  for (let ordinal = 0; ordinal < directoryRegions.length; ordinal++) {
    if (ordinal === structure.root || structure.directoryParent[ordinal] !== structure.root) continue;
    const region = directoryRegions[ordinal];
    if (region === undefined) continue;
    const x0 = xOf(region.x0);
    const y0 = yOf(region.y0);
    const x1 = xOf(region.x1);
    const y1 = yOf(region.y1);
    const pointIndex = session.graph.fileCount + session.graph.symbolCount + ordinal;
    const baseColor = basePointColor(session.graph, session.families, pointIndex);
    const measured = reuse?.get(ordinal);
    const metrics = range === null ? null : session.metricsFor(pointIndex);
    const metricColor =
      metrics !== null && range !== null && (mode === "locality" || mode === "reach")
        ? shadeOklab(baseColor, scalarPosition(metricValue(metrics, mode), range))
        : baseColor;
    regions.push({
      ordinal,
      x: Math.min(x0, x1),
      y: Math.min(y0, y1),
      width: Math.abs(x1 - x0),
      height: Math.abs(y1 - y0),
      color:
        measured === undefined || session.physical === null
          ? metricColor
          : shadeOklab(baseColor, reuseShadePosition(session.physical, measured.reuseFraction)),
      label: session.graph.pointLabels[pointIndex] ?? session.graph.pointPaths[pointIndex] ?? "",
    });
  }
  return regions;
}

function screenPositionOf(instance: MountedCosmograph | undefined, index: number): [number, number] | null {
  if (instance === undefined) return null;
  const space = instance.getPointPositionByIndex(index);
  if (space === undefined) return null;
  const screen = instance.spaceToScreenPosition(space);
  if (screen == null) return null;
  const canvas = instance.getCanvas();
  if (canvas === null) return null;
  const rect = canvas.getBoundingClientRect();
  return [rect.left + screen[0], rect.top + screen[1]];
}

export function GraphView({ session }: { session: GraphSession }) {
  const anchors = useMemo(() => layoutAnchors(session), [session]);
  const rootRef = useRef<HTMLDivElement>(null);
  const frameRef = useRef<number | null>(null);
  const regionUpdateRef = useRef<() => void>(() => {});
  const [regionLayer, setRegionLayer] = useState<{
    left: number;
    top: number;
    width: number;
    height: number;
    regions: ScreenRegion[];
  }>({
    left: 0,
    top: 0,
    width: 0,
    height: 0,
    regions: [],
  });
  const [wireWindow, setWireWindow] = useState<WireWindow | null>(null);
  const regionStyle = useMemo(
    () => ({
      left: regionLayer.left,
      top: regionLayer.top,
      width: regionLayer.width,
      height: regionLayer.height,
    }),
    [regionLayer],
  );
  const view = useSyncExternalStore(session.subscribeView, session.getViewSnapshot, session.getViewSnapshot);
  const setHoveredIndex = useSetAtom(hoveredIndexAtom);
  const setReady = useSetAtom(readyAtom);
  const setSelectedOnly = useSetAtom(selectOnlyAtom);
  const setToggleSelected = useSetAtom(toggleSelectedAtom);
  const setLandscapeOrigin = useSetAtom(selectLandscapeOriginAtom);
  const setLandscapeOrigins = useSetAtom(landscapeOriginsAtom);
  const selectWire = useSetAtom(selectWireAtom);
  const clearSelection = useSetAtom(clearSelectionAtom);

  const hovered = useAtomValue(hoveredIndexAtom);
  const emphasis = useAtomValue(emphasisAtom);
  const selected = useAtomValue(selectedAtom);
  const landscapeMode = useAtomValue(landscapeModeAtom);
  const landscapeDepth = useAtomValue(landscapeDepthAtom);
  const landscapeOrigins = useAtomValue(landscapeOriginsAtom);
  const landscapeThreshold = useAtomValue(landscapeThresholdAtom);
  const landscapeModeRef = useRef(landscapeMode);
  useEffect(() => { landscapeModeRef.current = landscapeMode; }, [landscapeMode]);
  const selectedWire = useAtomValue(selectedWireAtom);
  const visibleRelations = useAtomValue(visibleRelationSetAtom);
  const depth = useAtomValue(neighbourhoodDepthAtom);
  const filterRevision = useAtomValue(filterRevisionAtom);
  const measurementRevision = useAtomValue(measurementRevisionAtom);
  const drill = useAtomValue(drilledFamilyEdgeAtom);
  const setDrill = useSetAtom(drillFamilyEdgeAtom);
  const families = session.families;
  const measurementMode = useAtomValue(measurementModeAtom);
  const landscapeIndex = useMemo(
    () => landscapeMode === "parallelism" ? neighborhoodIndex(view.projection, session.containment) : null,
    [landscapeMode, view.projection, session.containment],
  );
  const landscapeA = landscapeIndex?.ordinalById.has(landscapeOrigins.a ?? "") ? landscapeOrigins.a : null;
  const landscapeB = landscapeIndex?.ordinalById.has(landscapeOrigins.b ?? "") ? landscapeOrigins.b : null;
  const landscapeGraph = useMemo(() => landscapeIndex === null ? null
    : convergenceGraph(landscapeIndex, landscapeDepth, landscapeThreshold),
  [landscapeIndex, landscapeDepth, landscapeThreshold]);
  const separatedRegions = useMemo(() => landscapeGraph === null ? new Set<string>()
    : new Set(greedySeparatedSet(landscapeGraph)), [landscapeGraph]);
  const convergingRegions = landscapeA === null
    ? new Set<string>() : landscapeGraph?.neighbors.get(landscapeA) ?? new Set<string>();
  const aIds = useMemo(() => landscapeIndex !== null && landscapeA !== null
    ? new Set(neighborhoodIds(landscapeIndex, landscapeA, landscapeDepth)) : new Set<string>(),
  [landscapeIndex, landscapeA, landscapeDepth]);
  const bIds = useMemo(() => landscapeIndex !== null && landscapeB !== null
    ? new Set(neighborhoodIds(landscapeIndex, landscapeB, landscapeDepth)) : new Set<string>(),
  [landscapeIndex, landscapeB, landscapeDepth]);
  const sharedCount = [...aIds].filter((id) => bIds.has(id)).length;
  // Structure mode keeps every admitted wire. A structural comparison traces
  // only wires inside the selected depth-1/2/3 territory; clearing A clears them.
  const focusedWireIds = useMemo(() => landscapeMode !== "parallelism" ? null
    : new Set([
      ...aIds, ...bIds,
      ...(landscapeA === null ? [] : [landscapeA]),
      ...(landscapeB === null ? [] : [landscapeB]),
    ]), [landscapeMode, landscapeA, landscapeB, aIds, bIds]);

  // The same projected dependency graph underlies every mode. Structural
  // separation traces its selected territory and leaves the empty mode clear.
  // A family-edge drill highlights its backing projected wires in that graph.
  const drilledRows = useMemo(() => {
    if (families === null || drill === null) return null;
    return new Set(
      (families.edgeContributionLinks.get(drill) ?? []).map((link) => session.graph.linkRows[link]),
    );
  }, [families, drill, session]);
  const renderWires = view.projection.wires.length <= LINK_RENDER_BUDGET;
  const currentWireWindow = wireWindow?.revision === view.revision ? wireWindow : null;
  const wireVisible = useMemo(
    () =>
      (index: number): boolean => {
        const wire = view.projection.wires[index];
        return (
          (renderWires || (currentWireWindow?.zoomed === true && currentWireWindow.indices.has(index))) &&
          wire !== undefined &&
          (focusedWireIds === null || (focusedWireIds.has(wire.source) && focusedWireIds.has(wire.target))) &&
          (drilledRows === null || wire.provenance.some((row) => drilledRows.has(row)))
        );
      },
    [view.projection, renderWires, currentWireWindow, focusedWireIds, drilledRows],
  );
  const wireColor = useMemo(
    () =>
      (relation: string, index = -1): string | [number, number, number, number] =>
        wireVisible(index) ? relationColor(relation) : HIDDEN_LINK,
    [wireVisible],
  );
  const wireWidth = useMemo(
    () =>
      (_relation: string, index = -1): number => {
        const wire = view.projection.wires[index];
        return wireVisible(index) && wire !== undefined ? projectedWireWidth(wire.multiplicity) : 0;
      },
    [view.projection, wireVisible],
  );

  const landscapeMarkers = useMemo(() => {
    if (landscapeIndex === null || landscapeA === null) return [];
    if (regionLayer.regions.length === 0) return [];
    const instance = mountedCosmograph();
    if (instance === undefined) return [];
    const shared: string[] = [];
    const aOnly: string[] = [];
    const bOnly: string[] = [];
    for (const id of aIds) (bIds.has(id) ? shared : aOnly).push(id);
    for (const id of bIds) if (!aIds.has(id)) bOnly.push(id);
    const records: { id: string; x: number; y: number; color: string; radius: number }[] = [];
    const seen = new Set<string>();
    const add = (id: string, color: string, radius: number): void => {
      if (records.length >= LANDSCAPE_MARKER_BUDGET || seen.has(id)) return;
      const point = session.graph.indexById.get(id);
      if (point === undefined) return;
      const position = instance.getPointPositionByIndex(point);
      const screen = position === undefined ? null : instance.spaceToScreenPosition(position);
      if (screen == null) return;
      seen.add(id);
      records.push({ id, x: screen[0], y: screen[1], color, radius });
    };
    // Selected origins and shared territory have priority when the budget binds.
    add(landscapeA, LANDSCAPE_A_COLOR, 16);
    if (landscapeB !== null) add(landscapeB, LANDSCAPE_B_COLOR, 16);
    for (const id of shared) add(id, LANDSCAPE_SHARED_COLOR, 12);
    for (const id of aOnly) add(id, LANDSCAPE_A_COLOR, 9);
    for (const id of bOnly) add(id, LANDSCAPE_B_COLOR, 9);
    return records;
  }, [landscapeIndex, landscapeA, landscapeB, aIds, bIds, regionLayer.regions, session]);
  const projectionMetrics = session.projectionMetrics();
  const scalarRange = useMemo(
    () => metricShadeRange(projectionMetrics, measurementMode),
    [projectionMetrics, measurementMode],
  );
  const shadingRef = useRef({ mode: measurementMode, range: scalarRange });
  const selectRegion = (ordinal: number, additive = false): void => {
    const index = session.graph.fileCount + session.graph.symbolCount + ordinal;
    const id = session.pointId(index);
    if (id === null) return;
    selectWire(null);
    if (landscapeMode === "parallelism") setLandscapeOrigin({ id, additive });
    else setSelectedOnly(id);
  };
  const pointColor = useMemo(() => {
    if (measurementMode === "physical" && session.physical !== null) {
      return physicalPointColor(session.graph, families, session.physical);
    }
    if ((measurementMode === "locality" || measurementMode === "reach") && scalarRange !== null) {
      const shaded = Array.from({ length: session.graph.pointCount }, (_, index) => {
        const base = basePointColor(session.graph, families, index);
        const metrics = session.metricsFor(index);
        return metrics === null
          ? base
          : shadeOklab(base, scalarPosition(metricValue(metrics, measurementMode), scalarRange));
      });
      return (_value: unknown, index = -1): string =>
        shaded[index] ?? basePointColor(session.graph, families, index);
    }
    return families === null ? undefined : familyPointColor(families);
  }, [measurementMode, scalarRange, session, families]);
  const pointSize = useMemo(
    () =>
      (_value: unknown, index = -1): number => {
        if (index >= session.graph.fileCount + session.graph.symbolCount) return 18;
        if (index >= session.graph.fileCount) return 5;
        return 9;
      },
    [session],
  );
  const labelledPoints = useMemo(
    () =>
      [...view.projection.nodes]
        .toSorted(
          (a, b) =>
            (a.kind === "directory" ? 0 : a.kind === "file" ? 1 : 2) -
              (b.kind === "directory" ? 0 : b.kind === "file" ? 1 : 2) ||
            a.depth - b.depth ||
            a.index - b.index,
        )
        .filter((node) => node.kind !== "directory")
        .slice(0, 30)
        .map((node) => node.id),
    [view],
  );

  // The renderer's stable callbacks delegate here; the dependency list is only
  // the setters (all stable) and the session. Disposing the session removes
  // these handlers even before React unmounts the component.
  useEffect(() => {
    let firstBuild = true;
    let fitZoom: number | null = null;
    let wireTimer: number | null = null;
    const updateWireWindow = (): void => {
      if (wireTimer !== null) window.clearTimeout(wireTimer);
      wireTimer = window.setTimeout(() => {
        wireTimer = null;
        const instance = mountedCosmograph();
        const canvas = instance?.getCanvas();
        if (instance === undefined || canvas == null) return;
        const snapshot = session.getViewSnapshot();
        if (snapshot.projection.wires.length <= LINK_RENDER_BUDGET) return;
        const zoom = instance.getZoomLevel() ?? 1;
        const fitted = fitZoom ?? zoom;
        const ratio = fitted > 0 ? zoom / fitted : 1;
        const budget = zoomWireBudget(ratio);
        const rect = canvas.getBoundingClientRect();
        const indices = viewportWires(
          snapshot.projection.wires,
          (index) => {
            const space = instance.getPointPositionByIndex(index);
            const screen = space === undefined ? undefined : instance.spaceToScreenPosition(space);
            return screen == null ? null : { x: screen[0], y: screen[1] };
          },
          rect.width,
          rect.height,
          budget,
        );
        setWireWindow((prior) => {
          const next: WireWindow = { revision: snapshot.revision, zoomed: budget > 0, indices };
          if (
            prior?.revision === next.revision &&
            prior.zoomed === next.zoomed &&
            prior.indices.size === next.indices.size &&
            [...prior.indices].every((index) => next.indices.has(index))
          ) {
            return prior;
          }
          return next;
        });
      }, 100);
    };
    const updateRegions = (): void => {
      if (frameRef.current !== null) return;
      frameRef.current = requestAnimationFrame(() => {
        frameRef.current = null;
        const instance = mountedCosmograph();
        const canvas = instance?.getCanvas();
        const root = rootRef.current;
        if (instance === undefined || canvas == null || root === null) return;
        const canvasRect = canvas.getBoundingClientRect();
        const rootRect = root.getBoundingClientRect();
        setRegionLayer({
          left: canvasRect.left - rootRect.left,
          top: canvasRect.top - rootRect.top,
          width: canvasRect.width,
          height: canvasRect.height,
          regions: topLevelRegions(
            session,
            instance,
            anchors,
            shadingRef.current.mode,
            shadingRef.current.range,
          ),
        });
      });
    };
    regionUpdateRef.current = updateRegions;
    const rebuilt = (): void => {
      const instance = mountedCosmograph();
      // A dataset switch gets a new GraphView. A frontier change keeps the
      // user's camera so the expanded region stays in context.
      if (firstBuild) {
        instance?.fitView(0);
        fitZoom = instance?.getZoomLevel() ?? null;
      }
      firstBuild = false;
      setReady(true);
      reapplyEmphasis();
      publish({ ready: true, camera: { zoom: instance?.getZoomLevel() ?? null } });
      updateRegions();
      updateWireWindow();
      void session.retireOldProjectedTables();
    };
    const zoom = (): void => {
      publish({ camera: { zoom: mountedCosmograph()?.getZoomLevel() ?? null } });
      updateRegions();
      updateWireWindow();
    };
    setGraphHandlers({
      enter: (index) => setHoveredIndex(index),
      leave: () => setHoveredIndex(null),
      click: (index, additive) => {
        const id = session.pointId(index);
        if (id === null) return;
        selectWire(null);
        if (landscapeModeRef.current === "parallelism") {
          setLandscapeOrigin({ id, additive });
          void session.revealOrigin(id);
          return;
        }
        if (additive) setToggleSelected(id);
        else setSelectedOnly(id);
      },
      linkClick: (index) => {
        if (session.getViewSnapshot().projection.wires[index] === undefined) return;
        clearSelection();
        selectWire({ index, viewRevision: session.getViewSnapshot().revision });
      },
      background: () => {
        if (landscapeModeRef.current === "parallelism") setLandscapeOrigins({ a: null, b: null });
        clearSelection();
        selectWire(null);
        setDrill(null);
      },
      rebuilt,
      zoom,
      drag: () => {
        updateRegions();
        updateWireWindow();
      },
    });
    setDiagnosticsSource({
      screenPositionOf: (index) => screenPositionOf(mountedCosmograph(), index),
      projectedWireScreenEndpoints: (index) => {
        const wire = session.getViewSnapshot().projection.wires[index];
        if (wire === undefined) return null;
        const instance = mountedCosmograph();
        const source = screenPositionOf(instance, wire.sourceIndex);
        const target = screenPositionOf(instance, wire.targetIndex);
        return source === null || target === null ? null : { source, target };
      },
      pointWithIncidentLinks: () =>
        session.getViewSnapshot().projection.wires[0]?.sourceIndex ??
        session.firstPointWithLinks(RELATION_ORDER),
      pointIdOf: (index) => session.pointId(index),
      pointCount: () => session.pointCount,
      visibleNodeIds: () => session.graph.pointIds,
      regionMetrics: (id) => {
        const index = session.graph.indexById.get(id);
        return index === undefined ? null : session.metricsFor(index);
      },
      familyOfPoint: (index) =>
        session.families === null ? null : familyMembership(session.families, index),
    });
    const unsubscribe = session.onDispose(() => {
      setGraphHandlers(null);
      setDiagnosticsSource(null);
    });
    return () => {
      unsubscribe();
      setGraphHandlers(null);
      setDiagnosticsSource(null);
      clearMountedCosmograph();
      regionUpdateRef.current = () => {};
      if (frameRef.current !== null) cancelAnimationFrame(frameRef.current);
      if (wireTimer !== null) window.clearTimeout(wireTimer);
    };
  }, [
    session,
    anchors,
    setHoveredIndex,
    setReady,
    setSelectedOnly,
    setToggleSelected,
    clearSelection,
    selectWire,
    setDrill,
    setLandscapeOrigin,
    setLandscapeOrigins,
  ]);

  useEffect(() => {
    shadingRef.current = { mode: measurementMode, range: scalarRange };
    regionUpdateRef.current();
  }, [measurementMode, scalarRange]);

  useEffect(() => {
    if (selectedWire !== null && selectedWire.viewRevision !== view.revision) selectWire(null);
  }, [selectedWire, view.revision, selectWire]);

  const enabledWireKey = visibleRelations.filter(isWireRelation).join(",");
  useEffect(() => {
    const enabled = enabledWireKey === "" ? [] : enabledWireKey.split(",").filter(isWireRelation);
    void session.setWireRelations(enabled).catch((cause: unknown) => {
      publish({ error: cause instanceof Error ? cause.message : String(cause) });
    });
  }, [session, enabledWireKey]);

  // The documented clear action on the keyboard (the canvas is not focusable).
  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent): void => {
      if (event.key === "Escape") {
        setLandscapeOrigins({ a: null, b: null });
        clearSelection();
        selectWire(null);
        setDrill(null);
      }
    };
    window.addEventListener("keydown", onKeyDown);
    return () => {
      window.removeEventListener("keydown", onKeyDown);
    };
  }, [clearSelection, selectWire, setDrill, setLandscapeOrigins]);

  useEffect(() => {
    if (landscapeMode === "parallelism" && landscapeA !== null) {
      const ids = new Set([...aIds, ...bIds, landscapeA]);
      if (landscapeB !== null) ids.add(landscapeB);
      setEmphasis({ points: [...ids].map((id) => session.graph.indexById.get(id)).filter((index): index is number => index !== undefined), links: [] });
    } else if (landscapeMode === "parallelism") setEmphasis({ points: [], links: [] });
    else setEmphasis(emphasis);
  }, [emphasis, landscapeMode, landscapeA, landscapeB, aIds, bIds, session]);

  useEffect(() => {
    const selection = sortedSelection(selected);
    const selectedIndex = session.graph.indexById.get(selection[selection.length - 1] ?? "");
    const projection = view.projection;
    const selectedProjectionWire =
      selectedWire?.viewRevision === view.revision ? projection.wires[selectedWire.index] : undefined;
    const inspection =
      selectedProjectionWire === undefined ? null : inspectWire(session.graph, selectedProjectionWire, 0);
    publish({
      frontier: {
        expanded: view.frontier.expanded,
        revision: view.frontier.revision,
        level: frontierLevel(session.containment, view.frontier),
      },
      projected: {
        nodeCount: projection.nodes.length,
        edgeCount: projection.wires.reduce((sum, edge) => sum + edge.multiplicity, 0),
        aggregatedEdgeCount: projection.wires.length,
        internalizedCount: projection.internalized,
      },
      selectedEdge:
        inspection === null
          ? null
          : {
              source: inspection.source,
              target: inspection.target,
              relation: inspection.relation,
              multiplicity: inspection.multiplicity,
              provenanceCount: selectedProjectionWire?.provenance.length ?? 0,
              uniqueSources: inspection.uniqueSources,
              uniqueTargets: inspection.uniqueTargets,
            },
      hovered: hovered === null ? null : session.pointId(hovered),
      hoveredIndex: hovered,
      highlighted: { points: highlightIds(session.graph, emphasis), links: [...emphasis.links] },
      selected: selection,
      selectedRegion: selectedIndex === undefined ? null : session.metricsFor(selectedIndex),
      relationFilter: [...visibleRelations],
      depth,
      filterRevision,
      overlay: { name: "structure", revision: 0 },
      shading: { name: measurementMode, revision: measurementRevision },
      drilledFamilyEdge: drill,
    });
  }, [
    session,
    view,
    selectedWire,
    hovered,
    emphasis,
    selected,
    visibleRelations,
    depth,
    filterRevision,
    measurementMode,
    measurementRevision,
    drill,
  ]);

  /* oxlint-disable jsx-a11y/prefer-tag-over-role -- SVG text cannot host a native HTML button. */
  return (
    <div ref={rootRef} {...stylex.props(styles.root)}>
      <Cosmograph
        {...stylex.props(styles.graph)}
        duckDBConnection={session.duckdb}
        points={session.pointsTable}
        links={view.linksTable}
        pointIdBy="id"
        pointIndexBy="index"
        pointXBy="x"
        pointYBy="y"
        linkSourceBy="source"
        linkTargetBy="target"
        linkSourceIndexBy="sourceIndex"
        linkTargetIndexBy="targetIndex"
        backgroundColor={BACKGROUND}
        enableSimulation={false}
        fitViewOnInit
        transitionDuration={0}
        selectPointOnClick={false}
        focusPointOnClick={false}
        resetSelectionOnEmptyCanvasClick={false}
        showLabels
        showDynamicLabels={false}
        showTopLabels={false}
        showLabelsFor={labelledPoints}
        showHoveredPointLabel
        statusIndicatorMode={false}
        pointColorBy="domain"
        pointColorStrategy={pointColor === undefined ? "map" : "direct"}
        pointColorByMap={POINT_COLORS}
        pointColorByFn={pointColor}
        pointSizeBy="index"
        pointSizeByFn={pointSize}
        pointLabelBy="label"
        pointDefaultSize={12}
        pointGreyoutOpacity={landscapeMode === "parallelism" ? 0.32 : 0.08}
        linkGreyoutOpacity={landscapeMode === "parallelism" ? 0.1 : 0.02}
        linkColorBy="relation"
        linkColorByFn={wireColor}
        linkWidthBy="relation"
        linkWidthByFn={wireWidth}
        onMount={onGraphMount}
        onPointMouseOver={onPointMouseOver}
        onPointMouseOut={onPointMouseOut}
        onPointClick={onPointClick}
        onLinkClick={onLinkClick}
        selectLinkOnClick={false}
        onBackgroundClick={onBackgroundClick}
        onGraphRebuilt={onGraphRebuilt}
        onZoom={onZoom}
        onDrag={onGraphDrag}
      />
      {renderWires ? null : (
        <output {...stylex.props(styles.edgeNotice)} data-testid="wire-visibility">
          {currentWireWindow?.zoomed === true
            ? `Showing ${currentWireWindow.indices.size.toLocaleString()} of ${view.projection.wires.length.toLocaleString()} connections at this zoom`
            : `Zoom in to reveal ${view.projection.wires.length.toLocaleString()} connections`}
        </output>
      )}
      {landscapeMode === "parallelism" && <div
        aria-label="Structural separation graph key"
        data-testid="structural-graph-key"
        {...stylex.props(styles.landscapeKey)}
      >
        <strong>{landscapeA === null ? "Greedy separated set" : `Neighborhoods · ${landscapeDepth}°`}</strong>
        {landscapeA === null ? <>
          <span {...stylex.props(styles.landscapeKeyRow)}>
            <span {...stylex.props(styles.landscapeKeySwatch)} style={LANDSCAPE_SET_SWATCH_STYLE} />
            {separatedRegions.size} / {landscapeIndex?.candidates.length ?? 0} regions
          </span>
          <span {...stylex.props(styles.landscapeKeyDetail)}>{landscapeDepth}° · τ {landscapeThreshold.toFixed(2)}<br />No wires until selection</span>
        </> : <>
          <span {...stylex.props(styles.landscapeKeyRow)}>
            <span {...stylex.props(styles.landscapeKeySwatch)} style={LANDSCAPE_A_SWATCH_STYLE} />
            {landscapeB === null ? `A reaches ${aIds.size}` : `A only · ${aIds.size - sharedCount}`}
          </span>
          {landscapeB !== null && <>
            <span {...stylex.props(styles.landscapeKeyRow)}>
              <span {...stylex.props(styles.landscapeKeySwatch)} style={LANDSCAPE_SHARED_SWATCH_STYLE} />
              Shared · {sharedCount}
            </span>
            <span {...stylex.props(styles.landscapeKeyRow)}>
              <span {...stylex.props(styles.landscapeKeySwatch)} style={LANDSCAPE_B_SWATCH_STYLE} />
              B only · {bIds.size - sharedCount}
            </span>
          </>}
        </>}
      </div>}
      <svg
        aria-label="Repository structural regions"
        {...stylex.props(styles.regions)}
        style={regionStyle}
        viewBox={`0 0 ${regionLayer.width} ${regionLayer.height}`}
      >
        {regionLayer.regions.map((region) => {
          const id = session.graph.pointIds[
            session.graph.fileCount + session.graph.symbolCount + region.ordinal
          ] ?? "";
          const role = id === landscapeA ? "origin-a"
            : id === landscapeB ? "origin-b"
            : aIds.has(id) && bIds.has(id) ? "shared"
            : aIds.has(id) ? "a-only"
            : bIds.has(id) ? "b-only"
            : landscapeA === null && separatedRegions.has(id) ? "separated"
            : convergingRegions.has(id) ? "converging" : "none";
          const accent = role === "origin-a" || role === "a-only" ? LANDSCAPE_A_COLOR
            : role === "origin-b" || role === "b-only" ? LANDSCAPE_B_COLOR
            : role === "shared" ? LANDSCAPE_SHARED_COLOR
            : role === "separated" ? LANDSCAPE_SET_COLOR
            : role === "converging" ? "#c5d5a3" : region.color;
          const highlighted = role !== "none" && role !== "converging";
          return <g key={region.ordinal}>
            <rect
              data-testid="topology-region"
              data-landscape-role={role}
              x={region.x}
              y={region.y}
              width={region.width}
              height={region.height}
              rx={3}
              fill={region.color}
              data-converging={convergingRegions.has(id)}
              fillOpacity={
                measurementMode !== "structure" &&
                (measurementMode !== "physical" || session.physical !== null)
                  ? 0.26
                  : 0.065
              }
              stroke={accent}
              strokeDasharray={role === "converging" ? "5 4" : undefined}
              strokeOpacity={role === "converging" ? 0.6 : 0.9}
              strokeWidth={highlighted ? role === "separated" ? 4 : 5 : role === "converging" ? 2.5 : 2}
            />
            {highlighted && <rect
              data-testid="structural-region-wash"
              x={region.x}
              y={region.y}
              width={region.width}
              height={region.height}
              rx={3}
              fill={accent}
              fillOpacity={role === "shared" ? 0.48
                : role.startsWith("origin") ? 0.43
                : role === "separated" ? 0.2 : 0.36}
            />}
            {highlighted && role !== "separated" && region.width > 42 && region.height > 48 && <g
              data-testid="structural-region-role"
              aria-hidden="true"
            >
              <rect x={region.x + 3} y={region.y + region.height - 21}
                width={role === "shared" ? 45 : role.startsWith("origin") ? 25 : 43}
                height={17} rx={2} fill={accent} />
              <text x={region.x + 8} y={region.y + region.height - 8}
                fill={BACKGROUND} fontSize={10} fontWeight={800}>
                {role === "shared" ? "BOTH" : role === "origin-a" ? "A" : role === "origin-b" ? "B"
                  : role === "a-only" ? "A ONLY" : "B ONLY"}
              </text>
            </g>}
            {region.width > 34 && region.height > 24 && (
              <text
                data-testid="topology-region-label"
                role="button"
                tabIndex={0}
                aria-label={`Inspect region ${region.label}`}
                pointerEvents="visiblePainted"
                style={REGION_LABEL_HIT_STYLE}
                onClick={(event) => selectRegion(region.ordinal, event.shiftKey)}
                onKeyDown={(event) => {
                  if (event.key === "Enter" || event.key === " ") {
                    event.preventDefault();
                    selectRegion(region.ordinal);
                  }
                }}
                x={region.x + 5}
                y={region.y + 14}
                fill="#f3f5f7"
                stroke={BACKGROUND}
                strokeWidth={3}
                paintOrder="stroke"
                fontSize={11}
                fontWeight={600}
              >
                {region.label.length > Math.floor((region.width - 9) / 6.5)
                  ? `${region.label.slice(0, Math.max(2, Math.floor((region.width - 16) / 6.5)))}…`
                  : region.label}
              </text>
            )}
          </g>;
        })}
        <g aria-hidden="true" pointerEvents="none">
          {landscapeMarkers.map((marker) => <circle key={marker.id}
            data-testid="structural-neighborhood-marker"
            cx={marker.x} cy={marker.y} r={marker.radius}
            fill={marker.color} fillOpacity={0.3}
            stroke={marker.color} strokeOpacity={0.96} strokeWidth={2.5} />)}
        </g>
      </svg>
    </div>
  );
  /* oxlint-enable jsx-a11y/prefer-tag-over-role */
}
