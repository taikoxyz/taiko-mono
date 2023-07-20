import { getContract } from '@wagmi/core';

import { freeMintErc20ABI } from '$abi';
import { getConnectedWallet } from '$libs/util/getConnectedWallet';

import { getLogger } from '../util/logger';
import type { Token } from './types';

const log = getLogger('token:mint');

export async function mint(token: Token, chainId: number) {
  const walletClient = await getConnectedWallet(chainId);

  const userAddress = walletClient.account.address;
  const tokenSymbol = token.symbol;

  const tokenContract = getContract({
    walletClient,
    abi: freeMintErc20ABI,
    address: token.addresses[chainId],
  });

  log(`Minting ${tokenSymbol} for account ${userAddress}`);

  const txHash = await tokenContract.write.mint([userAddress]);

  log(`Transaction hash for minting ${tokenSymbol}: ${txHash}`);

  return txHash;
}
