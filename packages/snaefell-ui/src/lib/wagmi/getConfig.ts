import { config, mainnet, publicConfig } from '$wagmi-config';

import type { IChainId } from '../../types';
import { isSupportedChain } from '../chain/chains';
import { web3modal } from '../connect';
export default function getConfig() {
  const { selectedNetworkId } = web3modal.getState();
  const wagmiConfig = selectedNetworkId ? config : publicConfig;

  const chainId = selectedNetworkId ? selectedNetworkId : mainnet.id;

  if (!isSupportedChain(chainId)) {
    return { config: publicConfig, chainId: mainnet.id };
  }

  return {
    config: wagmiConfig,
    chainId: chainId as IChainId,
  };
}
