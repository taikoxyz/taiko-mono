import { readContract } from '@wagmi/core';
import { type Address, zeroAddress } from 'viem';

import { quotaManagerAbi } from '$abi';
import { isL2Chain } from '$libs/chain';
import { getLogger } from '$libs/util/logger';
import { config } from '$libs/wagmi';

import { type BridgeTransaction, ContractType } from '.';
import { getContractAddressByType } from './getContractAddressByType';

const log = getLogger('bridge:checkBridgeQuota');

export const checkBridgeQuota = async ({
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

    const quota = await readContract(config, {
      address: quotaManagerAddress,
      abi: quotaManagerAbi,
      chainId: Number(transaction.destChainId),
      functionName: 'availableQuota',
      args: [tokenAddress, 0n],
    });

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
