import type { ReactNode } from "react";

import { Icon } from "@/components/Icon";
import { classNames } from "@/libs/util/classNames";

import type { AlertIconDetails, AlertType } from "./types";

type AlertTypeDetails = AlertIconDetails & {
  alertClass: string;
};

export type AlertProps = {
  type: AlertType;
  forceColumnFlow?: boolean;
  className?: string;
  children?: ReactNode;
};

const typeMap: Record<AlertType, AlertTypeDetails> = {
  success: {
    alertClass: "alert-success",
    iconType: "check-circle",
    iconFillClass: "fill-success-content",
  },
  warning: {
    alertClass: "alert-warning",
    iconType: "exclamation-circle",
    iconFillClass: "fill-warning-content",
  },
  error: {
    alertClass: "alert-error",
    iconType: "x-close-circle",
    iconFillClass: "fill-error-content",
  },
  info: {
    alertClass: "alert-info",
    iconType: "info-circle",
    iconFillClass: "fill-info-content",
  },
};

export default function Alert({
  type,
  forceColumnFlow = false,
  className,
  children,
}: AlertProps) {
  const { alertClass, iconType, iconFillClass } = typeMap[type];

  const classes = classNames(
    "alert flex gap-[5px] py-[12px] px-[20px] rounded-[10px]",
    type ? alertClass : null,
    forceColumnFlow ? "grid-flow-col text-left" : null,
    className,
  );

  return (
    <div className={classes}>
      <div className="self-start">
        <Icon type={iconType} fillClass={iconFillClass} size={24} />
      </div>
      <div className="callout-regular">{children}</div>
    </div>
  );
}
