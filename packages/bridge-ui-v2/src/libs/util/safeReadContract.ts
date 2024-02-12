import { readContract } from '@wagmi/core';
import type { Abi, Address } from 'viem';

import { config } from '$libs/wagmi';

import { getLogger } from './logger';

const log = getLogger('libs:util:safeReadContract');

type ReadContractParams = {
  address: Address;
  abi: Abi;
  functionName: string;
  args?: unknown[];
  chainId: number;
};

/*
 * Safely read a contract, returning null if it fails
 * useful when trying to access a non standard, non mandatory function
 */
export async function safeReadContract(params: ReadContractParams): Promise<unknown | null> {
  try {
    return await readContract(config, params);
  } catch (error) {
    log(`Safely failed to read contract: ${error}`);
    return null;
  }
}
