import { chainIdToChain } from '$libs/chain';
import { UnsupportedPrivateRpcError } from '$libs/error';
import { getConnectedWallet } from '$libs/util/getConnectedWallet';
import { getLogger } from '$libs/util/logger';

import { getPrivateRpc } from './privateRpc';
import { rememberEnabledPrivateRpc } from './privateRpcPreference';

const log = getLogger('mev:enablePrivateRpc');

/**
 * Asks the connected wallet to point the chain at its private relay, so claims reach block builders
 * without ever entering the public mempool. The wallet broadcasts the transaction, not this app, so
 * this can only prompt: the user is free to reject it and claim over their own endpoint instead.
 *
 * @param chainId The chain the claim will be sent to
 */
export async function enablePrivateRpc(chainId: number): Promise<void> {
  const privateRpc = getPrivateRpc(chainId);

  if (!privateRpc) {
    throw new UnsupportedPrivateRpcError(`no private relay is configured for chain ${chainId}`);
  }

  const chain = chainIdToChain(chainId);
  const wallet = await getConnectedWallet();

  await wallet.addChain({ chain: { ...chain, rpcUrls: { default: { http: [privateRpc.url] } } } });

  rememberEnabledPrivateRpc(chainId);
  log(`${privateRpc.name} enabled for chain ${chainId}`);
}
