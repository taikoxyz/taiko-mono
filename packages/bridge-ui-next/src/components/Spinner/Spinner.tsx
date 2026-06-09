import type { ComponentPropsWithoutRef } from "react";

import { cn } from "@/lib/utils";

export type SpinnerProps = ComponentPropsWithoutRef<"span">;

/**
 * Leaf primitive. Mirrors the original bridge-ui `Spinner.svelte`:
 * a `<span class="w-6 h-6 loading loading-spinner">` with an optional
 * caller-provided class merged in (Svelte `$$props.class` -> React `className`).
 * The `loading`/`loading-spinner` daisyUI classes are ported verbatim into
 * globals.css so this renders identically without daisyUI installed.
 */
export default function Spinner({ className, ...props }: SpinnerProps) {
  return (
    <span
      className={cn("w-6 h-6", "loading loading-spinner", className)}
      {...props}
    />
  );
}
