import { getContract, type WalletClient } from '@wagmi/core';

import { freeMintErc20ABI } from '$abi';

import { getLogger } from '../util/logger';
import type { Token } from './types';

const log = getLogger('token:mint');

export async function mint(token: Token, walletClient: WalletClient) {
  const tokenSymbol = token.symbol;
  const userAddress = walletClient.account.address;
  const chainId = walletClient.chain.id;

  const tokenContract = getContract({
    walletClient,
    abi: freeMintErc20ABI,
    address: token.addresses[chainId],
  });

  log(`Minting ${tokenSymbol} for account "${userAddress}"`);

  try {
    const txHash = await tokenContract.write.mint([userAddress]);

    log(`Minting transaction hash for ${tokenSymbol}: ${txHash}`);

    return txHash;
  } catch (error) {
    console.error(error);

    throw new Error(`found a problem minting ${tokenSymbol}`, {
      cause: error,
    });
  }
}
