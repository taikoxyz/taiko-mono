import { getWalletClient } from '@wagmi/core';

export async function getConnectedWallet(chainId?: number) {
  const walletClient = await getWalletClient({ chainId });

  if (!walletClient) {
    throw Error('wallet is not connected');
  }

  return walletClient;
}
