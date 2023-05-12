import { BigNumber, Contract, ethers } from 'ethers'

import { tokenVaultABI } from '../../abi'
import { providers } from '../provider'
import { isEther } from '../token'
import { tokenVaults } from '../vault'
import { erc20DeployedGasLimit, erc20NotDeployedGasLimit, ethGasLimit } from './gasLimits'
import type { RecommendProcessingFeeArgs } from './types'

export async function recommendProcessingFee({
  srcChain,
  destChain,
  feeType,
  token,
  signer,
}: RecommendProcessingFeeArgs): Promise<string> {
  if (!srcChain || !destChain || !token || !signer || !feeType) return '0'

  const destProvider = providers[destChain.id]

  // Returns a best guess of the Gas Price to use in a transaction.
  // See https://docs.ethers.org/v5/api/providers/provider/#Provider-getGasPrice
  const gasPrice = await destProvider.getGasPrice()

  let gasLimit = ethGasLimit

  if (!isEther(token)) {
    let chainAddress = token.addresses[srcChain.id]

    // If the token isn't deployed on the source chain
    // then we use the address on the destination chain
    if (!chainAddress || chainAddress === ethers.constants.AddressZero) {
      chainAddress = token.addresses[destChain.id]
    }

    const srcTokenVaultAddress = tokenVaults[srcChain.id]
    const srcTokenVaultContract = new Contract(srcTokenVaultAddress, tokenVaultABI, signer)

    const bridged = await srcTokenVaultContract.canonicalToBridged(destChain.id, chainAddress)

    if (bridged === ethers.constants.AddressZero) {
      gasLimit = erc20NotDeployedGasLimit
    } else {
      gasLimit = erc20DeployedGasLimit
    }
  }

  const recommendedFee = BigNumber.from(gasPrice).mul(gasLimit)

  return ethers.utils.formatEther(recommendedFee)
}
