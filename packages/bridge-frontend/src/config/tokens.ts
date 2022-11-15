import type { Token } from "../types";

const mainnetTokens: Record<string, Token> = {
  "0x0000000000000000000000000000000000000000": {
    name: "Ether",
    address: "0x0000000000000000000000000000000000000000",
    chainId: 31336,
    symbol: "ETH",
    decimals: 18,
    logoUrl:
      "https://github.com/trustwallet/assets/blob/master/blockchains/ethereum/info/logo.png?raw=true",
  },
  // "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48": {
  //   name: "USD Coin",
  //   address: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
  //   chainId: 31336,
  //   symbol: "USDC",
  //   decimals: 6,
  //   logoUrl:
  //     "https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/ethereum/assets/0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48/logo.png",
  // },
};

const taikoTokens: Record<string, Token> = {
  "0x0000000000000000000000000000000000000000": {
    name: "Ether",
    address: "0x0000000000000000000000000000000000000000",
    chainId: 31336,
    symbol: "ETH",
    decimals: 18,
    logoUrl:
      "https://github.com/trustwallet/assets/blob/master/blockchains/ethereum/info/logo.png?raw=true",
  },
  // "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48": {
  //   name: "USD Coin",
  //   address: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
  //   chainId: 31336,
  //   symbol: "USDC",
  //   decimals: 6,
  //   logoUrl:
  //     "https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/ethereum/assets/0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48/logo.png",
  // },
};

export const tokensByChain: Record<number, Record<string, Token>> = {
  31336: mainnetTokens,
  167001: taikoTokens,
};
