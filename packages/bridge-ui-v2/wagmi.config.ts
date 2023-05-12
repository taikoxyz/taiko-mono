import { defineConfig } from '@wagmi/cli'
import type { Abi } from 'abitype'

import ERC20 from '../protocol/abi/@openzeppelin/contracts/token/ERC20/IERC20.sol/IERC20.json'
import Bridge from '../protocol/abi/contracts/bridge/IBridge.sol/IBridge.json'
import TokenVault from '../protocol/abi/contracts/bridge/TokenVault.sol/TokenVault.json'
import ICrossChainSync from '../protocol/abi/contracts/common/ICrossChainSync.sol/ICrossChainSync.json'
import FreeMintERC20 from '../protocol/abi/contracts/test/erc20/FreeMintERC20.sol/FreeMintERC20.json'

export default defineConfig({
  out: 'src/abi/index.ts',
  contracts: [
    {
      name: 'bridge',
      abi: Bridge as Abi,
    },
    {
      name: 'tokenVault',
      abi: TokenVault as Abi,
    },
    {
      name: 'crossChainSync',
      abi: ICrossChainSync as Abi,
    },
    {
      name: 'freeMintErc20',
      abi: FreeMintERC20 as Abi,
    },
    {
      name: 'erc20',
      abi: ERC20 as Abi,
    },
  ],
})
