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
        proxy: "0x6b390878aCf6e3AdF5fAEb4771c6FB6be518D569",
        impl: "0x39bF8d5A8Ad841381E4075A009035a6a22d46bFE",
      },
    },
    taikoL1: {
      name: "TaikoL1",
      address: {
        proxy: "0x95fF8D3CE9dcB7455BEB7845143bEA84Fe5C4F6f",
        impl: "0xD0979F959D788dD0C55c743Cb5D5c2175F2AB097",
      },
    },
    erc20Vault: {
      name: "ERC20Vault",
      address: {
        proxy: "0x9f1a34A0e4f6C77C3648C4d9E922DA615C64D194",
        impl: "0xA17D83Fe61bF1D13446ed70A50dDab8b400Fa988",
      },
    },
    erc721Vault: {
      name: "ERC721Vault",
      address: {
        proxy: "0x116649D245c08979E20FeDa89162A3D02fFeA88a",
        impl: "0xFc168aF3235C76bDb8C544b71E4d55c458EbA2cf",
      },
    },
    erc1155Vault: {
      name: "ERC1155Vault",
      address: {
        proxy: "0xF92938C48D078797E1Eb201D0fbB1Ac739F50B90",
        impl: "0xFbBE73bD5682Db685eAe986d713F84Af4851b2e9",
      },
    },
    bridge: {
      name: "Bridge",
      address: {
        proxy: "0x5293Bb897db0B64FFd11E0194984E8c5F1f06178",
        impl: "0xa239b8f15e3BF3789D184873300cB6bdCe3BcC05",
      },
    },
    signalService: {
      name: "SignalService",
      address: {
        proxy: "0xcD5e2bebd3DfE46e4BF96aE2ac7B89B22cc6a982",
        impl: "0xD3ac5E6d9DB6e9845f53521D36b81cc14dA5424a",
      },
    },
    proofVerifier: {
      name: "ProofVerifier",
      address: {
        proxy: "0xdC396C7478C5C985fc19386BdD29370e10572ed9",
        impl: "0x05764AeD55E200200C0f50AAdEa377E9cf3C6Fb0",
      },
    },
    erc20Contracts: {
      taikoToken: {
        name: "Taiko Token Jolnir",
        symbol: "TTKOj",
        decimals: 18,
        address: {
          proxy: "0x4284890d4AcD0bcb017eCE481B96fD4Cb457CAc8",
          impl: "0x81d4843aCBD5bB37580033951300804091516d81",
        },
      },
      horseToken: {
        name: "Horse Token",
        symbol: "HORSE",
        decimals: 18,
        address: {
          impl: "0xe9f36Ec3F1B8056A67a2B542551D248D511aA7d6",
        },
      },
      bullToken: {
        name: "Bull Token",
        symbol: "BLL",
        decimals: 18,
        address: {
          impl: "0x0505f8EA58319b96bd7FffCec82d29AcC78Fb57e",
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
