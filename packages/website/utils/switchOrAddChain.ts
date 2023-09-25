import {
  SEPOLIA_CONFIG,
  TAIKO_CONFIG,
  TAIKO_ADD_ETHEREUM_CHAIN,
} from "../domain/chain";

const chainMap = {
  Sepolia: SEPOLIA_CONFIG.chainId.hex,
  Jolnir: TAIKO_CONFIG.chainId.hex,
};

export async function switchOrAddChain(network: string) {
  const { ethereum } = window as any;
  try {
    await ethereum.request({
      method: "wallet_switchEthereumChain",
      params: [{ chainId: chainMap[network] }],
    });
  } catch (switchError) {
    if (switchError.code !== 4902) {
      throw switchError;
    }
    await ethereum.request({
      method: "wallet_addEthereumChain",
      params: [TAIKO_ADD_ETHEREUM_CHAIN],
    });
  }
}
