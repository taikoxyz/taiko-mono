import { chains } from '../chain'
import { Prover } from '../prover.old'
import { providers } from '../provider'
import { ETHBridge } from './ETHBridge'

const prover = new Prover(providers)

export const ethBridgeService = new ETHBridge(prover, chains)
