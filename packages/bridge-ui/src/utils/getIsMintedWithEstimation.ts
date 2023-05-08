import { type Signer, Contract, BigNumber } from 'ethers';
import type { Token } from '../domain/token';
import { FREE_MINT_ERC20_ABI } from '../constants/abi';
import { getLogger } from './logger';

const log = getLogger('utils:minting');

/**
 * This function returns a boolean indicating whether the user has already claimed the token
 * and the estimated cost of the transaction for minting if not.
 */
export async function getIsMintedWithEstimation(
  signer: Signer,
  token: Token,
): Promise<[boolean, BigNumber]> {
  const address = signer.getAddress();

  const l1TokenContract = new Contract(
    token.addresses[0].address, // L1 address
    FREE_MINT_ERC20_ABI,
    signer,
  );

  const userHasAlreadyClaimed = await l1TokenContract.minters(address);

  log(`Has user already claimed ${token.symbol}?`, userHasAlreadyClaimed);

  if (userHasAlreadyClaimed) {
    return [true, null];
  }

  const gas = await l1TokenContract.estimateGas.mint(address);
  const gasPrice = await signer.getGasPrice();
  const estimatedGas = BigNumber.from(gas).mul(gasPrice);

  log(`Estimated gas to mint token ${token.symbol}`, estimatedGas);

  return [false, estimatedGas];
}
