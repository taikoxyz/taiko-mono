import { BigNumber, ethers } from "ethers";
import type { Syncing } from "src/domain/syncing";

export const getSyncing = async (
  provider: ethers.providers.JsonRpcProvider
): Promise<Syncing> => {
  const syncing = await provider.send("eth_syncing", []);
  console.log(syncing);
  if (!syncing)
    return {
      synced: true,
    };

  return {
    synced: false,
    currentBlock: BigNumber.from(syncing.currentBlock).toNumber(),
    highestBlock: BigNumber.from(syncing.highestBlock).toNumber(),
  };
};
