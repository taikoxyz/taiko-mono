import { defineConfig } from '@wagmi/cli';
import type { Abi } from 'abitype';

// CI will fail if we import from the protocol package
// We'll ignore this file on svelte-check: `svelte-check --ignore ./wagmi.config.ts`
import AnchroForkRouter from '../protocol/out/layer2/AnchorForkRouter.sol/AnchorForkRouter.json';
import Bridge from '../protocol/out/shared/Bridge.sol/Bridge.json';
import ERC20 from '../protocol/out/shared/BridgedERC20.sol/BridgedERC20.json';
import ERC721 from '../protocol/out/shared/BridgedERC721.sol/BridgedERC721.json';
import ERC1155 from '../protocol/out/shared/BridgedERC1155.sol/BridgedERC1155.json';
import ERC20Vault from '../protocol/out/shared/ERC20Vault.sol/ERC20Vault.json';
import ERC721Vault from '../protocol/out/shared/ERC721Vault.sol/ERC721Vault.json';
import ERC1155Vault from '../protocol/out/shared/ERC1155Vault.sol/ERC1155Vault.json';
import FreeMintERC20 from '../protocol/out/shared/FreeMintERC20Token.sol/FreeMintERC20Token.json';
import ISignalService from '../protocol/out/shared/ISignalService.sol/ISignalService.json';

export default defineConfig({
  out: 'src/abi/index.ts',
  contracts: [
    {
      name: 'Bridge',
      abi: Bridge.abi as Abi,
    },
    {
      name: 'ERC20Vault',
      abi: ERC20Vault.abi as Abi,
    },
    {
      name: 'ERC721Vault',
      abi: ERC721Vault.abi as Abi,
    },
    {
      name: 'ERC1155Vault',
      abi: ERC1155Vault.abi as Abi,
    },
    {
      name: 'SignalService',
      abi: ISignalService.abi as Abi,
    },
    {
      name: 'FreeMintERC20',
      abi: FreeMintERC20.abi as Abi,
    },
    {
      name: 'Erc20',
      abi: ERC20.abi as Abi,
    },
    {
      name: 'Erc721',
      abi: ERC721.abi as Abi,
    },
    {
      name: 'Erc1155',
      abi: ERC1155.abi as Abi,
    },
    {
      name: 'AnchorForkRouter',
      abi: AnchroForkRouter.abi as Abi,
    },
  ],
});
