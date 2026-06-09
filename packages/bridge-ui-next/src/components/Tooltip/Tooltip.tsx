"use client";

import { type ReactNode, useEffect, useId, useRef, useState } from "react";

import { Icon } from "@/components/Icon";
import { cn } from "@/lib/utils";
import { positionElementByTarget } from "@/libs/util/positionElementByTarget";

const GAP = 10; // distance between trigger element and tooltip

export interface TooltipProps {
  /** Where the tooltip is positioned relative to the trigger. Defaults to 'top'. */
  position?: Position;
  /** Controlled open state. When `onTooltipOpenChange` is supplied the component is fully controlled. */
  tooltipOpen?: boolean;
  /** Two-way binding replacement: fired whenever the open state changes. */
  onTooltipOpenChange?: (open: boolean) => void;
  /** Mirrors the Svelte `$$props.class`; defaults to `relative` when absent. */
  className?: string;
  /** Default slot content. */
  children?: ReactNode;
}

export default function Tooltip({
  position = "top",
  tooltipOpen,
  onTooltipOpenChange,
  className,
  children,
}: TooltipProps) {
  // Stable, SSR-safe id replacing `crypto.randomUUID()`.
  const tooltipId = `tooltip-${useId()}`;

  // Support both controlled (when onTooltipOpenChange is provided) and
  // uncontrolled usage, seeding internal state from the prop.
  const isControlled = onTooltipOpenChange !== undefined;
  const [internalOpen, setInternalOpen] = useState(tooltipOpen ?? false);
  const open = isControlled ? (tooltipOpen ?? false) : internalOpen;

  const triggerElemRef = useRef<HTMLButtonElement>(null);
  const dialogElemRef = useRef<HTMLDialogElement>(null);
  const closeTimeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const setOpen = (value: boolean) => {
    if (!isControlled) {
      setInternalOpen(value);
    }
    onTooltipOpenChange?.(value);
  };

  function closeTooltip(ms = 0) {
    closeTimeoutRef.current = setTimeout(() => {
      setOpen(false);
    }, ms);
  }

  function openTooltip() {
    setOpen(true);
  }

  // onMount: position the dialog relative to its trigger.
  useEffect(() => {
    const dialogElem = dialogElemRef.current;
    const triggerElem = triggerElemRef.current;
    if (dialogElem && triggerElem) {
      positionElementByTarget(dialogElem, triggerElem, position, GAP);
    }

    // onDestroy: closeTooltip() — clear any pending close timeout on unmount.
    return () => {
      if (closeTimeoutRef.current) {
        clearTimeout(closeTimeoutRef.current);
      }
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // `position === 'top'` adds the caret class. Computed inline to mirror the
  // Svelte onMount-derived `tooltipClass`.
  const tooltipClass = cn(
    "block dialog-tooltip",
    position === "top" && "dialog-tooltip-top",
  );

  const classes = cn("flex z-10", className || "relative");

  return (
    <div
      className={classes}
      role="presentation"
      onMouseLeave={() => closeTooltip(200)}
    >
      <button
        aria-haspopup="dialog"
        aria-controls={tooltipId}
        aria-expanded={open}
        onClick={(e) => {
          e.stopPropagation();
          openTooltip();
        }}
        onFocus={(e) => {
          e.stopPropagation();
          openTooltip();
        }}
        onMouseEnter={openTooltip}
        ref={triggerElemRef}
      >
        <Icon type="question-circle" />
      </button>

      <dialog
        id={tooltipId}
        className={cn(tooltipClass, !open && "block-hidden")}
        ref={dialogElemRef}
      >
        {children}
      </dialog>
    </div>
  );
}
