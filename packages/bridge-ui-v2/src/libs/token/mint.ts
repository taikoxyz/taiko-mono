import { getContract,type WalletClient } from '@wagmi/core';
import { parseTransaction } from 'viem';

import { freeMintErc20ABI } from '$abi';

import { getLogger } from '../util/logger';
import type { Token } from './types';

const log = getLogger('token:mint');

export async function mint(token: Token, walletClient: WalletClient) {
  const tokenSymbol = token.symbol;
  const userAddress = walletClient.account.address;
  const chainId = walletClient.chain.id;

  const l1TokenContract = getContract({
    walletClient,
    abi: freeMintErc20ABI,
    address: token.addresses[chainId],
  });

  log(`Minting ${tokenSymbol} for account "${userAddress}"`);

  try {
    const hash = await l1TokenContract.write.mint([userAddress]);
    return hash;
  } catch (error) {
    console.error(error);

    throw new Error(`found a problem minting ${tokenSymbol}`, {
      cause: error,
    });
  }
}
