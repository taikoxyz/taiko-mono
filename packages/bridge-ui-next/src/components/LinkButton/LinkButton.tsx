"use client";

import type { AnchorHTMLAttributes, ReactNode } from "react";
import { useMemo } from "react";

import Icon from "@/components/Icon";
import { cn } from "@/lib/utils";

export interface LinkButtonProps
  extends Omit<AnchorHTMLAttributes<HTMLAnchorElement>, "href"> {
  active?: boolean;
  href?: string;
  external?: boolean;
  children?: ReactNode;
}

export default function LinkButton({
  active = false,
  href = "/",
  external = false,
  className,
  children,
  ...rest
}: LinkButtonProps) {
  const activeClass = useMemo(
    () =>
      active
        ? "body-bold bg-primary-interactive text-grey-10 hover:!bg-primary-interactive hover:!text-grey-10"
        : "body-regular hover:bg-primary-interactive-hover",
    [active],
  );

  const classes = useMemo(
    () =>
      cn(
        "p-3 rounded-full flex justify-start content-center",
        activeClass,
        className,
      ),
    [activeClass, className],
  );

  return (
    <a
      href={href}
      target={external ? "_blank" : undefined}
      className={classes}
      {...rest}
    >
      {children}
      {external && (
        <div className="flex flex-grow justify-end">
          <Icon type="arrow-top-right" className="justify-self-end" />
        </div>
      )}
    </a>
  );
}
