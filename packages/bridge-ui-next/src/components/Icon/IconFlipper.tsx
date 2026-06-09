"use client";

import { useState } from "react";

import Icon, { type IconType } from "./Icon";
import { classNames } from "@/libs/util/classNames";

export interface IconFlipperProps {
  iconType1: IconType;
  iconType2: IconType;
  size?: number;
  /**
   * Original `selectedDefault` defaulted to `iconType1` and was two-way bound.
   * Exposed here as controllable value + onSelectedDefaultChange.
   */
  selectedDefault?: IconType;
  onSelectedDefaultChange?: (value: IconType) => void;
  /** Original two-way bound `flipped`. */
  flipped?: boolean;
  onFlippedChange?: (value: boolean) => void;
  type?: "swap-rotate" | "swap-flip" | "";
  noEvent?: boolean;
  /** Svelte dispatch('labelclick') -> callback prop. */
  onLabelClick?: () => void;
  className?: string;
}

export default function IconFlipper({
  iconType1,
  iconType2,
  size = 20,
  selectedDefault,
  onSelectedDefaultChange,
  flipped,
  onFlippedChange,
  type = "",
  noEvent = false,
  onLabelClick,
  className,
}: IconFlipperProps) {
  // Support both controlled and uncontrolled usage for the two-way bound props.
  const [internalFlipped, setInternalFlipped] = useState(flipped ?? false);
  const [internalSelected, setInternalSelected] = useState<IconType>(
    selectedDefault ?? iconType1,
  );

  const currentFlipped = flipped ?? internalFlipped;
  const currentSelected = selectedDefault ?? internalSelected;

  function handleLabelClick() {
    if (noEvent) return;
    const nextSelected = currentSelected === iconType1 ? iconType2 : iconType1;
    const nextFlipped = !currentFlipped;
    setInternalSelected(nextSelected);
    setInternalFlipped(nextFlipped);
    onSelectedDefaultChange?.(nextSelected);
    onFlippedChange?.(nextFlipped);
    onLabelClick?.();
  }

  // $: isDefault = !flipped;
  const isDefault = !currentFlipped;

  const classes = classNames("swap  btn-neutral", type, className);

  return (
    <div
      role="button"
      tabIndex={0}
      className={classes}
      onClick={handleLabelClick}
      onKeyPress={handleLabelClick}
    >
      <input
        type="checkbox"
        className="border-none"
        checked={isDefault}
        readOnly
      />
      <Icon
        type={iconType1}
        className="fill-primary-icon swap-on"
        size={size}
      />
      <Icon
        type={iconType2}
        className="fill-primary-icon swap-off"
        size={size}
      />
    </div>
  );
}
