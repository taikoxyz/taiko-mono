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
    name: "blockscout",
    url: "https://explorer.test.taiko.xyz",
  },
  testnet: true,
  l1Contracts: {
    addressManager: {
      name: "AddressManager",
      address: {
        proxy: "0xB566C97d37662f8a5843D523bE7806e04b02D99d",
        implementation: "0x98c5042C5fD3B38F250961546d271760b504278E",
      },
    },
    taikoL1: {
      name: "TaikoL1",
      address: {
        proxy: "0x6375394335f34848b850114b66A49D6F47f2cdA8",
        implementation: "0x07eb4fe3c621393702cee6643af9c728fbac116a",
      },
    },
    tokenVault: {
      name: "TokenVault",
      address: {
        proxy: "0xD70506580B5F65e68ed0dbA7B4Ae507641C48197",
        implementation: "0x90871108691796cee8307C8610Da353F4Ef41774",
      },
    },
    bridge: {
      name: "Bridge",
      address: {
        proxy: "0x7D992599E1B8b4508Ba6E2Ba97893b4C36C23A28",
        implementation: "0xd7C538576c78ab62EFE867CffC23F7e722E73A7D",
      },
    },
    signalService: {
      name: "SignalService",
      address: {
        proxy: "0x23baAc3892a823e9E59B85d6c90068474fe60086",
        implementation: "0x4E0924758cBbe463c58c6F2519086411d084f242",
      },
    },
    proverPool: {
      name: "ProverPool",
      address: {
        proxy: "0xc06e918ED0B596ED975bc940eD15dF552547Fcd1",
        implementation: "0x96DD8A2ed8C46Cb40D96BfE1118ca4B5A718857e",
      },
    },
    plonkVerifier: {
      name: "PlonkVerifier",
      address: "0xd46eb8cF2b47cd99bdb1dD8C76EEc55ac6eb930E",
    },
    taikoToken: {
      name: "Taiko Token",
      address: {
        proxy: "0xE52952B8063d0AE6Bd35E894866d8148976ce645",
        implementation: "0x517976c137606f040168E5ec7f15e5d32f29C73F",
      },
      decimals: 8,
      symbol: "TTKO",
    },
    horseToken: {
      name: "Horse Token",
      address: "0x958b482c4E9479a600bFFfDDfe94D974951Ca3c7",
      decimals: 18,
      symbol: "HORSE",
    },
    bullToken: {
      name: "Bull Token",
      address: "0x39e12053803898211F21047D56017986E0f070c1",
      decimals: 18,
      symbol: "BLL",
    },
  },
  l2Contracts: {
    // Protocol contracts
    taikoL2: {
      name: "TaikoL2",
      address: "0x1000777700000000000000000000000000000001",
    },
    bridge: {
      name: "Bridge",
      address: "0x1000777700000000000000000000000000000004",
    },
    tokenVault: {
      name: "TokenVault",
      address: "0x1000777700000000000000000000000000000002",
    },
    etherVault: {
      name: "EtherVault",
      address: "0x1000777700000000000000000000000000000003",
    },
    signalService: {
      name: "SignalService",
      address: "0x1000777700000000000000000000000000000007",
    },
    // Bridged ERC-20 contracts
    bridgedTaikoToken: {
      name: "Bridged Taiko Token",
      address: "0x7b1a3117B2b9BE3a3C31e5a097c7F890199666aC",
      decimals: 8,
      symbol: "TTKO", // TODO is that right
    },
    bridgedHorseToken: {
      name: "Bridged Horse Token",
      address: "0xa4505BB7AA37c2B68CfBC92105D10100220748EB",
      decimals: 18,
      symbol: "HORSE",
    },
    bridgedBullToken: {
      name: "Bridged Bull Token",
      address: "0x6302744962a0578E814c675B40909e64D9966B0d",
      decimals: 18,
      symbol: "BLL",
    },
  },
  otherContracts: [
    {
      name: "Deterministic Deployment Proxy",
      address: "0x1C83d994f649E62cAA042097415d050732f53FF6",
    },
    {
      name: "ERC-4337 Entrypoint",
      address: "0x3e871218D1c0A1670552aFFcB8adFDE98f6FA4F8",
    },
  ],
} as const satisfies TaikoL1Alpha4 & TaikoL2Alpha3;
