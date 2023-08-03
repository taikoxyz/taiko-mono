import { defineConfig } from '@wagmi/cli';
import type { Abi } from 'abitype';

// CI will fail if we import from the protocol package
// We'll ignore this file on svelte-check: `svelte-check --ignore ./wagmi.config.ts`
import Bridge from '../protocol/out/Bridge.sol/Bridge.json';
import TokenVault from '../protocol/out/TokenVault.sol/TokenVault.json';
import ICrossChainSync from '../protocol/out/ICrossChainSync.sol/ICrossChainSync.json';
import FreeMintERC20 from '../protocol/out/FreeMintERC20.sol/FreeMintERC20.json';
import ERC20 from '../protocol/out/ERC20.sol/ERC20.json';

export default defineConfig({
  out: 'src/constants/abi/index.ts',
  contracts: [
    {
      name: 'bridge',
      abi: Bridge.abi as Abi,
    },
    {
      name: 'tokenVault',
      abi: TokenVault.abi as Abi,
    },
    {
      name: 'crossChainSync',
      abi: ICrossChainSync.abi as Abi,
    },
    {
      name: 'freeMintErc20',
      abi: FreeMintERC20.abi as Abi,
    },
    {
      name: 'erc20',
      abi: ERC20.abi as Abi,
    },
  ],
});
