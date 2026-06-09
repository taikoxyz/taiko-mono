import * as React from "react";

import { cn } from "@/lib/utils";

function Skeleton({
  className,
  ...props
}: React.ComponentPropsWithoutRef<"div">) {
  return (
    <div
      className={cn("animate-pulse rounded-md bg-muted", className)}
      {...props}
    />
  );
}

export { Skeleton };
