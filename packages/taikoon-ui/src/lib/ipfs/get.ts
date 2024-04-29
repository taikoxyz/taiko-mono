import { PUBLIC_IPFS_GATEWAY } from './config';

export default async function get(hash: string, json?: boolean): Promise<any> {
  const response = await fetch(`${PUBLIC_IPFS_GATEWAY}${hash}`);
  return json ? response.json() : response.text();
}
