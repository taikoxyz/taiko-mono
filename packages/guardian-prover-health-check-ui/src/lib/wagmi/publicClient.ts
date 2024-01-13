import { createPublicClient, http } from 'viem';

const jsonRpcUrl = import.meta.env.VITE_RPC_URL;

export const publicClient = createPublicClient({
	transport: http(jsonRpcUrl)
});
