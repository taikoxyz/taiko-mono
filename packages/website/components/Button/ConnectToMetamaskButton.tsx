import {
  SEPOLIA_CONFIG,
  TAIKO_CONFIG,
  TAIKO_ADD_ETHEREUM_CHAIN,
} from "../../domain/chain";

import { ethereumRequest } from "../../utils/ethereumRequest";

type ConnectButtonProps = {
  network:
    | typeof SEPOLIA_CONFIG.names.shortName
    | typeof TAIKO_CONFIG.names.shortName;
};

const chainMap = {
  Sepolia: SEPOLIA_CONFIG.chainId.hex,
  Jolnir: TAIKO_CONFIG.chainId.hex,
};

async function ConnectToMetamask(network: ConnectButtonProps["network"]) {
  const { ethereum } = window as any;
  if (!ethereum) {
    alert("Metamask not detected! Install Metamask then try again.");
    return;
  }

  if (ethereum.chainId == chainMap[network]) {
    alert(`You are already connected to ${network}.`);
    return;
  }

  let params: any;
  if (network === SEPOLIA_CONFIG.names.shortName) {
    params = [{ chainId: chainMap[network] }];
  } else {
    params = [TAIKO_ADD_ETHEREUM_CHAIN];
  }
  try {
    await ethereumRequest(
      network === SEPOLIA_CONFIG.names.shortName
        ? "wallet_switchEthereumChain"
        : "wallet_addEthereumChain",
      params
    );
  } catch (error) {
    alert(
      "Failed to add the network with wallet_addEthereumChain request. Add the network with https://chainlist.org/ or do it manually. Error log: " +
        error.message
    );
  }
}

export function ConnectToMetamaskButton(props: ConnectButtonProps) {
  return (
    <div
      onClick={() => ConnectToMetamask(props.network)}
      className="hover:cursor-pointer text-neutral-100 bg-[#E81899] hover:bg-[#d1168a] border-solid border-neutral-200 focus:ring-4 focus:outline-none focus:ring-neutral-100 font-medium rounded-lg text-sm px-3 py-2 text-center inline-flex items-center m-1 w-48 justify-center"
    >
      Connect to {props.network}
    </div>
  );
}
