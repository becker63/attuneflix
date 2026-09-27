/**
 * The snapshot picker. A Base UI Select listing exactly the 78 census worlds
 * (repository + short base revision + counts) plus the separately labelled
 * synthetic stress fixture. Choosing an option loads that dataset on demand;
 * nothing is prefetched. The list is a real listbox, so an accessibility
 * snapshot of the open popup reads every option.
 */
import { Select } from "@base-ui/react";
import * as stylex from "@stylexjs/stylex";

import type { DatasetOption } from "./datasets.ts";

const styles = stylex.create({
  trigger: {
    display: "flex",
    alignItems: "center",
    gap: 8,
    minWidth: 260,
    maxWidth: 460,
    paddingTop: 6,
    paddingBottom: 6,
    paddingLeft: 10,
    paddingRight: 10,
    borderRadius: 6,
    borderWidth: 1,
    borderStyle: "solid",
    borderColor: { default: "#374151", ":hover": "#4b5563" },
    backgroundColor: "#111827",
    color: "#f4f4f5",
    fontSize: 13,
    textAlign: "left",
    cursor: { default: "pointer", ":disabled": "progress" },
    opacity: { default: 1, ":disabled": 0.6 },
  },
  value: {
    flexGrow: 1,
    overflow: "hidden",
    textOverflow: "ellipsis",
    whiteSpace: "nowrap",
  },
  placeholder: {
    color: "#9ca3af",
  },
  icon: {
    color: "#9ca3af",
    fontSize: 11,
  },
  positioner: {
    zIndex: 50,
  },
  popup: {
    minWidth: "var(--anchor-width)",
    maxHeight: 420,
    overflowY: "auto",
    borderRadius: 8,
    borderWidth: 1,
    borderStyle: "solid",
    borderColor: "#374151",
    backgroundColor: "#111827",
    boxShadow: "0 12px 32px rgba(0, 0, 0, 0.45)",
  },
  list: {
    display: "flex",
    flexDirection: "column",
    paddingTop: 4,
    paddingBottom: 4,
  },
  item: {
    display: "flex",
    alignItems: "center",
    gap: 8,
    paddingTop: 6,
    paddingBottom: 6,
    paddingLeft: 10,
    paddingRight: 10,
    cursor: "pointer",
    backgroundColor: { default: "transparent", ":hover": "#1f2937" },
  },
  itemBody: {
    display: "flex",
    flexDirection: "column",
    gap: 2,
    flexGrow: 1,
    minWidth: 0,
  },
  label: {
    fontSize: 13,
    color: "#f9fafb",
    overflow: "hidden",
    textOverflow: "ellipsis",
    whiteSpace: "nowrap",
  },
  synthetic: {
    color: "#fcd34d",
    fontWeight: 600,
  },
  detail: {
    fontSize: 11,
    color: "#9ca3af",
  },
  check: {
    color: "#a7f3d0",
    fontSize: 12,
  },
});

function labelFor(value: unknown, options: readonly DatasetOption[]): string {
  if (typeof value !== "string") return "Select a dataset";
  return options.find((option) => option.value === value)?.label ?? value;
}

export interface DatasetPickerProps {
  readonly options: readonly DatasetOption[];
  readonly value: string | null;
  readonly disabled?: boolean;
  readonly onSelect: (value: string) => void;
}

export function DatasetPicker({ options, value, disabled = false, onSelect }: DatasetPickerProps) {
  return (
    <Select.Root
      items={options}
      value={value}
      disabled={disabled}
      onValueChange={(next) => {
        if (typeof next === "string") onSelect(next);
      }}
    >
      <Select.Trigger {...stylex.props(styles.trigger)} aria-label="Dataset" data-testid="dataset-picker">
        <Select.Value>
          {(selected: unknown) => (
            <span {...stylex.props(styles.value, typeof selected === "string" ? null : styles.placeholder)}>
              {labelFor(selected, options)}
            </span>
          )}
        </Select.Value>
        <Select.Icon {...stylex.props(styles.icon)}>▾</Select.Icon>
      </Select.Trigger>
      <Select.Portal>
        <Select.Positioner sideOffset={4} align="start" {...stylex.props(styles.positioner)}>
          <Select.Popup {...stylex.props(styles.popup)}>
            <Select.List {...stylex.props(styles.list)} data-testid="dataset-picker-popup">
              {options.map((option) => (
                <Select.Item
                  key={option.value}
                  value={option.value}
                  label={option.label}
                  data-dataset={option.synthetic ? "synthetic" : "world"}
                  data-snapshot-id={option.value}
                  {...stylex.props(styles.item)}
                >
                  <Select.ItemText {...stylex.props(styles.itemBody)}>
                    <span {...stylex.props(styles.label, option.synthetic ? styles.synthetic : null)}>
                      {option.label}
                    </span>
                    <span {...stylex.props(styles.detail)}>{option.detail}</span>
                  </Select.ItemText>
                  <Select.ItemIndicator {...stylex.props(styles.check)}>✓</Select.ItemIndicator>
                </Select.Item>
              ))}
            </Select.List>
          </Select.Popup>
        </Select.Positioner>
      </Select.Portal>
    </Select.Root>
  );
}
