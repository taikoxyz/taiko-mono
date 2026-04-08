import { getPublicClient, readContract } from '@wagmi/core';

import { routingContractsMap } from '$bridgeConfig';
import { config } from '$libs/wagmi';

export enum ProtocolVersion {
  PACAYA = 'pacaya',
  SHASTA = 'shasta',
}

const signalServiceForkRouterAbi = [
  {
    type: 'function',
    name: 'shastaForkTimestamp',
    inputs: [],
    outputs: [{ name: '', type: 'uint64' }],
    stateMutability: 'view',
  },
] as const;

const SHASTA_DEST_CHAIN_IDS = new Set([1, 167_000, 560_048, 167_013]);

async function getChainTimestamp(chainId: number): Promise<bigint> {
  const client = getPublicClient(config, { chainId });
  if (!client) {
    throw new Error(`Could not get public client for chainId ${chainId}`);
  }

  const block = await client.getBlock();
  return block.timestamp;
}

/**
 * Detects protocol version for routes that may still rely on the legacy
 * SignalServiceForkRouter endpoint.
 *
 * Mainnet and Hoodi are already on Shasta, so they resolve directly.
 * Other routes fall back to the legacy router endpoint for backward compatibility.
 */
export async function getProtocolVersion(srcChainId: number, destChainId: number): Promise<ProtocolVersion> {
  const signalService = routingContractsMap[destChainId]?.[srcChainId]?.signalServiceAddress;
  if (!signalService) return ProtocolVersion.PACAYA;
  if (SHASTA_DEST_CHAIN_IDS.has(destChainId)) return ProtocolVersion.SHASTA;

  try {
    const [forkTimestamp, chainTimestamp] = await Promise.all([
      readContract(config, {
        address: signalService,
        abi: signalServiceForkRouterAbi,
        functionName: 'shastaForkTimestamp',
        chainId: destChainId,
      }),
      getChainTimestamp(destChainId),
    ]);

    return chainTimestamp < forkTimestamp ? ProtocolVersion.PACAYA : ProtocolVersion.SHASTA;
  } catch {
    // Route config may be stale, the destination may still be on Pacaya, or this may be a transient RPC error.
    return ProtocolVersion.PACAYA;
  }
}
