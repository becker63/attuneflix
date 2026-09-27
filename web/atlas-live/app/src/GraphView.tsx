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
import { useEffect } from "react";

import { RELATION_ORDER } from "../../projection/src/relation.ts";
import {
  clearSelectionAtom,
  emphasisAtom,
  filterRevisionAtom,
  hoveredIndexAtom,
  neighbourhoodDepthAtom,
  readyAtom,
  relationMaskAtom,
  selectOnlyAtom,
  selectedAtom,
  toggleSelectedAtom,
  visibleRelationSetAtom,
} from "./atoms.ts";
import { publish, setDiagnosticsSource } from "./diagnostics.ts";
import { reapplyEmphasis, setEmphasis } from "./emphasis.ts";
import {
  clearMountedCosmograph,
  mountedCosmograph,
  onBackgroundClick,
  onGraphMount,
  onGraphRebuilt,
  onPointClick,
  onPointMouseOut,
  onPointMouseOver,
  onZoom,
  setGraphHandlers,
  type MountedCosmograph,
} from "./graphHandlers.ts";
import { linkColorFn, linkWidthFn } from "./linkAccessors.ts";
import { highlightIds } from "./neighbourhood.ts";
import { sortedSelection } from "./selection.ts";
import type { GraphSession } from "./session.ts";
import { pointColorMap } from "./vocabulary.ts";

const styles = stylex.create({
  root: {
    width: "100%",
    height: "100%",
  },
});

const POINT_COLORS = pointColorMap();
const BACKGROUND = "#0b0d12";

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

  // The renderer's stable callbacks delegate here; the dependency list is only
  // the setters (all stable) and the session. Disposing the session removes
  // these handlers even before React unmounts the component.
  useEffect(() => {
    const rebuilt = (): void => {
      // Fit the camera to the freshly loaded dataset, so a switch never keeps the
      // previous world's zoom and pan.
      const instance = mountedCosmograph();
      instance?.fitView(0);
      setReady(true);
      reapplyEmphasis();
      publish({ ready: true, camera: { zoom: instance?.getZoomLevel() ?? null } });
    };
    const zoom = (): void => {
      publish({ camera: { zoom: mountedCosmograph()?.getZoomLevel() ?? null } });
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
      background: () => clearSelection(),
      rebuilt,
      zoom,
    });
    setDiagnosticsSource({
      screenPositionOf: (index) => screenPositionOf(mountedCosmograph(), index),
      pointWithIncidentLinks: () => session.firstPointWithLinks(RELATION_ORDER),
      pointIdOf: (index) => session.pointId(index),
      pointCount: () => session.pointCount,
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
    };
  }, [session, setHoveredIndex, setReady, setSelectedOnly, setToggleSelected, clearSelection]);

  // The documented clear action on the keyboard (the canvas is not focusable).
  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent): void => {
      if (event.key === "Escape") clearSelection();
    };
    window.addEventListener("keydown", onKeyDown);
    return () => {
      window.removeEventListener("keydown", onKeyDown);
    };
  }, [clearSelection]);

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
    });
  }, [session, hovered, emphasis, selected, visibleRelations, depth, filterRevision]);

  return (
    <Cosmograph
      {...stylex.props(styles.root)}
      duckDBConnection={session.duckdb}
      points={session.pointsTable}
      links={session.linksTable}
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
      showLabels={false}
      showDynamicLabels={false}
      showTopLabels={false}
      showHoveredPointLabel={false}
      statusIndicatorMode={false}
      pointColorBy="domain"
      pointColorStrategy="map"
      pointColorByMap={POINT_COLORS}
      pointDefaultSize={12}
      pointGreyoutOpacity={0.08}
      linkGreyoutOpacity={0.02}
      linkColorBy="relation"
      linkColorByFn={linkColorFn(relationMask, session.renderLinks)}
      linkWidthBy="relation"
      linkWidthByFn={linkWidthFn(relationMask, session.renderLinks)}
      onMount={onGraphMount}
      onPointMouseOver={onPointMouseOver}
      onPointMouseOut={onPointMouseOut}
      onPointClick={onPointClick}
      onBackgroundClick={onBackgroundClick}
      onGraphRebuilt={onGraphRebuilt}
      onZoom={onZoom}
    />
  );
}
