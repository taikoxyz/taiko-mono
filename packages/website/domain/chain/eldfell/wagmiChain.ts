import { Chain } from "viem";
import { ELDFELL_CONFIG } from "./config";

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
