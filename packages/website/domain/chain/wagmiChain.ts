import { Chain } from "viem";
import { GRIMSVOTN_CONFIG, ELDFELL_CONFIG } from "./config";

export const taikoGrimsvotn = {
  id: GRIMSVOTN_CONFIG.chainId.decimal,
  name: GRIMSVOTN_CONFIG.names.mediumName,
  network: GRIMSVOTN_CONFIG.names.lowercaseShortName,
  nativeCurrency: GRIMSVOTN_CONFIG.nativeCurrency,
  rpcUrls: {
    public: {
      http: [GRIMSVOTN_CONFIG.rpc.https],
    },
    default: {
      http: [GRIMSVOTN_CONFIG.rpc.https],
    },
  },
  blockExplorers: {
    default: {
      name: GRIMSVOTN_CONFIG.blockExplorer.name,
      url: GRIMSVOTN_CONFIG.blockExplorer.url,
    },
  },
  testnet: GRIMSVOTN_CONFIG.testnet,
} as const satisfies Chain;

export const taikoEldfell = {
  id: ELDFELL_CONFIG.chainId.decimal,
  name: ELDFELL_CONFIG.names.mediumName,
  network: ELDFELL_CONFIG.names.lowercaseShortName,
  nativeCurrency: ELDFELL_CONFIG.nativeCurrency,
  rpcUrls: {
    public: {
      http: [ELDFELL_CONFIG.rpc.https],
    },
    default: {
      http: [ELDFELL_CONFIG.rpc.https],
    },
  },
  blockExplorers: {
    default: {
      name: ELDFELL_CONFIG.blockExplorer.name,
      url: ELDFELL_CONFIG.blockExplorer.url,
    },
  },
  testnet: ELDFELL_CONFIG.testnet,
} as const satisfies Chain;
