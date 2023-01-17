type Props = {
  buttonText: string;
  chain: string;
};

async function addEthereumChain(chain: string) {
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
  const l1params: AddEthereumChainParameter = {
    chainId: "0x7A6A",
    chainName: "Ethereum A1 (Taiko)",
    nativeCurrency: {
      name: "ETH",
      symbol: "eth",
      decimals: 18,
    },
    rpcUrls: ["https://l1rpc.a1.taiko.xyz"],
    blockExplorerUrls: ["https://l1explorer.a1.taiko.xyz/"],
    iconUrls: [],
  };

  const l2params: AddEthereumChainParameter = {
    chainId: "0x28C5B",
    chainName: "Taiko A1 (Taiko)",
    nativeCurrency: {
      name: "ETH",
      symbol: "eth",
      decimals: 18,
    },
    rpcUrls: ["https://l2rpc.a1.taiko.xyz"],
    blockExplorerUrls: ["https://l2explorer.a1.taiko.xyz/"],
    iconUrls: [],
  };

  const params = chain === "l1" ? l1params : l2params;

  await (window as any).ethereum.request({
    method: "wallet_addEthereumChain",
    params: [params],
  });
}

export default function AddEthereumChainButton(props: Props) {
  return (
    <div
      onClick={() => addEthereumChain(props.chain)}
      className="hover:cursor-pointer text-neutral-900 bg-white hover:bg-neutral-100 border-solid border-neutral-200 focus:ring-4 focus:outline-none focus:ring-neutral-100 font-medium rounded-lg text-sm px-3 py-2 text-center inline-flex items-center dark:focus:ring-neutral-600 dark:bg-neutral-800 dark:border-neutral-700 dark:text-white dark:hover:bg-neutral-700"
    >
      {props.buttonText}
    </div>
  );
}
