import React from "react";

type Props = {
  buttonText: string;
};

async function addEthereumChain() {
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
  const params: AddEthereumChainParameter = {
    chainId: "0x38",
    chainName: "Binance",
    nativeCurrency: {
      name: "BNB",
      symbol: "bnb",
      decimals: 18,
    },
    rpcUrls: ["https://bsc-dataseed.binance.org/"],
    blockExplorerUrls: ["https://bscscan.com/"],
    iconUrls: ["https://bscscan.com/images/brand-assets/bsc-logo.png"],
  };
  const resp = await (window as any).ethereum.request({
    method: "wallet_addEthereumChain",
    params: [params],
  });
  console.log(resp);
}

export default function AddEthereumChainButton(props: Props): JSX.Element {
  return (
    <button
      onClick={addEthereumChain}
      type="button"
      className="inline-flex items-center rounded-md border border-transparent bg-[#fc0fc0] px-4 py-2 text-sm font-semibold text-white shadow-sm hover:bg-[#dc009b] focus:outline-none focus:ring-2 focus:ring-[#ff2ad9] focus:ring-offset-2 hover:cursor-pointer"
    >
      {props.buttonText}
    </button>
  );
}
