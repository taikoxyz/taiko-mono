import type { Address, Hash } from "viem";

import { chainConfig } from "@/config/generated/chainConfig";
import { Icon } from "@/components/Icon";
import { cn } from "@/lib/utils";
import { shortenAddress } from "@/libs/util/shortenAddress";

type ExplorerCategory = "address" | "tx" | "token";

export interface ExplorerLinkProps {
  urlParam: Hash | Address;
  chainId: number;
  category: ExplorerCategory;
  linkText?: string | null;
  shorten?: boolean;
  /** Passed through to the underlying <a> (mirrors the original `$$props.class`). */
  className?: string;
}

export default function ExplorerLink({
  urlParam,
  chainId,
  category,
  linkText = null,
  shorten = false,
  className,
}: ExplorerLinkProps) {
  const explorerLink = `${chainConfig[chainId]?.blockExplorers?.default.url}/${category}/${urlParam}`;

  return (
    <a
      href={explorerLink}
      className={cn("link f-row gap-1", className)}
      target="_blank"
      rel="noopener noreferrer"
    >
      {linkText ? (
        <span>{linkText}</span>
      ) : shorten ? (
        shortenAddress(urlParam, 8, 4)
      ) : (
        urlParam
      )}
      <Icon size={10} type="arrow-top-right" />
    </a>
  );
}
