import {
  SEPOLIA_CONFIG,
  GRIMSVOTN_CONFIG,
  ELDFELL_CONFIG,
  GRIMSVOTN_ADD_ETHEREUM_CHAIN,
  ELDFELL_ADD_ETHEREUM_CHAIN,
} from "../../domain/chain";
import { ethereumRequest } from "../../utils/ethereumRequest";

type ConnectButtonProps = {
  network:
    | typeof SEPOLIA_CONFIG.names.shortName
    | typeof ELDFELL_CONFIG.names.shortName
    | typeof GRIMSVOTN_CONFIG.names.shortName;
};

const chainMap = {
  Eldfell: ELDFELL_CONFIG.chainId.hex, // 167005
  Grimsvotn: GRIMSVOTN_CONFIG.chainId.hex, // 167005
  Sepolia: SEPOLIA_CONFIG.chainId.hex, // 11155111
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
    params = [
      network === ELDFELL_CONFIG.names.shortName
        ? ELDFELL_ADD_ETHEREUM_CHAIN
        : GRIMSVOTN_ADD_ETHEREUM_CHAIN,
    ];
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
      className="hover:cursor-pointer text-neutral-100 bg-[#E81899] hover:bg-[#d1168a] border-solid border-neutral-200 focus:ring-4 focus:outline-none focus:ring-neutral-100 font-medium rounded-lg text-sm px-3 py-2 text-center inline-flex items-center"
    >
      Connect to {props.network}
    </div>
  );
}
