const chainIdToBlockExplorerUrl = (chainId: number, hash: string): string => {
  let network: string = "";
  if (chainId === 5) {
    network = "goerli";
  } else {
    network = "rinkeby";
  }
  if (network) return `https://${network}.etherscan.io/tx/${hash}`;
  return `https://etherscan.io/tx/${hash}`;
};

export default chainIdToBlockExplorerUrl;
