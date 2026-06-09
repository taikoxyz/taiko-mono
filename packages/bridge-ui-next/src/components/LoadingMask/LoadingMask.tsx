import { Spinner } from "@/components/Spinner";
import { cn } from "@/lib/utils";

export interface LoadingMaskProps {
  /** The text shown next to the spinner. Defaults to the literal "Loading" (matches the source default, not an i18n key). */
  text?: string;
  /** Extra classes merged onto the text span (mirrors Svelte `textClass`). */
  textClass?: string;
  /** Extra classes forwarded to the Spinner (mirrors Svelte `spinnerClass`). */
  spinnerClass?: string;
  /** Extra classes merged onto the root overlay (mirrors Svelte `$$props.class`). */
  className?: string;
}

export default function LoadingMask({
  text = "Loading",
  textClass = "",
  spinnerClass = "",
  className,
}: LoadingMaskProps) {
  const classes = cn(
    "gap-2 z-10",
    "f-center",
    "absolute",
    "top-0 bottom-0",
    "left-0 right-0",
    "overflow-hidden",
    "overlay-dialog",
    "text-white",
    className,
  );
  const textClasses = cn("body-regular", textClass);

  return (
    <div className={classes}>
      <Spinner className={spinnerClass} />
      <span className={textClasses}>{text}</span>
    </div>
  );
}
