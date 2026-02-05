import { readContract } from '@wagmi/core';

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

const cache = new Map<string, { version: ProtocolVersion; expiry: number }>();
const CACHE_TTL_MS = 5 * 60 * 1000; // 5 minutes

/**
 * Detects protocol version by querying shastaForkTimestamp from SignalServiceForkRouter.
 * This aligns with how the SignalServiceForkRouter makes routing decisions.
 *
 * - If shastaForkTimestamp() reverts (not upgraded yet) → PACAYA
 * - If currentTime < forkTimestamp → PACAYA
 * - If currentTime >= forkTimestamp → SHASTA
 */
export async function getProtocolVersion(srcChainId: number, destChainId: number): Promise<ProtocolVersion> {
  const cacheKey = `${srcChainId}-${destChainId}`;
  const cached = cache.get(cacheKey);
  if (cached && Date.now() < cached.expiry) {
    return cached.version;
  }

  const signalService = routingContractsMap[destChainId]?.[srcChainId]?.signalServiceAddress;
  if (!signalService) return ProtocolVersion.PACAYA;

  try {
    // Query fork timestamp from SignalServiceForkRouter
    const forkTimestamp = await readContract(config, {
      address: signalService,
      abi: signalServiceForkRouterAbi,
      functionName: 'shastaForkTimestamp',
      chainId: destChainId,
    });

    // Compare current time with fork timestamp
    const now = BigInt(Math.floor(Date.now() / 1000));
    const version = now < forkTimestamp ? ProtocolVersion.PACAYA : ProtocolVersion.SHASTA;

    cache.set(cacheKey, { version, expiry: Date.now() + CACHE_TTL_MS });
    return version;
  } catch {
    // SignalService not upgraded to fork router yet = still Pacaya
    cache.set(cacheKey, { version: ProtocolVersion.PACAYA, expiry: Date.now() + CACHE_TTL_MS });
    return ProtocolVersion.PACAYA;
  }
}

export function clearProtocolVersionCache(): void {
  cache.clear();
}
