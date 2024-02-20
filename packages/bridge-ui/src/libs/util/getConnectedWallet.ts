import { getWalletClient } from '@wagmi/core';

import { NotConnectedError } from '$libs/error';
import { config } from '$libs/wagmi';

export async function getConnectedWallet(chainId?: number) {
  const walletClient = await getWalletClient(config, { chainId });

  if (!walletClient) {
    throw new NotConnectedError('wallet is not connected');
  }

  return walletClient;
}
