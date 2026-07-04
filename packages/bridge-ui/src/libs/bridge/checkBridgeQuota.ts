import { readContract } from '@wagmi/core';
import { type Address, zeroAddress } from 'viem';

import { quotaManagerAbi } from '$abi';
import { isL2Chain } from '$libs/chain';
import { getLogger } from '$libs/util/logger';
import { config } from '$libs/wagmi';

import { type BridgeTransaction, ContractType } from '.';
import { getContractAddressByType } from './getContractAddressByType';

const log = getLogger('bridge:checkBridgeQuota');

/**
 * Checks if the specified amount exceeds the quota for a given token address and chain ID.
 * If the token address is not provided, the zero address (ETH) is used.
 *
 * @param {Object} params - The parameters for checking the quota.
 * @param {Address} params.tokenAddress - The token address (optional).
 * @param {bigint} params.amount - The amount to check.
 * @param {Address} params.quotaManagerAddress - The quota manager address.
 * @param {number} params.chainId - The chain ID of the quota manager.
 * @returns {Promise<boolean>} - A promise that resolves to `true` if the amount exceeds the quota, `false` otherwise.
 */
export const exceedsQuota = async ({
  tokenAddress,
  amount,
  quotaManagerAddress,
  chainId,
}: {
  tokenAddress?: Address;
  amount: bigint;
  quotaManagerAddress: Address;
  chainId: number;
}) => {
  try {
    const address = tokenAddress || zeroAddress; // if tokenAddress is not provided, use zero address (=ETH)

    const quota = await getQuotaForAddress(quotaManagerAddress, address, chainId);
    log('Quota:', quota, 'Amount:', amount, 'Has enough quota:', amount <= quota);
    if (amount > quota) {
      log('Not enough quota', quota, amount);
      return true;
    }
    return false;
  } catch (e) {
    log('Error getting quota manager address', e);
    return false;
  }
};

/**
 * Checks if there is enough bridge quota for a claim transaction.
 * @param {Object} options - The options for checking bridge quota.
 * @param {BridgeTransaction} options.transaction - The bridge transaction.
 * @param {bigint} options.amount - The amount of tokens to be claimed.
 * @returns {Promise<boolean>} - A promise that resolves to `true` if there is enough quota, or `false` otherwise.
 */
export const checkEnoughBridgeQuotaForClaim = async ({
  transaction,
  amount,
}: {
  transaction: BridgeTransaction;
  tokenAddress?: Address;
  amount: bigint;
}) => {
  log(
    'Checking bridge quota',
    transaction.canonicalTokenAddress,
    amount,
    isL2Chain(Number(transaction.destChainId)),
    transaction.destChainId,
    transaction.srcChainId,
  );

  const tokenAddress =
    transaction.canonicalTokenAddress && (transaction.canonicalTokenAddress as string) !== ''
      ? transaction.canonicalTokenAddress
      : zeroAddress;

  if (isL2Chain(Number(transaction.destChainId))) {
    // Quota only applies for transactions from L2-L1.
    // So if the destination chain is an L2 chain, we can skip this check.
    log('Skipping quota check for L2 chain');
    return true;
  }
  try {
    const quotaManagerAddress = getContractAddressByType({
      srcChainId: Number(transaction.destChainId),
      destChainId: Number(transaction.srcChainId),
      contractType: ContractType.QUOTAMANAGER,
    });

    const quota = await getQuotaForAddress(quotaManagerAddress, tokenAddress, Number(transaction.destChainId));

    if (amount > quota) {
      log('Not enough quota', quota, amount);
      return false;
    }
    log('Quota:', quota, 'Amount:', amount, 'Has enough quota:', amount <= quota);
    return true;
  } catch (e) {
    // If there is an error checking the quota, there is probably no quota configured
    log('Error checking quota', e);
    return true;
  }
};

const getQuotaForAddress = async (quotaManagerAddress: Address, address: Address, chainId: number) => {
  const quota = await readContract(config, {
    address: quotaManagerAddress,
    abi: quotaManagerAbi,
    chainId: chainId,
    functionName: 'availableQuota',
    args: [address, 0n],
  });
  return quota;
};
