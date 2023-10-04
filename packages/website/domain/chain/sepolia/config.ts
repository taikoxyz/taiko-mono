import { TaikoL1Alpha5 } from "../baseTypes";

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
        impl: "0xb6Ac7F87c35686b9db84cC51474895BA628f490E",
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
          proxy: "0x75F94f04d2144cB6056CCd0CFF1771573d838974",
          impl: "0xB3458D8Ba7fcA9Eab341E986005df155e1243AE4",
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
    },
  },
  otherContracts: {},
} as const satisfies TaikoL1Alpha5;
