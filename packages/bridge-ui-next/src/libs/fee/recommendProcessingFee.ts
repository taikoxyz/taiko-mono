import { getPublicClient } from "@wagmi/core";
import { type Address, formatGwei, parseGwei } from "viem";

import { publicEnv } from "@/config/env";
import { estimateMessageGasLimit } from "$libs/bridge/estimateMessageGasLimit";
import { NoCanonicalInfoFoundError } from "$libs/error";
import { getTokenAddresses } from "$libs/token/getTokenAddresses";
import { type NFT, type Token, TokenType } from "$libs/token/types";
import { getBaseFee } from "$libs/util/getBaseFee";
import { getLogger } from "$libs/util/logger";
import { config } from "$libs/wagmi";

const log = getLogger("libs:recommendedProcessingFee");

type RecommendProcessingFeeArgs = {
  token: Token | NFT;
  destChainId: number;
  srcChainId?: number;
  to?: Address;
  tokenIds?: number[];
  amounts?: number[];
};

export async function recommendProcessingFee({
  token,
  destChainId,
  srcChainId,
  to,
  tokenIds,
  amounts,
}: RecommendProcessingFeeArgs): Promise<bigint> {
  if (!srcChainId) {
    return 0n;
  }

  const baseFee = await getBaseFee(BigInt(destChainId));

  const destPublicClient = getPublicClient(config, { chainId: destChainId });

  if (!destPublicClient) throw new Error("Could not get public client");

  let maxPriorityFee = await destPublicClient.estimateMaxPriorityFeePerGas();
  log(`maxPriorityFee: ${formatGwei(maxPriorityFee)} gwei`);

  if (maxPriorityFee < parseGwei("0.01")) {
    log(
      `maxPriorityFee is less than 0.01 gwei, setting maxPriorityFee to 0.01 gwei`,
    );
    maxPriorityFee = parseGwei("0.01");
  }

  if (!baseFee) throw new Error("Unable to get base fee");
  log(`baseFee: ${formatGwei(baseFee)} gwei`);

  let isTokenAlreadyDeployed = false;

  if (token.type !== TokenType.ETH) {
    const tokenInfo = await getTokenAddresses({
      token,
      srcChainId,
      destChainId,
    });
    if (!tokenInfo) throw new NoCanonicalInfoFoundError();

    if (tokenInfo.bridged) {
      const { address } = tokenInfo.bridged;
      if (address) {
        isTokenAlreadyDeployed = true;
      }
    }

    log(
      `token ${token.symbol} is ${isTokenAlreadyDeployed ? "already" : "not"} deployed on chain ${destChainId}`,
    );
  }

  const messageGasLimit = await estimateMessageGasLimit({
    token,
    srcChainId,
    destChainId,
    isTokenAlreadyDeployed,
    tokenIds,
    amounts,
  });

  const relayerGasLimit = await getRelayerGasLimit({
    token,
    to,
    destChainId,
    messageGasLimit: BigInt(messageGasLimit),
  });

  // Initial fee multiplicator and add fallback
  const feeMultiplier = publicEnv.FEE_MULTIPLIER || "1";

  // if (gasPrice <= parseGwei('0.05')) {
  //   feeMultiplicator = 4;
  //   log(`gasPrice {formatGwei(gasPrice)} is less than 0.5 gwei, setting feeMultiplicator to 4`);
  // } else if (gasPrice <= parseGwei('0.1') && gasPrice > parseGwei('0.05')) {
  //   feeMultiplicator = 3;
  //   log(
  //     `gasPrice ${formatGwei(gasPrice)} is less than 0.1 gwei and more than 0.05 gwei, setting feeMultiplicator to 3`,
  //   );
  // } else {
  //   feeMultiplicator = 2;
  //   log(`gasPrice ${formatGwei(gasPrice)} is more than 0.1 gwei, setting feeMultiplicator to 2`);
  // }

  return calculateProcessingFee({
    relayerGasLimit,
    baseFee,
    maxPriorityFeePerGas: maxPriorityFee,
    feeMultiplier,
  });
}

export function calculateProcessingFee({
  relayerGasLimit,
  baseFee,
  maxPriorityFeePerGas,
  feeMultiplier,
}: {
  relayerGasLimit: bigint;
  baseFee: bigint;
  maxPriorityFeePerGas: bigint;
  feeMultiplier: number | string;
}): bigint {
  const cost = relayerGasLimit * (baseFee * 2n + maxPriorityFeePerGas);
  return applyFeeMultiplier(cost, feeMultiplier);
}

export function applyRelayerGasLimitPadding(
  messageGasLimit: bigint,
  isContractRecipient: boolean,
): bigint {
  const multiplier = isContractRecipient ? 110n : 105n;
  return (messageGasLimit * multiplier + 99n) / 100n;
}

async function getRelayerGasLimit({
  token,
  to,
  destChainId,
  messageGasLimit,
}: {
  token: Token | NFT;
  to?: Address;
  destChainId: number;
  messageGasLimit: bigint;
}): Promise<bigint> {
  if (token.type !== TokenType.ETH || !to) {
    return applyRelayerGasLimitPadding(messageGasLimit, true);
  }

  try {
    const destPublicClient = getPublicClient(config, { chainId: destChainId });
    if (!destPublicClient) throw new Error("Could not get public client");

    const code = await destPublicClient.getBytecode({ address: to });
    return applyRelayerGasLimitPadding(
      messageGasLimit,
      Boolean(code && code !== "0x"),
    );
  } catch (err) {
    log(
      "Unable to detect recipient bytecode, using contract recipient gas padding",
      err,
    );
    return applyRelayerGasLimitPadding(messageGasLimit, true);
  }
}

function applyFeeMultiplier(
  value: bigint,
  feeMultiplier: number | string,
): bigint {
  const { numerator, denominator } = parseFeeMultiplier(feeMultiplier);
  return (value * numerator + denominator - 1n) / denominator;
}

function parseFeeMultiplier(feeMultiplier: number | string): {
  numerator: bigint;
  denominator: bigint;
} {
  const rawMultiplier = String(feeMultiplier).trim();
  if (!/^\d+(\.\d+)?$/.test(rawMultiplier)) {
    return { numerator: 1n, denominator: 1n };
  }

  const [whole, decimal = ""] = rawMultiplier.split(".");
  const denominator = 10n ** BigInt(decimal.length);
  const numerator = BigInt(`${whole}${decimal}`);

  if (numerator < denominator) {
    return { numerator: 1n, denominator: 1n };
  }

  return { numerator, denominator };
}

// function roundWeiTo6DecimalPlaces(wei: bigint): bigint {
//   const roundingFactor = BigInt('1000000000000'); // 10^12

//   // Calculate how many "10^12 wei" units are in the input
//   const units = wei / roundingFactor;

//   // Multiply back to get the rounded wei value
//   const roundedWei = units * roundingFactor;
//   return roundedWei;
// }
