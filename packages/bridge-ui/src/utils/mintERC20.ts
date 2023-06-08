import { switchNetwork } from '@wagmi/core';
import { Contract, Signer, type Transaction } from 'ethers';
import type { Token } from 'src/domain/token';

import { freeMintErc20ABI } from '../constants/abi';
import { L1_CHAIN_ID } from '../constants/envVars';
import { getLogger } from './logger';

const log = getLogger('util:mintERC20');

export async function mintERC20(
  srcChainId: number,
  token: Token,
  signer: Signer,
): Promise<Transaction> {
  // If we're not already, switch to L1
  if (srcChainId !== L1_CHAIN_ID) {
    await switchNetwork({ chainId: L1_CHAIN_ID });
  }

  const l1TokenContract = new Contract(
    token.addresses[L1_CHAIN_ID],
    freeMintErc20ABI,
    signer,
  );

  try {
    const address = await signer.getAddress();

    log(`Minting ${token.symbol} for account "${address}"`);

    const tx = await l1TokenContract.mint(address);

    log(`Minting transaction for ${token.symbol}`, tx);

    return tx;
  } catch (error) {
    console.error(error);
    throw new Error(`found a problem minting ${token.symbol}`, {
      cause: error,
    });
  }
}
