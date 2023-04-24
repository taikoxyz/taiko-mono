import { Prover } from '../prover.old'
import { providers } from '../provider'
import { ERC20Bridge } from './ERC20Bridge'

const prover = new Prover(providers)

export const erc20BridgeService = new ERC20Bridge(prover)
