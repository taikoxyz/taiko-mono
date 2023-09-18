import { TaikoL2Alpha5 } from "../baseTypes";

export const JOLNIR_CONFIG = {
  names: {
    lowercaseShortName: "jolnir",
    shortName: "Jolnir",
    shortishName: "Jolnir L2",
    mediumName: "Taiko Jolnir L2",
    longName: "Taiko Jolnir L2 (alpha-5)",
  },
  chainId: {
    decimal: 167007,
    hex: "0x28c5f",
  },
  nativeCurrency: {
    name: "Ether",
    symbol: "ETH",
    decimals: 18,
  },
  rpc: {
    https: "https://rpc.jolnir.taiko.xyz",
    wss: "wss://ws.jolnir.taiko.xyz",
  },
  blockExplorer: {
    name: "Blockscout",
    url: "https://explorer.jolnir.taiko.xyz",
  },
  testnet: true,
  rollupContracts: {
    // Protocol contracts
    taikoL2: {
      name: "TaikoL2",
      address: {
        impl: "0x1000777700000000000000000000000000000001",
      },
    },
    etherVault: {
      name: "EtherVault",
      address: {
        impl: "0x1000777700000000000000000000000000000003",
      },
    },
    erc20Vault: {
      name: "ERC20Vault",
      address: {
        impl: "0x1000777700000000000000000000000000000002",
      },
    },
    erc721Vault: {
      name: "ERC721Vault",
      address: {
        impl: "0x1000777700000000000000000000000000000008",
      },
    },
    erc1155Vault: {
      name: "ERC1155Vault",
      address: {
        impl: "0x1000777700000000000000000000000000000009",
      },
    },
    bridge: {
      name: "Bridge",
      address: {
        impl: "0x1000777700000000000000000000000000000004",
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
        name: "Bridged Taiko Token Jolnir",
        address: {
          impl: "0xe705498492D0aE94CA9365D395D2C6924F24F445",
        },
        decimals: 18,
        symbol: "TTKOj",
      },
      bridgedHorseToken: {
        name: "Bridged Horse Token",
        address: {
          impl: "0x9833DcA11f178dbaF2b88da42557DA2970534430",
        },
        decimals: 18,
        symbol: "HORSE",
      },
      bridgedBullToken: {
        name: "Bridged Bull Token",
        address: {
          impl: "0xc02D1fE3aA2134D2d7561e99f0A699C5Ca7B44ED",
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
        impl: "0xTODO(docs)",
      },
    },
    erc4337Entrypoint: {
      name: "ERC-4337 Entrypoint",
      address: {
        impl: "0xTODO(docs)",
      },
    },
  },
} as const satisfies TaikoL2Alpha5;
