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

const cache = new Map<string, { version: ProtocolVersion; expiry: number }>();
const CACHE_TTL_MS = 5 * 60 * 1000; // 5 minutes
const MS_PER_SECOND = 1000;

async function getChainTimestamp(chainId: number): Promise<bigint> {
  const client = getPublicClient(config, { chainId });
  if (!client) {
    throw new Error(`Could not get public client for chainId ${chainId}`);
  }

  const block = await client.getBlock();
  return block.timestamp;
}

/**
 * Detects protocol version by querying shastaForkTimestamp from SignalServiceForkRouter.
 * This aligns with how the SignalServiceForkRouter makes routing decisions.
 *
 * - If shastaForkTimestamp() reverts (not upgraded yet) → PACAYA
 * - If chainTime < forkTimestamp → PACAYA
 * - If chainTime >= forkTimestamp → SHASTA
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
    // Query fork timestamp from SignalServiceForkRouter and compare against chain time.
    const [forkTimestamp, chainTimestamp] = await Promise.all([
      readContract(config, {
        address: signalService,
        abi: signalServiceForkRouterAbi,
        functionName: 'shastaForkTimestamp',
        chainId: destChainId,
      }),
      getChainTimestamp(destChainId),
    ]);

    const version = chainTimestamp < forkTimestamp ? ProtocolVersion.PACAYA : ProtocolVersion.SHASTA;

    let expiry = Date.now() + CACHE_TTL_MS;
    if (chainTimestamp < forkTimestamp) {
      const msUntilFork = Number((forkTimestamp - chainTimestamp) * BigInt(MS_PER_SECOND));
      expiry = Date.now() + Math.min(CACHE_TTL_MS, Math.max(msUntilFork, 0));
    }

    cache.set(cacheKey, { version, expiry });
    return version;
  } catch {
    // SignalService not upgraded to fork router yet or temporary RPC error.
    // Avoid caching to prevent locking into the wrong fork on transient failures.
    return ProtocolVersion.PACAYA;
  }
}

export function clearProtocolVersionCache(): void {
  cache.clear();
}
