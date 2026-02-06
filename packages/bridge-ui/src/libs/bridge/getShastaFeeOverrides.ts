import { getPublicClient } from '@wagmi/core';

import { isL2Chain } from '$libs/chain';
import { getProtocolVersion, ProtocolVersion } from '$libs/protocol/protocolVersion';
import { getLogger } from '$libs/util/logger';
import { config } from '$libs/wagmi';

const log = getLogger('bridge:getShastaFeeOverrides');

const ELASTICITY_MULTIPLIER = 2n;
const BASE_FEE_MAX_CHANGE_DENOMINATOR = 8n;
const MAX_GAS_TARGET_PERCENT = 95n;
const BLOCK_TIME_TARGET = 2n;

// Shasta fork constants from protocol/docs/Derivation.md
const MIN_BASE_FEE = 5_000_000n; // 0.005 gwei
const MAX_BASE_FEE = 1_000_000_000n; // 1 gwei

const MIN_PRIORITY_FEE = 1_000_000n; // 0.001 gwei
const MAX_FEE_HEADROOM_MULTIPLIER = 2n;

const maxBigInt = (a: bigint, b: bigint) => (a > b ? a : b);
const minBigInt = (a: bigint, b: bigint) => (a < b ? a : b);
const clampBigInt = (v: bigint, min: bigint, max: bigint) => maxBigInt(min, minBigInt(v, max));

type Eip4396BaseFeeArgs = {
  parentBaseFeePerGas: bigint;
  parentGasUsed: bigint;
  parentGasLimit: bigint;
  parentBlockTime: bigint;
};

type ShastaFeeOverrideArgs = {
  txChainId: number;
  srcChainId?: number;
  destChainId?: number;
};

export type ShastaFeeOverrides = {
  maxFeePerGas: bigint;
  maxPriorityFeePerGas: bigint;
};

/**
 * EIP-4396 expected base fee calculation with Shasta clamps.
 */
export function calculateExpectedBaseFeePerGas({
  parentBaseFeePerGas,
  parentGasUsed,
  parentGasLimit,
  parentBlockTime,
}: Eip4396BaseFeeArgs): bigint {
  // safe since if parentGasLimit = 0n, 0n / 2n = 0n; won't error.
  const parentBaseGasTarget = parentGasLimit / ELASTICITY_MULTIPLIER;
  if (parentBaseGasTarget === 0n) {
    return clampBigInt(parentBaseFeePerGas, MIN_BASE_FEE, MAX_BASE_FEE);
  }

  const safeBlockTime = parentBlockTime > 0n ? parentBlockTime : 1n;
  const adjustedTargetByTime = (parentBaseGasTarget * safeBlockTime) / BLOCK_TIME_TARGET;
  const maxGasTarget = (parentGasLimit * MAX_GAS_TARGET_PERCENT) / 100n;
  const parentAdjustedGasTarget = minBigInt(adjustedTargetByTime, maxGasTarget);

  let expectedBaseFeePerGas: bigint;

  if (parentGasUsed === parentAdjustedGasTarget) {
    expectedBaseFeePerGas = parentBaseFeePerGas;
  } else if (parentGasUsed > parentAdjustedGasTarget) {
    const gasUsedDelta = parentGasUsed - parentAdjustedGasTarget;
    const baseFeeDelta = maxBigInt(
      (parentBaseFeePerGas * gasUsedDelta) / parentBaseGasTarget / BASE_FEE_MAX_CHANGE_DENOMINATOR,
      1n,
    );
    expectedBaseFeePerGas = parentBaseFeePerGas + baseFeeDelta;
  } else {
    const gasUsedDelta = parentAdjustedGasTarget - parentGasUsed;
    const baseFeeDelta = (parentBaseFeePerGas * gasUsedDelta) / parentBaseGasTarget / BASE_FEE_MAX_CHANGE_DENOMINATOR;
    expectedBaseFeePerGas = parentBaseFeePerGas > baseFeeDelta ? parentBaseFeePerGas - baseFeeDelta : 0n;
  }

  return clampBigInt(expectedBaseFeePerGas, MIN_BASE_FEE, MAX_BASE_FEE);
}

async function shouldUseShastaFeeOverrides({
  txChainId,
  srcChainId,
  destChainId,
}: ShastaFeeOverrideArgs): Promise<boolean> {
  // EIP-4396 + Shasta fee model is relevant for Shasta L2 execution.
  if (!isL2Chain(txChainId)) return false;

  if (srcChainId == null || destChainId == null) {
    // No route context (e.g., token approval). On Taiko L2 we still prefer Shasta pricing.
    return true;
  }

  try {
    const protocol = await getProtocolVersion(srcChainId, destChainId);
    return protocol === ProtocolVersion.SHASTA;
  } catch (error) {
    log('Could not determine protocol version; skipping fee override', error);
    return false;
  }
}

/**
 * Returns fee overrides for transaction requests so wallet defaults are not
 * relied on for Shasta L2 base fee estimation.
 */
export async function getShastaFeeOverrides(args: ShastaFeeOverrideArgs): Promise<ShastaFeeOverrides | undefined> {
  const { txChainId } = args;
  const shouldUse = await shouldUseShastaFeeOverrides(args);
  if (!shouldUse) return undefined;

  const client = getPublicClient(config, { chainId: txChainId });
  if (!client) return undefined;

  try {
    const latest = await client.getBlock({ blockTag: 'latest' });
    if (latest.baseFeePerGas == null) return undefined;

    let parentBlockTime = 1n;
    try {
      const parent = await client.getBlock({ blockHash: latest.parentHash });
      parentBlockTime = latest.timestamp > parent.timestamp ? latest.timestamp - parent.timestamp : 1n;
    } catch (error) {
      log('Could not fetch parent block, using 1s block-time fallback', error);
    }

    const expectedBaseFee = calculateExpectedBaseFeePerGas({
      parentBaseFeePerGas: latest.baseFeePerGas,
      parentGasUsed: latest.gasUsed,
      parentGasLimit: latest.gasLimit,
      parentBlockTime,
    });

    let maxPriorityFeePerGas = MIN_PRIORITY_FEE;
    try {
      const suggestedPriorityFee = await client.estimateMaxPriorityFeePerGas();
      maxPriorityFeePerGas = maxBigInt(suggestedPriorityFee, MIN_PRIORITY_FEE);
    } catch (error) {
      log('Could not estimate maxPriorityFeePerGas, using floor', error);
    }

    const gasPrice = await client.getGasPrice();
    const maxFeeFromExpectedBase = expectedBaseFee * MAX_FEE_HEADROOM_MULTIPLIER + maxPriorityFeePerGas;
    // Keep maxFeePerGas at least as high as the node's immediate gas price signal to avoid underpricing
    // in short-lived fee spikes while still honoring the EIP-4396-derived baseline.
    const maxFeePerGas = maxBigInt(gasPrice, maxFeeFromExpectedBase);

    return { maxFeePerGas, maxPriorityFeePerGas };
  } catch (error) {
    log('Failed to build Shasta fee overrides', error);
    return undefined;
  }
}
