import { MetaMaskInpageProvider } from "@metamask/providers";

declare global {
  interface Window{
    ethereum?:MetaMaskInpageProvider
  }
}

async function ConnectToSepolia() {
  if (!window.ethereum) {
    alert("Metamask not detected! Install Metamask then try again.")
    return;
  }
  if (window.ethereum.networkVersion == "11155111") {
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

type Props = {
  buttonText: string;
};

export default function ConnectToSepoliaButton(props: Props) {
  return (
    <div
      onClick={() => ConnectToSepolia()}
      className="hover:cursor-pointer text-neutral-900 bg-neutral-100 hover:bg-neutral-200 border-solid border-neutral-200 focus:ring-4 focus:outline-none focus:ring-neutral-100 font-medium rounded-lg text-sm px-3 py-2 text-center inline-flex items-center dark:focus:ring-neutral-600 dark:bg-neutral-800 dark:border-neutral-700 dark:text-white dark:hover:bg-neutral-700"
    >
      {props.buttonText}
      Click to Connect to Sepolia
    </div>
  );
}