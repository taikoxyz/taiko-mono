// Test stand-in for the generated $bridgeConfig module — ported from the
// original packages/bridge-ui/__mocks__/$bridgeConfig.ts. The vitest config
// aliases `$bridgeConfig` here (the app build aliases it to
// src/config/generated/bridgeConfig.ts, which is an empty placeholder without
// real CONFIGURED_BRIDGES env).
import {
  L1_ADDRESSES,
  L2_A_ADDRESSES,
  L3_ADDRESSES,
} from "./addresses";

export const routingContractsMap = {
  1: {
    2: L1_ADDRESSES,
  },
  2: {
    1: L2_A_ADDRESSES,
  },
  3: {
    2: L3_ADDRESSES,
  },
  32382: {
    167001: {
      bridgeAddress: "0x1c406D71342D2C368e3B35F5c3F573E51Aa2E88f",
      signalServiceAddress: "0xC51aaC3cfF330586435cf2168FAd9E5F3c1a8654",
    },
  },
  167001: {
    32382: {
      bridgeAddress: "0x1670010000000000000000000000000000000001",
      signalServiceAddress: "0x1670010000000000000000000000000000000005",
    },
  },
};
