import { BigNumber, Contract, type Signer } from 'ethers';

import { freeMintErc20ABI } from '../constants/abi';
import { L1_CHAIN_ID } from '../constants/envVars';
import type { Token } from '../domain/token';
import { getLogger } from './logger';

const log = getLogger('util:minting');

/**
 * This function returns a boolean indicating whether the user has already claimed
 * the test token on L1, and the estimated cost of the transaction for minting if not.
 */
export async function getIsMintedWithEstimation(
  signer: Signer,
  token: Token,
): Promise<{ isMinted: boolean; estimatedGas: BigNumber }> {
  const address = signer.getAddress();

  const l1TokenContract = new Contract(
    token.addresses[L1_CHAIN_ID],
    freeMintErc20ABI,
    signer,
  );

  try {
    const userHasAlreadyMinted = await l1TokenContract.minters(address);

    log(`Has user already minted ${token.symbol}? ${userHasAlreadyMinted}`);

    if (userHasAlreadyMinted) {
      return { isMinted: true, estimatedGas: null }; // already minted, no gas cost is needed
    }
  } catch (error) {
    console.error(error);
    throw new Error(`there was an issue getting minters for ${token.symbol}`, {
      cause: error,
    });
  }

  try {
    const gas = await l1TokenContract.estimateGas.mint(address);
    const gasPrice = await signer.getGasPrice();
    const estimatedGas = BigNumber.from(gas).mul(gasPrice);

    log(`Estimated gas to mint token ${token.symbol}: ${estimatedGas}`);

    return { isMinted: false, estimatedGas };
  } catch (error) {
    throw new Error(`failed to estimate gas to mint token ${token.symbol}`, {
      cause: error,
    });
  }
}
