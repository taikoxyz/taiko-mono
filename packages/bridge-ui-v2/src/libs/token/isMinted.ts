import { getContract,type WalletClient } from '@wagmi/core';

import { freeMintErc20ABI } from '$abi';

import { getLogger } from '../util/logger';
import type { Token } from './types';

const log = getLogger('token:isMinted');

export async function isMinted(token: Token, walletClient: WalletClient) {
  const tokenSymbol = token.symbol;
  const userAddress = walletClient.account.address;
  const chainId = walletClient.chain.id;

  const l1TokenContract = getContract({
    walletClient,
    abi: freeMintErc20ABI,
    address: token.addresses[chainId],
  });

  try {
    const hasMinted = await l1TokenContract.read.minters([userAddress]);

    log(`Has user already minted ${tokenSymbol}? ${hasMinted}`);

    return hasMinted;
  } catch (error) {
    console.error(error);
    throw new Error(`there was an issue getting minters for ${token.symbol}`, {
      cause: error,
    });
  }
}
