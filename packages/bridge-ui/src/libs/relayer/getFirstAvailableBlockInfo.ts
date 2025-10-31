import { relayerApiServices } from './initRelayers';
import type { RelayerBlockInfo } from './types';

export async function getFirstAvailableBlockInfo(srcChainId: number): Promise<RelayerBlockInfo | undefined> {
  const relayerTxPromises = relayerApiServices.map((relayerApiService) => relayerApiService.getBlockInfo());

  try {
    const firstResolvedBlockInfo: RelayerBlockInfo = await Promise.race(relayerTxPromises);
    return firstResolvedBlockInfo;
  } catch (error) {
    console.error(error);
    throw new Error('Failed to fetch block info from any relayer', { cause: error });
  }
}
