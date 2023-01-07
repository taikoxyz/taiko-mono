import type { ethers } from "ethers";

export const getPendingTransactions = async (
  provider: ethers.providers.JsonRpcProvider,
  contractAddress: string
): Promise<number> => {
  const mempool = await provider.send("txpool_content", []);
  let len = 0;
  Object.values(mempool.pending).forEach((p) => {
    len += Object.entries(p).length;
  });
  return len;
};
