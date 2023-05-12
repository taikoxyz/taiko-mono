import type { Signer } from 'ethers'

import type { Chain } from '../chain/types'
import type { Token } from '../token/types'

export enum ProcessingFeeMethod {
  RECOMMENDED = 'recommended',
  CUSTOM = 'custom',
  NONE = 'none',
}

export type RecommendProcessingFeeArgs = {
  srcChain: Chain
  destChain: Chain
  feeType: ProcessingFeeMethod
  token: Token
  signer: Signer
}
