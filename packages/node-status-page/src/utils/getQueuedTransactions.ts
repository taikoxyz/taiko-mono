import { BigNumber, ethers } from "ethers";

export const getQueuedTransactions = async (
  provider: ethers.providers.JsonRpcProvider,
  contractAddress: string
): Promise<number> => {
  const mempool = await provider.send("txpool_status", []);
  return BigNumber.from(mempool.queued).toNumber();
};
