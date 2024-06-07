import { createPublicClient, http } from 'viem';
import { holesky, mainnet } from 'viem/chains';

const jsonRpcUrl = import.meta.env.VITE_RPC_URL;

export const publicClient = createPublicClient({
	chain: import.meta.env.VITE_MAINNET === 'true' ? mainnet : holesky,
	transport: http(jsonRpcUrl)
});
