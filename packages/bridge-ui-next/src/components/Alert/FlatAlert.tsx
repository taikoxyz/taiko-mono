import { Icon } from "@/components/Icon";
import { classNames } from "@/libs/util/classNames";

import type { AlertIconDetails, AlertType } from "./types";

type AlertTypeDetails = AlertIconDetails & {
  textClass: string;
};

export type FlatAlertProps = {
  type: AlertType;
  message: string;
  className?: string;
};

const typeMap: Record<AlertType, AlertTypeDetails> = {
  success: {
    textClass: "text-positive-sentiment",
    iconType: "check-circle",
    iconFillClass: "fill-success-content",
  },
  warning: {
    textClass: "text-warning-sentiment",
    iconType: "exclamation-circle",
    iconFillClass: "fill-warning-content",
  },
  error: {
    textClass: "text-negative-sentiment",
    iconType: "x-close-circle",
    iconFillClass: "fill-error-content",
  },
  info: {
    textClass: "text-secondary-content",
    iconType: "info-circle",
    iconFillClass: "fill-secondary-content",
  },
};

export default function FlatAlert({
  type,
  message,
  className,
}: FlatAlertProps) {
  const { textClass, iconType, iconFillClass } = typeMap[type];

  const classes = classNames("f-items-center space-x-1", className);

  return (
    <div className={classes}>
      <Icon type={iconType} fillClass={iconFillClass} />
      <div className={`body-small-regular ${textClass}`}>{message}</div>
    </div>
  );
}
