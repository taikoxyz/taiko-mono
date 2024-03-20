const networks = [
  {
    name: "Ethereum (Holesky)",
    chainId: 17000,
    rpc: "https://rpc.holesky.taiko.xyz",
    symbol: "ETH",
    blockExplorer: "https://holesky.etherscan.io",
  },
  {
    name: "Taiko (Katla)",
    chainId: 167008,
    rpc: "https://rpc.katla.taiko.xyz",
    symbol: "ETH",
    blockExplorer: "https://katla.taikoscan.network",
  },
];

function promptNetworkChange() {
  const currentNetwork = "https://rpc.katla.taiko.xyz"; // Example current network URL
  const desiredNetwork = "https://rpc.holesky.taiko.xyz"; // Example desired network URL

  if (currentNetwork !== desiredNetwork) {
    alert(`Please switch to ${desiredNetwork}`);
    // You can add code here to trigger wallet network change automatically
  } else {
    console.log("Already on the desired network");
  }
}

// Call the function to prompt network change
promptNetworkChange();
