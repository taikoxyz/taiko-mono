import { type Chain, getContract, getPublicClient, getWalletClient } from '@wagmi/core';
import { formatEther } from 'viem';

import { freeMintErc20ABI } from '$abi';
import { PUBLIC_L1_CHAIN_ID } from '$env/static/public';

import { MintableError, type Token } from './types';

// Throws an error if there is any reason for not being mintable
export async function checkMintable(token: Maybe<Token>, network: Maybe<Chain>) {
  if (!token) {
    throw new Error(`token is undefined`, { cause: MintableError.TOKEN_UNDEFINED });
  }

  if (!network) {
    throw new Error(`network is undefined`, { cause: MintableError.NETWORK_UNDEFINED });
  }

  // Are we in the right network L1? we cannot mint in L2
  const chainId = network.id;
  if (chainId.toString() !== PUBLIC_L1_CHAIN_ID) {
    throw new Error(`user is in the wrong chain: ${chainId}`, { cause: MintableError.WRONG_CHAIN });
  }

  const walletClient = await getWalletClient({ chainId });
  if (!walletClient) {
    throw new Error(`user is not connected to ${network.name}`, { cause: MintableError.NOT_CONNECTED });
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
