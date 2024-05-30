import { holesky } from 'viem/chains';

import { config, publicConfig } from '$wagmi-config';

import type { IChainId } from '../../types';
import { web3modal } from '../connect';

export default function getConfig() {
  const { selectedNetworkId } = web3modal.getState();
  const wagmiConfig = selectedNetworkId ? config : publicConfig;

  // const chainId = selectedNetworkId ? selectedNetworkId : taiko.id;
  const chainId = selectedNetworkId ? selectedNetworkId : holesky.id;

  return {
    config: wagmiConfig,
    chainId: chainId as IChainId,
  };
}
