import { taikoChainConfig } from "../constants/taikoChainConfig";

type ConnectButtonProps = {
  network: "Sepolia" | "Taiko";
};

async function ConnectToMetamask(network: ConnectButtonProps["network"]) {
  if (!(window as any).ethereum) {
    alert("Metamask not detected! Install Metamask then try again.");
    return;
  }
  if (
    (window as any).ethereum.networkVersion ==
    (network === "Sepolia" ? 11155111 : 167005)
  ) {
    alert(`You are already connected to ${network}.`);
    return;
  }
  try {
    if (network === "Sepolia") {
      await (window as any).ethereum.request({
        method: "wallet_switchEthereumChain",
        params: [
          {
            chainId: "0xaa36a7",
          },
        ],
      });
    } else {
      await (window as any).ethereum.request({
        method: "wallet_addEthereumChain",
        params: [taikoChainConfig],
      });
    }
  } catch (error) {
    alert(
      "Failed to add the network with wallet_addEthereumChain request. Add the network with https://chainlist.org/ or do it manually. Error log: " +
        error.message
    );
  }
}

export default function ConnectToMetamaskButton(props: ConnectButtonProps) {
  return (
    <div
      onClick={() => ConnectToMetamask(props.network)}
      className="hover:cursor-pointer text-neutral-100 bg-[#E81899] hover:bg-[#d1168a] border-solid border-neutral-200 focus:ring-4 focus:outline-none focus:ring-neutral-100 font-medium rounded-lg text-sm px-3 py-2 text-center inline-flex items-center dark:focus:ring-neutral-600 dark:bg-neutral-800 dark:border-neutral-700 dark:text-white dark:hover:bg-neutral-700"
    >
      Connect to {props.network}
    </div>
  );
}
