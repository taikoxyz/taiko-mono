import type { Ethereum } from "@wagmi/core";
import {switchNetwork} from "@wagmi/core";
import { ethers } from "ethers";
import type { Chain } from "../domain/chain";

export const switchEthereumChain = async (ethereum: Ethereum, chain: Chain) => {
  try {
    await switchNetwork({
      chainId: chain.id,
    });
  } catch (switchError) {
    throw switchError;
  }
};
