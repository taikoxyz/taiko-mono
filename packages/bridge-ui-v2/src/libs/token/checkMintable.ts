import { getContract, getPublicClient } from '@wagmi/core';

import { freeMintErc20ABI } from '$abi';
import { InsufficientBalanceError, TokenMintedError } from '$libs/error';
import { getConnectedWallet } from '$libs/util/getConnectedWallet';

import type { Token } from './types';

// Throws an error if:
// 1. User has already minted this token
// 2. User has insufficient balance to mint this token
export async function checkMintable(token: Token, chainId: number) {
  const walletClient = await getConnectedWallet();

  const tokenContract = getContract({
    walletClient,
    abi: freeMintErc20ABI,
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
  const publicClient = getPublicClient();

  const estimatedGas = await tokenContract.estimateGas.mint([userAddress]);
  const gasPrice = await publicClient.getGasPrice();
  const estimatedCost = estimatedGas * gasPrice;

  const userBalance = await publicClient.getBalance({ address: userAddress });

  if (estimatedCost > userBalance) {
    throw new InsufficientBalanceError();
  }
}
