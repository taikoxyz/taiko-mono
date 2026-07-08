import type { Address } from "viem";

export type FetchNftArgs = {
  address: Address;
  chainId: number;
  /** Defaults to false: serve cached pages when available. */
  refresh?: boolean;
};
