import { signedBlocksRoute } from '$lib/routes';
import type { SignedBlocks } from '$lib/types';
import axios from 'axios';

export async function fetchSignedBlocksFromApi(baseURL: string): Promise<SignedBlocks> {
	const url = `${baseURL}/${signedBlocksRoute}`;

	const resp = await axios.get<SignedBlocks>(url);

	return resp.data;
}
