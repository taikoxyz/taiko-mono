import type { ethers } from "ethers";

const getConfirmations = async (
  provider: ethers.providers.Provider,
  hash: string
): Promise<number> => {
  try {
    const tx = await provider.getTransaction(hash);
    if (tx) {
      const receipt = await provider.getTransactionReceipt(hash);
      if (!receipt) return receipt.confirmations;
      return tx.confirmations;
    } else {
      return 0;
    }
  } catch (e) {
    return 0;
  }
};

export default getConfirmations;
