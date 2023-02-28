import type { Ethereum } from "@wagmi/core";
import { ethers } from "ethers";
import type { Chain } from "../domain/chain";

export const switchEthereumChain = async (ethereum: Ethereum, chain: Chain) => {
  try {
    await ethereum.request({
      method: "wallet_switchEthereumChain",
      params: [{ chainId: ethers.utils.hexValue(chain.id) }],
    });
  } catch (switchError) {
    // This error code indicates that the chain has not been added to MetaMask.
    if (
      switchError.code === 4902 ||
      switchError?.data?.originalError?.code === 4902
    ) {
      try {
        await ethereum.request({
          method: "wallet_addEthereumChain",
          params: [
            {
              chainId: ethers.utils.hexValue(chain.id),
              chainName: chain.name,
              rpcUrls: [chain.rpc],
              nativeCurrency: {
                symbol: "ETH",
                decimals: 18,
                name: "Ethereum",
              },
            },
          ],
        });
      } catch (addError) {
        throw addError;
      }
    } else {
      throw switchError;
    }
  }
};
