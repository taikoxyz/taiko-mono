// networks.js
export const networks = [
  {
    name: "Holesky",
    chainId: 17000,
    rpcUrlL1: "https://l1rpc.hekla.taiko.xyz",
    rpcUrlL2: "https://rpc.hekla.taiko.xyz",
    taikoL1Address: "0x79C9109b764609df928d16fC4a91e9081F7e87DB",
    fromBlock: 4280000,
    toBlock: "latest"
  },
  /*
  {
    name: "Ethereum",
    chainId: 1,
    rpcUrlL1: "https://l1rpc.mainnet.taiko.xyz/",
    rpcUrlL2: "https://rpc.mainnet.taiko.xyz/",
    taikoL1Address: "0x06a9Ab27c7e2255df1815E6CC0168d7755Feb19a",
    fromBlock: 22432338, // Taiko L1 Mainnet deployment block
    toBlock: "latest"
  }
  */
];
