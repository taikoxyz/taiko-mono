import { getPublicClient } from '@wagmi/core';
import type { Address } from 'viem';

import { config } from '$libs/wagmi';

import { getLogger } from './logger';

const log = getLogger('util:isSmartContractWallet');

export const isSmartContractWallet = async (walletAddress: Address, chainId: number) => {
  const publicClient = getPublicClient(config, { chainId });

  if (!publicClient) throw new Error('No public client found');

  const byteCode = await publicClient.getBytecode({ address: walletAddress });

  let isSmartContract = false;
  if (byteCode !== '0x' && byteCode !== undefined) {
    isSmartContract = true;
  }
  log('isSmartContractWallet', isSmartContract, walletAddress, chainId);
  return isSmartContract;
};
