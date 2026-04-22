import { getPublicClient } from '@wagmi/core';
import type { Address } from 'viem';

import { config } from '$libs/wagmi';

import { getLogger } from './logger';

const log = getLogger('util:isSmartContract');

export const isSmartContract = async (walletAddress: Address, chainId: number) => {
  const publicClient = getPublicClient(config, { chainId });

  if (!publicClient) throw new Error('No public client found');

  const byteCode = await publicClient.getBytecode({ address: walletAddress });

  let isSmartContract = false;
  if (byteCode !== '0x' && byteCode !== undefined) {
    isSmartContract = true;
  }
  log('isSmartContract', isSmartContract, walletAddress, chainId);
  return isSmartContract;
};
