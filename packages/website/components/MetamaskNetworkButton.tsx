type Props = {
  buttonText: string;
};

async function ConnectToMetamask(props: Props) {
  if (!(window as any).ethereum) {
    alert("Wallet not detected! Install Metamask then try again.");
    return;
  }
  if(props.buttonText == "Connect to Sepolia"){
    ConnectToSepolia();
  }
  if(props.buttonText == "Connect to Taiko"){
    ConnectToTaiko();
  }
}

async function ConnectToSepolia() {
  if (!(window as any).ethereum) {
    alert("Metamask not detected! Install Metamask then try again.")
    return;
  }
  if ((window as any).ethereum.networkVersion == "11155111") {
    alert("You are already connected to Sepolia (chainId 11155111).", )
    return;
  }
  try{
    await (window as any).ethereum.request({
      method: "wallet_switchEthereumChain",
      params: [{
         chainId: "0xaa36a7"
      }]
    });
  } catch (error) {
    alert("Failed to add the network with wallet_addEthereumChain request. Add the network with https://chainlist.org/ or do it manually. Error log: " + error.message)
  }
}

async function ConnectToTaiko() {
  if ((window as any).ethereum.networkVersion == "167005") {
    alert("You are already connected to Taiko Alpha 3 (chainId 167005).", )
    return;
  }
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
    // iconUrls?: string[]; // Currently ignored.
  }
  const taikoParams: AddEthereumChainParameter = {
    chainId: "0x28c5d",
    chainName: "Taiko (Alpha-3 Testnet)",
    nativeCurrency: {
      name: "Ether",
      symbol: "ETH",
      decimals: 18,
    },
    rpcUrls: ["https://rpc.test.taiko.xyz"],
    blockExplorerUrls: ["https://explorer.test.taiko.xyz/"],
    // iconUrls: [],
  };
  try{
    await (window as any).ethereum.request({
      method: "wallet_addEthereumChain",
      params: [taikoParams],
    });
  } catch (error) {
    alert("Failed to add the network with wallet_addEthereumChain request. Add the network with https://chainlist.org/ or do it manually. Error log: " + error.message)
  } 
}

export default function ConnectToMetamaskButton(props: Props) {
  return (
    <div
      onClick={() => ConnectToMetamask(props)}
      className="hover:cursor-pointer text-neutral-900 bg-neutral-100 hover:bg-neutral-200 border-solid border-neutral-200 focus:ring-4 focus:outline-none focus:ring-neutral-100 font-medium rounded-lg text-sm px-3 py-2 text-center inline-flex items-center dark:focus:ring-neutral-600 dark:bg-neutral-800 dark:border-neutral-700 dark:text-white dark:hover:bg-neutral-700"
    >
      {props.buttonText}
    </div>
  );
}