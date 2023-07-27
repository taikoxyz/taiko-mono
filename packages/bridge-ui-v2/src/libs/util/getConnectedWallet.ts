import { getWalletClient } from '@wagmi/core';

import { NotConnectedError } from '$libs/error';

export async function getConnectedWallet(chainId?: number) {
  const walletClient = await getWalletClient({ chainId });

  if (!walletClient) {
    throw new NotConnectedError('wallet is not connected');
  }

  return walletClient;
}
