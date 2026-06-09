import { Icon } from "@/components/Icon";

type StatusType = "success" | "pending" | "error";

export interface StatusDotProps {
  type: StatusType;
  simple?: boolean;
}

const typeMap: Record<StatusType, string> = {
  success: "fill-positive-sentiment",
  pending: "fill-warning-sentiment",
  error: "fill-negative-sentiment",
};

export default function StatusDot({ type, simple = true }: StatusDotProps) {
  return (
    <Icon
      type={simple ? "circle" : "status-circle"}
      fillClass={typeMap[type]}
      className="min-w-[20px] max-w-[20px]"
    />
  );
}
