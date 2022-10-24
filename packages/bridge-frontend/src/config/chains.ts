import { Chain } from "../types";

export const chains: Record<string, Chain> = {
  31336: {
    id: 31336,
    name: "Mainnet",
    rpc: "http://34.132.67.34:8545",
    enabled: true,
  },
  167001: {
    id: 167001,
    name: "Taiko",
    rpc: "http://rpc.a1.testnet.taiko.xyz",
    enabled: true,
  },
};
