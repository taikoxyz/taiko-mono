import React from "react";

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
    chainId: "0x7A68",
    chainName: "Taiko Testnet L1",
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
    chainId: "0x28C59",
    chainName: "Taiko Testnet",
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

export default function AddEthereumChainButton(props: Props): JSX.Element {
  return (
    <button
      onClick={() => addEthereumChain(props.chain)}
      type="button"
      className="inline-flex items-center rounded-md border border-transparent bg-[#fc0fc0] px-4 py-2 text-sm font-semibold text-white shadow-sm hover:bg-[#dc009b] focus:outline-none focus:ring-2 focus:ring-[#ff2ad9] focus:ring-offset-2 hover:cursor-pointer"
    >
      {props.buttonText}
    </button>
  );
}
