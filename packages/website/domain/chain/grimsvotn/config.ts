import { TaikoL1Alpha4, TaikoL2Alpha3 } from "../baseTypes";

export const GRIMSVOTN_CONFIG = {
  names: {
    lowercaseShortName: "grimsvotn",
    shortName: "Grimsvotn",
    shortishName: "Grimsvotn L2",
    mediumName: "Taiko Grimsvotn L2",
    longName: "Taiko Grimsvotn L2 (alpha-3)",
  },
  chainId: {
    decimal: 167005,
    hex: "0x28c5d",
  },
  nativeCurrency: {
    name: "Ether",
    symbol: "ETH",
    decimals: 18,
  },
  rpc: {
    https: "https://rpc.test.taiko.xyz",
    wss: "wss://ws.test.taiko.xyz",
  },
  blockExplorer: {
    name: "Blockscout",
    url: "https://explorer.test.taiko.xyz",
  },
  testnet: true,
  basedContracts: {
    addressManager: {
      name: "AddressManager",
      address: {
        proxy: "0xAC9251ee97Ed8beF31706354310C6b020C35d87b",
        impl: "0xA4b744c9f38B8822F217206373Ca6eed142F20BB",
      },
    },
    taikoL1: {
      name: "TaikoL1",
      address: {
        proxy: "0x4e7c942D51d977459108bA497FDc71ae0Fc54a00",
        impl: "0xe212f20F518eBA52260B61986c0A538aD6cC23bB",
      },
    },
    tokenVault: {
      name: "TokenVault",
      address: {
        proxy: "0xD90d8e85d0472eBC61267Ecbba544252b7197452",
        impl: "0xCFa53BCa7677040Eb48143d09F42BcA45d76B5e8",
      },
    },
    bridge: {
      name: "Bridge",
      address: {
        proxy: "0x21561e1c1c64e18aB02654F365F3b0f7509d9481",
        impl: "0x2c787dF59552bec40B7eEb4449cCb5403ae7B409",
      },
    },
    signalService: {
      name: "SignalService",
      address: {
        proxy: "0x5d2a35AC6464596b7aA04fdb69c5aFC37e391dFf",
        impl: "0x844b0EC81a737AfF882ff93010613Bb09EcFC0e8",
      },
    },
    proverPool: {
      name: "ProverPool",
      address: {
        proxy: "0xC9580414A4372BDdBd8e19e01854DC0B2b1390Cf",
        impl: "0xD2951Ec51a2724aE37fA697E20643232fa810C0c",
      },
    },
    plonkVerifier: {
      name: "PlonkVerifier",
      address: {
        impl: "0x183b0B26120053729B01198fEa2Fc931F1AB4ADd",
      },
    },
    erc20Contracts: {
      taikoToken: {
        name: "Taiko Token Eldfell",
        symbol: "TTKOe",
        decimals: 8,
        address: {
          proxy: "0x4284890d4AcD0bcb017eCE481B96fD4Cb457CAc8",
          impl: "0x81d4843aCBD5bB37580033951300804091516d81",
        },
      },
    },
  },
  rollupContracts: {
    // Protocol contracts
    taikoL2: {
      name: "TaikoL2",
      address: {
        impl: "0x1000777700000000000000000000000000000001",
      },
    },
    bridge: {
      name: "Bridge",
      address: {
        impl: "0x1000777700000000000000000000000000000004",
      },
    },
    tokenVault: {
      name: "TokenVault",
      address: {
        impl: "0x1000777700000000000000000000000000000002",
      },
    },
    etherVault: {
      name: "EtherVault",
      address: {
        impl: "0x1000777700000000000000000000000000000003",
      },
    },
    signalService: {
      name: "SignalService",
      address: {
        impl: "0x1000777700000000000000000000000000000007",
      },
    },
    // Bridged ERC-20 contracts
    erc20Contracts: {
      bridgedTaikoToken: {
        name: "Bridged Taiko Token",
        address: {
          impl: "0x7b1a3117B2b9BE3a3C31e5a097c7F890199666aC",
        },
        decimals: 8,
        symbol: "TTKO",
      },
      bridgedHorseToken: {
        name: "Bridged Horse Token",
        address: {
          impl: "0xa4505BB7AA37c2B68CfBC92105D10100220748EB",
        },
        decimals: 18,
        symbol: "HORSE",
      },
      bridgedBullToken: {
        name: "Bridged Bull Token",
        address: {
          impl: "0x6302744962a0578E814c675B40909e64D9966B0d",
        },
        decimals: 18,
        symbol: "BLL",
      },
    },
  },
  otherContracts: {
    deterministicDeploymentProxy: {
      name: "Deterministic Deployment Proxy",
      address: {
        impl: "0x4e59b44847b379578588920ca78fbf26c0b4956c",
      },
    },
    erc4337Entrypoint: {
      name: "ERC-4337 Entrypoint",
      address: {
        impl: "0x3e871218D1c0A1670552aFFcB8adFDE98f6FA4F8",
      },
    },
  },
} as const satisfies TaikoL1Alpha4 & TaikoL2Alpha3;
