// Ported from packages/bridge-ui/src/libs/bridge/checkQuota.ts
// (upstream commit e91ad7f5f).
import { readContract } from "@wagmi/core";
import { type Address, zeroAddress } from "viem";

import { quotaManagerAbi } from "$abi";
import { routingContractsMap } from "$bridgeConfig";
import { TokenType } from "$libs/token/types";
import { config } from "$libs/wagmi";

import type { BridgeTransaction } from "./types";

function getQuotaToken(bridgeTx: BridgeTransaction): Address | null {
  if (bridgeTx.tokenType === TokenType.ETH) return zeroAddress;
  if (bridgeTx.tokenType === TokenType.ERC20)
    return bridgeTx.canonicalTokenAddress ?? null;
  return null;
}

export async function isClaimBlockedByQuota(
  bridgeTx: BridgeTransaction,
): Promise<boolean> {
  const srcChainId = Number(bridgeTx.srcChainId);
  const destChainId = Number(bridgeTx.destChainId);
  const quotaManagerAddress =
    routingContractsMap[destChainId]?.[srcChainId]?.quotaManagerAddress;
  if (!quotaManagerAddress) return false;

  const token = getQuotaToken(bridgeTx);
  if (!token) return false;

  const availableQuota = (await readContract(config, {
    address: quotaManagerAddress,
    abi: quotaManagerAbi,
    functionName: "availableQuota",
    args: [token, 0n],
    chainId: destChainId,
  })) as bigint;

  return bridgeTx.amount > availableQuota;
}
