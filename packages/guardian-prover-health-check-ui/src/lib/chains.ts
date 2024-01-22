import { defineChain } from 'viem';

export const internalChain = defineChain({
	id: 31336,
	name: 'Internal L1',
	network: 'taiko internal testnet',
	nativeCurrency: {
		decimals: 18,
		name: 'Ether',
		symbol: 'ETH'
	},
	rpcUrls: {
		default: {
			http: ['https://l1rpc.internal.taiko.xyz']
		},
		public: {
			http: ['https://l1rpc.internal.taiko.xyz']
		}
	},
	blockExplorers: {
		default: { name: 'Explorer', url: 'https://l1explorer.internal.taiko.xyz/' }
	}
});
