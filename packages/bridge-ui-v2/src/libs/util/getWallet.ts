import { getWalletClient } from '@wagmi/core';

export async function getConnectedWallet() {
  const walletClient = await getWalletClient();

  if (!walletClient) {
    throw Error('wallet is not connected');
  }

  return walletClient;
}
