import { getContract, UserRejectedRequestError } from 'viem';

import { freeMintErc20Abi } from '$abi';
import { MintError } from '$libs/error';
import { getConnectedWallet } from '$libs/util/getConnectedWallet';

import { getLogger } from '../util/logger';
import type { Token } from './types';

const log = getLogger('token:mint');

export async function mint(token: Token, chainId: number) {
  const walletClient = await getConnectedWallet(chainId);

  const userAddress = walletClient.account.address;
  const tokenSymbol = token.symbol;

  const tokenContract = getContract({
    client: walletClient,
    abi: freeMintErc20Abi,
    address: token.addresses[chainId],
  });

  try {
    log(`Minting ${tokenSymbol} for account ${userAddress}`);

    const txHash = await tokenContract.write.mint([userAddress]);

    log(`Transaction hash for mint call: "${txHash}"`);

    return txHash;
  } catch (err) {
    console.error(err);

    if (`${err}`.includes('denied transaction signature')) {
      throw new UserRejectedRequestError(err as Error);
    }

    throw new MintError(`failed to mint ${tokenSymbol} tokens`, { cause: err });
  }
}
