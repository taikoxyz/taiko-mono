import { readContract } from '@wagmi/core';

import { config } from '$wagmi-config';

import { snaefellTokenAbi, snaefellTokenAddress } from '../../generated/abi/';
import { web3modal } from '../../lib/connect';
import type { IChainId } from '../../types';

export async function symbol(): Promise<string> {
  const { selectedNetworkId } = web3modal.getState();
  if (!selectedNetworkId) return '';

  const chainId = selectedNetworkId as IChainId;

  const result = await readContract(config, {
    abi: snaefellTokenAbi,
    address: snaefellTokenAddress[chainId],
    functionName: 'symbol',
    chainId,
  });

  return result as string;
}
