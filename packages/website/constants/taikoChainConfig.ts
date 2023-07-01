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

export const taikoChainConfig: AddEthereumChainParameter = {
  chainId: "0x28c5d",
  chainName: "Taiko (Alpha-3 Testnet)",
  nativeCurrency: {
    name: "ETH",
    symbol: "ETH",
    decimals: 18,
  },
  rpcUrls: ["https://rpc.test.taiko.xyz"],
  blockExplorerUrls: ["https://explorer.test.taiko.xyz/"],
  iconUrls: [],
};
