import { Signer, Contract, type Transaction } from 'ethers';
import type { Token } from 'src/domain/token';
import { selectChain } from './selectChain';
import { L1_CHAIN_ID } from '../constants/envVars';
import { chains } from '../chain/chains';
import { freeMintErc20ABI } from '../constants/abi';
import { getLogger } from './logger';

const log = getLogger('util:mintERC20');

export async function mintERC20(
  srcChainId: number,
  token: Token,
  signer: Signer,
): Promise<Transaction> {
  // If we're not already, switch to L1
  if (srcChainId !== token.addresses[0].chainId) {
    await selectChain(chains[L1_CHAIN_ID]);
  }

  const l1TokenContract = new Contract(
    token.addresses[0].address,
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
    throw new Error(`Error minting ${token.symbol}`, { cause: error });
  }
}
