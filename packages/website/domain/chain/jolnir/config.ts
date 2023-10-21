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
        proxy: "0x1000777700000000000000000000000000000001",
        impl: "0x1c7a1688604a79616826993A1AC27e802cC8b17D",
      },
    },
    etherVault: {
      name: "EtherVault",
      address: {
        proxy: "0x1000777700000000000000000000000000000003",
        impl: "0x0000777700000000000000000000000000000003",
      },
    },
    erc20Vault: {
      name: "ERC20Vault",
      address: {
        proxy: "0x1000777700000000000000000000000000000002",
        impl: "0x0000777700000000000000000000000000000002",
      },
    },
    erc721Vault: {
      name: "ERC721Vault",
      address: {
        proxy: "0x1000777700000000000000000000000000000008",
        impl: "0x0000777700000000000000000000000000000008",
      },
    },
    erc1155Vault: {
      name: "ERC1155Vault",
      address: {
        proxy: "0x1000777700000000000000000000000000000009",
        impl: "0x0000777700000000000000000000000000000009",
      },
    },
    bridge: {
      name: "Bridge",
      address: {
        proxy: "0x1000777700000000000000000000000000000004",
        impl: "0x0000777700000000000000000000000000000004",
      },
    },
    signalService: {
      name: "SignalService",
      address: {
        proxy: "0x1000777700000000000000000000000000000007",
        impl: "0x0000777700000000000000000000000000000007",
      },
    },
    // Bridged ERC-20 contracts
    erc20Contracts: {
      bridgedTaikoToken: {
        name: "Bridged Taiko Token Jolnir",
        address: {
          proxy: "0xe705498492D0aE94CA9365D395D2C6924F24F445",
          impl: "0x29E2e05dcE30299A90Fd212F6c680692BF7f1dC5",
        },
        decimals: 18,
        symbol: "TTKOj",
      },
      bridgedHorseToken: {
        name: "Bridged Horse Token",
        address: {
          proxy: "0x9833DcA11f178dbaF2b88da42557DA2970534430",
          impl: "0x5B9F2597FF055bfC304F1276048AB65fFde8FbEA",
        },
        decimals: 18,
        symbol: "HORSE",
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
        impl: "0x4e59b44847b379578588920ca78fbf26c0b4956c",
      },
    },
    weth: {
      name: "WETH",
      address: {
        impl: "0xf86E3b4cde65c0cd59580Ee3F8dd34343E23ea5B",
      },
    },
    v3CoreFactoryAddress: {
      name: "Uniswap V3 Core Factory",
      address: {
        impl: "0xae2C46ddb314B9Ba743C6dEE4878F151881333D9",
      },
    },
    multicallAddress: {
      name: "Multicall",
      address: {
        impl: "0xC4d03e4055381525F9d7B545f87AC6F7c114218D",
      },
    },
    tickLensAddress: {
      name: "TickLens",
      address: {
        impl: "0xaF23C54A651A548Eb17B9aF1Fd5b33a224579769",
      },
    },
    nonfungiblePositionManagerAddress: {
      name: "NonfungiblePositionManager",
      address: {
        impl: "0x0b89d0FB71B81D0C04f3F71c47bbBd128896DA6b",
      },
    },
    v3MigratorAddress: {
      name: "Uniswap V3 Migrator",
      address: {
        impl: "0xA4ACE40E895C11977a57FbCE154F2790f1C18892",
      },
    },
    swapRouter02Address: {
      name: "SwapRouter02",
      address: {
        impl: "0x73B721608Ec729cE60c8a2746Ea3dcdd36a4EA10",
      },
    },
  },
} as const satisfies TaikoL2Alpha5;
