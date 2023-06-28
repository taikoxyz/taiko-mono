async function ConnectToTaikoAlpha3() {
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

  const taikoParams: AddEthereumChainParameter = {
    chainId: "0x28c5d",
    chainName: "Taiko (Alpha-3 Testnet)",
    nativeCurrency: {
      name: "ETH",
      symbol: "eth",
      decimals: 18,
    },
    rpcUrls: ["https://rpc.test.taiko.xyz"],
    blockExplorerUrls: ["https://explorer.test.taiko.xyz/"],
    iconUrls: [],
  };

  if (!(window as any).ethereum) {
    alert("Metamask not detected! Install Metamask then try again.")
    return;
  }
  if ((window as any).ethereum.networkVersion == "167005") {
    alert("You are already connected to Taiko Alpha 3 (chainId 167005).", )
    return;
  }
  try{
    await (window as any).ethereum.request({
      method: "wallet_addEthereumChain",
      params: [taikoParams],
    });
  } catch (error) {
    alert("Failed to add the network with wallet_addEthereumChain request. Add the network with https://chainlist.org/ or do it manually. Error log: " + error.message)
  }
}

type Props = {
  buttonText: string;
};

export default function ConnectToTaikoAlpha3Button(props: Props) {
  return (
    <div
      onClick={() => ConnectToTaikoAlpha3()}
      className="hover:cursor-pointer text-neutral-900 bg-neutral-100 hover:bg-neutral-200 border-solid border-neutral-200 focus:ring-4 focus:outline-none focus:ring-neutral-100 font-medium rounded-lg text-sm px-3 py-2 text-center inline-flex items-center dark:focus:ring-neutral-600 dark:bg-neutral-800 dark:border-neutral-700 dark:text-white dark:hover:bg-neutral-700"
    >
      {props.buttonText}
      Click to Connect to Taiko Alpha 3
    </div>
  );
}