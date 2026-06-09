"use client";

import { useEffect, useRef } from "react";

import { classNames } from "@/libs/util/classNames";

export interface LoadingTextProps {
  mask?: string;
  className?: string;
}

export default function LoadingText({
  mask = "Loading",
  className,
}: LoadingTextProps) {
  const maskRef = useRef<HTMLSpanElement>(null);

  const classes = classNames("animate-pulse rounded-md", className);

  useEffect(() => {
    const maskElem = maskRef.current;
    if (!maskElem) return;
    // The idea is to use same background color as text color
    const textColor = globalThis
      .getComputedStyle(maskElem)
      .getPropertyValue("color");
    maskElem.style.backgroundColor = textColor;
  }, []);

  return (
    <span className={classes} ref={maskRef}>
      {mask}
    </span>
  );
}
