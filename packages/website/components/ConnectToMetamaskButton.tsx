import { eldfellChainConfig, grimsvotnChainConfig } from "../constants/chains";

type ConnectButtonProps = {
  network: "Eldfell" | "Grimsvotn" | "Sepolia";
};

const chainMap = {
  Eldfell: "0x28c5d", // 167005
  Grimsvotn: "0x28c5d", // 167005
  Sepolia: "0xaa36a7", // 11155111
};

async function ConnectToMetamask(network: ConnectButtonProps["network"]) {
  if (!(window as any).ethereum) {
    alert("Metamask not detected! Install Metamask then try again.");
  }

  if ((window as any).ethereum.chainId == chainMap[network]) {
    alert(`You are already connected to ${network}.`);
  }
  try {
    if (network === "Sepolia") {
      await (window as any).ethereum.request({
        method: "wallet_switchEthereumChain",
        params: [
          {
            chainId: chainMap[network],
          },
        ],
      });
    } else {
      await (window as any).ethereum.request({
        method: "wallet_addEthereumChain",
        params: [
          network === "Eldfell" ? eldfellChainConfig : grimsvotnChainConfig,
        ],
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
      className="hover:cursor-pointer text-neutral-100 bg-[#E81899] hover:bg-[#d1168a] border-solid border-neutral-200 focus:ring-4 focus:outline-none focus:ring-neutral-100 font-medium rounded-lg text-sm px-3 py-2 text-center inline-flex items-center"
    >
      Connect to {props.network}
    </div>
  );
}
