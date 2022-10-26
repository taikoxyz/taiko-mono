import type { Token } from "../types";

const mainnetTokens: Record<string, Token> = {
  "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48": {
    name: "USD Coin",
    address: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
    chainId: 31336,
    symbol: "USDC",
    decimals: 6,
    logoUrl: "ipfs://QmXfzKRvjZz3u5JRgC4v5mGVbm9ahrUiB4DgzHBsnWbTMM",
  },
};

export const tokensByChain: Record<number, Record<string, Token>> = {
  31336: mainnetTokens,
};
