// React port of src/components/Transactions/ChainSymbol.svelte.
//
// COMPONENT CONVENTION mapping:
//   - `export let chainId: ChainID` -> typed `chainId` prop.
//   - Svelte's implicit `$$props.class` (forwarded onto the root div) ->
//     optional `className` prop, merged via `cn()`.
//
// DOM / Tailwind class strings preserved verbatim for pixel parity, including
// the stray `'}` literal present in the original class attribute.

import { chainConfig } from "$chainConfig";
import type { ChainID } from "@/libs/chain";
import { cn } from "@/lib/utils";

export interface ChainSymbolProps {
  chainId: ChainID;
  className?: string;
}

export default function ChainSymbol({ chainId, className }: ChainSymbolProps) {
  const icon = chainConfig[Number(chainId)]?.icon || "Unknown Chain";

  return (
    <div
      className={cn(
        "flex md:items-stretch self-center justify-items-start'}",
        className,
      )}
    >
      <img src={icon} alt="chain-logo" className="rounded-full w-5 h-5 mr-2" />
    </div>
  );
}
