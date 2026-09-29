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
  neighbourhoodDepthAtom,
  overlayAtom,
  overlayRevisionAtom,
  readyAtom,
  relationMaskAtom,
  reuseShadingAtom,
  selectOnlyAtom,
  selectedAtom,
  toggleSelectedAtom,
  visibleRelationSetAtom,
} from "./atoms.ts";
import { publish, setDiagnosticsSource } from "./diagnostics.ts";
import { LINK_RENDER_BUDGET } from "./datasets.ts";
import { reapplyEmphasis, setEmphasis } from "./emphasis.ts";
import { familyMembership, familyPointColor, familyTint } from "./families.ts";
import { frontierLevel } from "./frontier/frontier.ts";
import { isWireRelation } from "./frontier/wires.ts";
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
import { linkColorAccessor, linkWidthAccessor } from "./linkAccessors.ts";
import { highlightIds } from "./neighbourhood.ts";
import { physicalPointColor, regionReuse, reuseShadePosition, shadeOklab } from "./physical.ts";
import { sortedSelection } from "./selection.ts";
import type { GraphSession } from "./session.ts";
import { pointColorMap } from "./vocabulary.ts";

const styles = stylex.create({
  root: {
    position: "relative",
    width: "100%",
    height: "100%",
  },
  graph: { width: "100%", height: "100%" },
  regions: { position: "absolute", pointerEvents: "none", overflow: "hidden" },
});

const POINT_COLORS = pointColorMap();
const BACKGROUND = "#0b0d12";

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

function topLevelRegions(session: GraphSession, instance: MountedCosmograph, anchors: LayoutAnchors, shadeReuse: boolean): ScreenRegion[] {
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
  const reuse = shadeReuse && session.physical !== null ? regionReuse(session.layout, session.physical) : null;
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
    const baseColor = session.families === null ? POINT_COLORS.location : familyTint(session.families, pointIndex);
    const measured = reuse?.get(ordinal);
    regions.push({
      ordinal,
      x: Math.min(x0, x1),
      y: Math.min(y0, y1),
      width: Math.abs(x1 - x0),
      height: Math.abs(y1 - y0),
      color: measured === undefined || session.physical === null
        ? baseColor
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
  if (screen === undefined) return null;
  const canvas = instance.getCanvas();
  if (canvas === null) return null;
  const rect = canvas.getBoundingClientRect();
  return [rect.left + screen[0], rect.top + screen[1]];
}

export function GraphView({ session }: { session: GraphSession }) {
  const anchors = useMemo(() => layoutAnchors(session), [session]);
  const rootRef = useRef<HTMLDivElement>(null);
  const frameRef = useRef<number | null>(null);
  const [regionLayer, setRegionLayer] = useState<{ left: number; top: number; width: number; height: number; regions: ScreenRegion[] }>({
    left: 0, top: 0, width: 0, height: 0, regions: [],
  });
  const regionStyle = useMemo(() => ({
    left: regionLayer.left,
    top: regionLayer.top,
    width: regionLayer.width,
    height: regionLayer.height,
  }), [regionLayer]);
  const view = useSyncExternalStore(session.subscribeView, session.getViewSnapshot, session.getViewSnapshot);
  const setHoveredIndex = useSetAtom(hoveredIndexAtom);
  const setReady = useSetAtom(readyAtom);
  const setSelectedOnly = useSetAtom(selectOnlyAtom);
  const setToggleSelected = useSetAtom(toggleSelectedAtom);
  const clearSelection = useSetAtom(clearSelectionAtom);

  const hovered = useAtomValue(hoveredIndexAtom);
  const emphasis = useAtomValue(emphasisAtom);
  const selected = useAtomValue(selectedAtom);
  const visibleRelations = useAtomValue(visibleRelationSetAtom);
  const depth = useAtomValue(neighbourhoodDepthAtom);
  const filterRevision = useAtomValue(filterRevisionAtom);
  const relationMask = useAtomValue(relationMaskAtom);
  const overlay = useAtomValue(overlayAtom);
  const overlayRevision = useAtomValue(overlayRevisionAtom);
  const drill = useAtomValue(drilledFamilyEdgeAtom);
  const setDrill = useSetAtom(drillFamilyEdgeAtom);

  const families = session.families;
  const shadeReuse = useAtomValue(reuseShadingAtom);
  const pointColor = useMemo(
    () => shadeReuse && session.physical !== null
      ? physicalPointColor(session.graph, families, session.physical)
      : families === null ? undefined : familyPointColor(families),
    [shadeReuse, session, families],
  );
  const pointSize = useMemo(
    () => (_value: unknown, index = -1): number => {
      if (index >= session.graph.fileCount + session.graph.symbolCount) return 18;
      if (index >= session.graph.fileCount) return 5;
      return 9;
    },
    [session],
  );
  const labelledPoints = useMemo(
    () => [...view.projection.nodes]
          .toSorted((a, b) =>
            (a.kind === "directory" ? 0 : a.kind === "file" ? 1 : 2) -
              (b.kind === "directory" ? 0 : b.kind === "file" ? 1 : 2) ||
            a.depth - b.depth || a.index - b.index,
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
          regions: topLevelRegions(session, instance, anchors, shadeReuse),
        });
      });
    };
    const rebuilt = (): void => {
      const instance = mountedCosmograph();
      // A dataset switch gets a new GraphView. A frontier change keeps the
      // user's camera so the expanded region stays in context.
      if (firstBuild) instance?.fitView(0);
      firstBuild = false;
      setReady(true);
      reapplyEmphasis();
      publish({ ready: true, camera: { zoom: instance?.getZoomLevel() ?? null } });
      updateRegions();
      void session.retireOldProjectedTables();
    };
    const zoom = (): void => {
      publish({ camera: { zoom: mountedCosmograph()?.getZoomLevel() ?? null } });
      updateRegions();
    };
    setGraphHandlers({
      enter: (index) => setHoveredIndex(index),
      leave: () => setHoveredIndex(null),
      click: (index, additive) => {
        const id = session.pointId(index);
        if (id === null) return;
        if (additive) setToggleSelected(id);
        else setSelectedOnly(id);
      },
      linkClick: () => setDrill(null),
      background: () => {
        clearSelection();
        setDrill(null);
      },
      rebuilt,
      zoom,
      drag: updateRegions,
    });
    setDiagnosticsSource({
      screenPositionOf: (index) => screenPositionOf(mountedCosmograph(), index),
      pointWithIncidentLinks: () =>
        session.getViewSnapshot().projection.wires[0]?.sourceIndex ?? session.firstPointWithLinks(RELATION_ORDER),
      pointIdOf: (index) => session.pointId(index),
      pointCount: () => session.pointCount,
      visibleNodeIds: () => session.graph.pointIds,
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
      if (frameRef.current !== null) cancelAnimationFrame(frameRef.current);
    };
  }, [session, anchors, shadeReuse, setHoveredIndex, setReady, setSelectedOnly, setToggleSelected, clearSelection, setDrill]);

  const enabledWireKey = visibleRelations.filter(isWireRelation).join(",");
  useEffect(() => {
    const enabled = enabledWireKey === "" ? [] : enabledWireKey.split(",").filter(isWireRelation);
    void session.setWireRelations(enabled).catch((cause: unknown) => {
      publish({ error: cause instanceof Error ? cause.message : String(cause) });
    });
  }, [session, enabledWireKey]);

  useEffect(() => {
    const projection = view.projection;
    publish({
      frontier: {
        expanded: view.frontier.expanded,
        revision: view.frontier.revision,
        level: frontierLevel(session.containment, view.frontier),
      },
      projected: {
        nodeCount: projection.nodes.length,
        edgeCount: projection.wires.reduce((sum, wire) => sum + wire.multiplicity, 0),
        aggregatedEdgeCount: projection.wires.length,
        internalizedCount: projection.internalized,
      },
    });
  }, [session, view]);

  // The documented clear action on the keyboard (the canvas is not focusable).
  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent): void => {
      if (event.key === "Escape") {
        clearSelection();
        setDrill(null);
      }
    };
    window.addEventListener("keydown", onKeyDown);
    return () => {
      window.removeEventListener("keydown", onKeyDown);
    };
  }, [clearSelection, setDrill]);

  useEffect(() => {
    setEmphasis(emphasis);
  }, [emphasis]);

  useEffect(() => {
    publish({
      hovered: hovered === null ? null : session.pointId(hovered),
      hoveredIndex: hovered,
      highlighted: { points: highlightIds(session.graph, emphasis), links: [...emphasis.links] },
      selected: sortedSelection(selected),
      relationFilter: [...visibleRelations],
      depth,
      filterRevision,
      overlay: { name: overlay, revision: overlayRevision },
      drilledFamilyEdge: drill,
    });
  }, [
    session,
    hovered,
    emphasis,
    selected,
    visibleRelations,
    depth,
    filterRevision,
    overlay,
    overlayRevision,
    drill,
  ]);

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
      pointGreyoutOpacity={0.08}
      linkGreyoutOpacity={0.02}
      linkColorBy="relation"
      linkColorByFn={linkColorAccessor({
        mask: relationMask,
        renderLinks: view.projection.wires.length <= LINK_RENDER_BUDGET,
        overlay,
        families,
        exactLinkCount: Number.MAX_SAFE_INTEGER,
        drill,
      })}
      linkWidthBy="relation"
      linkWidthByFn={linkWidthAccessor({
        mask: relationMask,
        renderLinks: view.projection.wires.length <= LINK_RENDER_BUDGET,
        overlay,
        families,
        exactLinkCount: Number.MAX_SAFE_INTEGER,
        drill,
      })}
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
    <svg
      aria-hidden="true"
      {...stylex.props(styles.regions)}
      style={regionStyle}
      viewBox={`0 0 ${regionLayer.width} ${regionLayer.height}`}
    >
      {regionLayer.regions.map((region) => (
        <g key={region.ordinal}>
          <rect
            data-testid="topology-region"
            x={region.x}
            y={region.y}
            width={region.width}
            height={region.height}
            rx={3}
            fill={region.color}
            fillOpacity={0.065}
            stroke={region.color}
            strokeOpacity={0.85}
            strokeWidth={2}
          />
          {region.width > 34 && region.height > 24 && (
            <text
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
        </g>
      ))}
    </svg>
    </div>
  );
}
