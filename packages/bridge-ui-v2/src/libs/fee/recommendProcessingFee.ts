import { BigNumber,Contract, ethers } from 'ethers'

import { TOKEN_VAULT_ABI } from '../../abi'
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
    let srcChainAddress = token.addresses[srcChain.id]

    if (!srcChainAddress || srcChainAddress === '0x00') {
      srcChainAddress = token.addresses[destChain.id]
    }

    const srcTokenVaultAddress = tokenVaults[srcChain.id]
    const srcTokenVaultContract = new Contract(srcTokenVaultAddress, TOKEN_VAULT_ABI, signer)

    const bridged = await srcTokenVaultContract.canonicalToBridged(destChain.id, srcChainAddress)

    if (bridged == ethers.constants.AddressZero) {
      gasLimit = erc20NotDeployedGasLimit
    } else {
      gasLimit = erc20DeployedGasLimit
    }
  }

  const recommendedFee = BigNumber.from(gasPrice).mul(gasLimit)
  return ethers.utils.formatEther(recommendedFee)
}
