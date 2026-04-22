import { getPublicClient } from '@wagmi/core';
import { getContract } from 'viem';

import { freeMintErc20Abi } from '$abi';
import { InsufficientBalanceError, TokenMintedError } from '$libs/error';
import { getConnectedWallet } from '$libs/util/getConnectedWallet';
import { config } from '$libs/wagmi';

import type { Token } from './types';

// Throws an error if:
// 1. User has already minted this token
// 2. User has insufficient balance to mint this token
export async function checkMintable(token: Token, chainId: number) {
  const walletClient = await getConnectedWallet();

  const tokenContract = getContract({
    client: walletClient,
    abi: freeMintErc20Abi,
    address: token.addresses[chainId],
  });

  // Check whether the user has already minted this token
  const userAddress = walletClient.account.address;
  const hasMinted = await tokenContract.read.minters([userAddress]);

  if (hasMinted) {
    throw new TokenMintedError();
  }

  // Check whether the user has enough balance to mint.
  // Compute the cost of the transaction:
  const publicClient = getPublicClient(config);
  if (!publicClient) throw new Error('Could not get public client');

  const estimatedGas = await tokenContract.estimateGas.mint([userAddress]);
  const gasPrice = await publicClient.getGasPrice();
  const estimatedCost = estimatedGas * gasPrice;

  const userBalance = await publicClient.getBalance({ address: userAddress });

  if (estimatedCost > userBalance) {
    throw new InsufficientBalanceError();
  }
}
