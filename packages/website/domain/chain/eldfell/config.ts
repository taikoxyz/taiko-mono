import { TaikoL2Alpha4 } from "../baseTypes";

export const ELDFELL_CONFIG = {
  names: {
    lowercaseShortName: "eldfell",
    shortName: "Eldfell",
    shortishName: "Eldfell L3",
    mediumName: "Taiko Eldfell L3",
    longName: "Taiko Eldfell L3 (alpha-4)",
  },
  chainId: {
    decimal: 167006,
    hex: "0x28c5e",
  },
  nativeCurrency: {
    name: "Ether",
    symbol: "ETH",
    decimals: 18,
  },
  rpc: {
    https: "https://rpc.l3test.taiko.xyz",
    wss: "wss://ws.l3test.taiko.xyz",
  },
  blockExplorer: {
    name: "Blockscout",
    url: "https://explorer.l3test.taiko.xyz",
  },
  testnet: true,
  rollupContracts: {
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
        name: "Bridged Taiko Token Eldfell",
        address: {
          impl: "0x804fade1e0f9b1f5af6bef6c615c9af3af823336",
        },
        decimals: 8,
        symbol: "TTKOe",
      },
      bridgedHorseToken: {
        name: "Bridged Bridged Horse Token",
        address: {
          impl: "0x060b5388daf7e57b52bf5959a9fe8462b88a9b86",
        },
        decimals: 18,
        symbol: "HORSE",
      },
      bridgedBullToken: {
        name: "Bridged Bridged Bull Token",
        address: {
          impl: "0x8fa0a752c585b749a5a8d555cc50a350c93f7693",
        },
        decimals: 18,
        symbol: "BLL",
      },
    },
  },
  otherContracts: {},
} as const satisfies TaikoL2Alpha4;
