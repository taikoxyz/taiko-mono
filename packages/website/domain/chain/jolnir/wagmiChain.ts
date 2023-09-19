import { Chain } from "viem";
import { JOLNIR_CONFIG } from "./config";

export const taikoJOLNIR = {
  id: JOLNIR_CONFIG.chainId.decimal,
  name: JOLNIR_CONFIG.names.mediumName,
  network: JOLNIR_CONFIG.names.lowercaseShortName,
  nativeCurrency: JOLNIR_CONFIG.nativeCurrency,
  rpcUrls: {
    public: {
      http: [JOLNIR_CONFIG.rpc.https],
    },
    default: {
      http: [JOLNIR_CONFIG.rpc.https],
    },
  },
  blockExplorers: {
    default: {
      name: JOLNIR_CONFIG.blockExplorer.name,
      url: JOLNIR_CONFIG.blockExplorer.url,
    },
  },
  testnet: JOLNIR_CONFIG.testnet,
} as const satisfies Chain;
