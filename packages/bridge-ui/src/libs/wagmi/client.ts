import { injected, walletConnect } from '@wagmi/connectors';
import { createConfig, getPublicClient, http, reconnect } from '@wagmi/core';

import { PUBLIC_WALLETCONNECT_PROJECT_ID } from '$env/static/public';
import { chains } from '$libs/chain';

const projectId = PUBLIC_WALLETCONNECT_PROJECT_ID;

export const publicClient = async (chainId: number) => {
  return await getPublicClient(config, { chainId });
};

const transports = chains.reduce((acc, { id }) => ({ ...acc, [id]: http() }), {});

export const config = createConfig({
  //@ts-ignore
  chains: [...chains],
  connectors: [walletConnect({ projectId, showQrModal: false }), injected()],
  transports,
});

reconnect(config);
