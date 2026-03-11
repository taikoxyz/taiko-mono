import { createPublicClient, defineChain, http } from 'viem';

import { appConfig } from '$lib/config';

const fallbackRpcUrl = appConfig.rpcUrl ?? 'https://hoodi-rpc.example.invalid';
const fallbackExplorerUrl = appConfig.explorerUrl ?? 'https://hoodi-explorer.example.invalid';

export const hoodiChain = defineChain({
  id: appConfig.chainId,
  name: appConfig.chainName,
  nativeCurrency: {
    name: 'Ether',
    symbol: 'ETH',
    decimals: 18,
  },
  rpcUrls: {
    default: { http: [fallbackRpcUrl] },
    public: { http: [fallbackRpcUrl] },
  },
  blockExplorers: {
    default: {
      name: 'Hoodi Explorer',
      url: fallbackExplorerUrl,
    },
  },
  testnet: true,
});

export const hoodiPublicClient = createPublicClient({
  chain: hoodiChain,
  transport: http(fallbackRpcUrl),
});
