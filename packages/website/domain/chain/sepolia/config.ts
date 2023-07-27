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
  basedContracts: {
    addressManager: {
      name: "AddressManager",
      address: {
        proxy: "0xB566C97d37662f8a5843D523bE7806e04b02D99d",
        impl: "0x98c5042C5fD3B38F250961546d271760b504278E",
      },
    },
    taikoL1: {
      name: "TaikoL1",
      address: {
        proxy: "0x6375394335f34848b850114b66A49D6F47f2cdA8",
        impl: "0x07eb4fe3c621393702cee6643af9c728fbac116a",
      },
    },
    tokenVault: {
      name: "TokenVault",
      address: {
        proxy: "0xD70506580B5F65e68ed0dbA7B4Ae507641C48197",
        impl: "0x90871108691796cee8307C8610Da353F4Ef41774",
      },
    },
    bridge: {
      name: "Bridge",
      address: {
        proxy: "0x7D992599E1B8b4508Ba6E2Ba97893b4C36C23A28",
        impl: "0xd7C538576c78ab62EFE867CffC23F7e722E73A7D",
      },
    },
    signalService: {
      name: "SignalService",
      address: {
        proxy: "0x23baAc3892a823e9E59B85d6c90068474fe60086",
        impl: "0x4E0924758cBbe463c58c6F2519086411d084f242",
      },
    },
    plonkVerifier: {
      name: "PlonkVerifier",
      address: {
        impl: "0xd46eb8cF2b47cd99bdb1dD8C76EEc55ac6eb930E",
      },
    },
    erc20Contracts: {
      taikoToken: {
        name: "Taiko Token",
        address: {
          proxy: "0xE52952B8063d0AE6Bd35E894866d8148976ce645",
          impl: "0x517976c137606f040168E5ec7f15e5d32f29C73F",
        },
        decimals: 8,
        symbol: "TTKO",
      },
      horseToken: {
        name: "Horse Token",
        address: {
          impl: "0x958b482c4E9479a600bFFfDDfe94D974951Ca3c7",
        },
        decimals: 18,
        symbol: "HORSE",
      },
      bullToken: {
        name: "Bull Token",
        address: {
          impl: "0x39e12053803898211F21047D56017986E0f070c1",
        },
        decimals: 18,
        symbol: "BLL",
      },
    },
  },
  otherContracts: {},
} as const satisfies TaikoL1Alpha3;
