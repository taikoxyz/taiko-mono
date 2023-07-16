import { TaikoL1Alpha3 } from "../baseTypes";

export const SEPOLIA_CONFIG = {
  names: {
    lowercaseShortName: "sepolia",
    shortName: "Sepolia",
    shortishName: "Sepolia L1",
    mediumName: "Sepolia L1",
    longName: "Sepolia L1",
  },
  chainId: {
    decimal: 11155111,
    hex: "0xaa36a7",
  },
  nativeCurrency: {
    name: "Ether",
    symbol: "ETH",
    decimals: 18,
  },
  rpc: {
    https: "https://rpc.sepolia.org",
  },
  blockExplorer: {
    name: "Etherscan",
    url: "https://sepolia.etherscan.io",
  },
  testnet: true,
  l1Contracts: {
    addressManager: {
      name: "AddressManager",
      address: {
        proxy: "0xAC9251ee97Ed8beF31706354310C6b020C35d87b",
        implementation: "0xA4b744c9f38B8822F217206373Ca6eed142F20BB",
      },
    },
    taikoL1: {
      name: "TaikoL1",
      address: {
        proxy: "0x4e7c942D51d977459108bA497FDc71ae0Fc54a00",
        implementation: "0x26Dc222448e28567af82CB6D6DEeeDe337102B2a",
      },
    },
    tokenVault: {
      name: "TokenVault",
      address: {
        proxy: "0xD90d8e85d0472eBC61267Ecbba544252b7197452",
        implementation: "0xCFa53BCa7677040Eb48143d09F42BcA45d76B5e8",
      },
    },
    bridge: {
      name: "Bridge",
      address: {
        proxy: "0x21561e1c1c64e18aB02654F365F3b0f7509d9481",
        implementation: "0x2c787dF59552bec40B7eEb4449cCb5403ae7B409",
      },
    },
    signalService: {
      name: "SignalService",
      address: {
        proxy: "0x5d2a35AC6464596b7aA04fdb69c5aFC37e391dFf",
        implementation: "0x844b0EC81a737AfF882ff93010613Bb09EcFC0e8",
      },
    },
    plonkVerifier: {
      name: "PlonkVerifier",
      address: "0x183b0B26120053729B01198fEa2Fc931F1AB4ADd",
    },
    taikoToken: {
      name: "Taiko Token",
      address: {
        proxy: "0x4e7c942D51d977459108bA497FDc71ae0Fc54a00",
        implementation: "0x26Dc222448e28567af82CB6D6DEeeDe337102B2a",
      },
      decimals: 8,
      symbol: "TTKO",
    },
    horseToken: {
      name: "Horse Token",
      address: "0x812d923E6a108900dF1304Dc5Bd96600837488DB",
      decimals: 18,
      symbol: "HORSE",
    },
    bullToken: {
      name: "Bull Token",
      address: "0xE2D396faef4F950AaBD4591F05cc0f29b63aC98A",
      decimals: 18,
      symbol: "BLL",
    },
  },
} as const satisfies TaikoL1Alpha3;
