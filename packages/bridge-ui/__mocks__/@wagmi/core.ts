import type {
  FetchSignerArgs,
  SwitchNetworkResult,
  SwitchNetworkArgs,
} from '@wagmi/core';
import type { Signer } from 'ethers';

export const fetchSigner = jest.fn<Signer, [FetchSignerArgs]>();

export const switchNetwork = jest.fn<
  Promise<SwitchNetworkResult>,
  [SwitchNetworkArgs]
>();
