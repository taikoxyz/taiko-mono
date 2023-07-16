// This file is the root config for all Taiko networks. They are inherited by other chain config formats (eg. wagmi, addEthereumChain).
// You only need to update here and the rest will update.

type TaikoConfig = {
  names: {
    lowercaseShortName: string;
    shortName: string; // used only after medium name or long name is used
    shortishName: string; // used on the bridge
    mediumName: string; // used for wallets
    longName: string; // full descriptive name
  };
  chainId: {
    decimal: number;
    hex: string;
  };
  nativeCurrency: {
    name: "Ether";
    symbol: "ETH";
    decimals: 18;
  };
  rpc: {
    https: string;
    wss?: string;
  },
  blockExplorer: {
    name: string;
    url: string;
  };
  testnet: boolean;
};

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
    https: "https://rpc.sepolia.org"
  },
  blockExplorer: {
    name: "Etherscan",
    url: "https://sepolia.etherscan.io/",
  }
} as const satisfies Partial<TaikoConfig>;

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
    wss: "wss://ws.test.taiko.xyz"
  },
  blockExplorer: {
    name: "blockscout",
    url: "https://explorer.test.taiko.xyz/",
  },
  testnet: true,
} as const satisfies TaikoConfig;

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
    wss: "wss://ws.l3test.taiko.xyz"
  },
  blockExplorer: {
    name: "blockscout",
    url: "https://explorer.l3test.taiko.xyz/",
  },
  testnet: true,
} as const satisfies TaikoConfig;
