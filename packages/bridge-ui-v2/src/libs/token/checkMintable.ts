import { type Chain, getContract, getPublicClient, getWalletClient } from '@wagmi/core';
import { formatEther } from 'viem';

import { freeMintErc20ABI } from '$abi';

import { MintableError, type Token } from './types';

// Throws an error if:
// 1. User is not connected to the network
// 2. User has already minted this token
// 3. User has insufficient balance to mint this token
export async function checkMintable(token: Token, network: Chain) {
  const chainId = network.id;
  const walletClient = await getWalletClient({ chainId });

  if (!walletClient) {
    throw Error(`user is not connected to ${network.name}`, { cause: MintableError.NOT_CONNECTED });
  }

  const tokenContract = getContract({
    walletClient,
    abi: freeMintErc20ABI,
    address: token.addresses[chainId],
  });

  // Check whether the user has already minted this token
  const userAddress = walletClient.account.address;
  const hasMinted = await tokenContract.read.minters([userAddress]);

  if (hasMinted) {
    throw Error(`token ${token.symbol} has already been minted`, { cause: MintableError.TOKEN_MINTED });
  }

  // Check whether the user has enough balance to mint.
  // Compute the cost of the transaction:
  const publicClient = getPublicClient({ chainId });
  const estimatedGas = await tokenContract.estimateGas.mint([userAddress]);
  const gasPrice = await publicClient.getGasPrice();
  const estimatedCost = estimatedGas * gasPrice;

  const userBalance = await publicClient.getBalance({ address: userAddress });

  if (estimatedCost > userBalance) {
    throw Error(`user has insufficient balance to mint ${token.symbol}: ${formatEther(userBalance)}`, {
      cause: MintableError.INSUFFICIENT_BALANCE,
    });
  }
}
