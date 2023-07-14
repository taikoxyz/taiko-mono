interface AddEthereumChainParameter {
  chainId: string; // A 0x-prefixed hexadecimal string
  chainName: string;
  nativeCurrency: {
    name: string;
    symbol: string; // 2-6 characters long
    decimals: 18;
  };
  rpcUrls: string[];
  blockExplorerUrls?: string[];
  iconUrls?: string[]; // Currently ignored.
}

const grimsvotnChainConfig: AddEthereumChainParameter = {
  chainId: "0x28c5d",
  chainName: "Taiko L2 (Grimsvotn)",
  nativeCurrency: {
    name: "ETH",
    symbol: "ETH",
    decimals: 18,
  },
  rpcUrls: ["https://rpc.test.taiko.xyz"],
  blockExplorerUrls: ["https://explorer.test.taiko.xyz/"],
  iconUrls: [],
};

const eldfellChainConfig: AddEthereumChainParameter = {
  chainId: "0x28c5d",
  chainName: "Taiko L3 (Eldfell)",
  nativeCurrency: {
    name: "ETH",
    symbol: "ETH",
    decimals: 18,
  },
  rpcUrls: ["https://l3rpc.test.taiko.xyz"],
  blockExplorerUrls: ["https://l3explorer.test.taiko.xyz/"],
  iconUrls: [],
};

export { grimsvotnChainConfig, eldfellChainConfig };
