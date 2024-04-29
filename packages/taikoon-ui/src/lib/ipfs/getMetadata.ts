import { IpfsError } from '../error';
import Token from '../token';
import { PUBLIC_IPFS_GATEWAY } from './config';
import get from './get';

export interface ITokenMetadata {
  name: string;
  description: string;
  image: string;
}
export default async function getMetadata(tokenId: number): Promise<ITokenMetadata> {
  const tokenURI = await Token.tokenURI(tokenId);
  const hash = tokenURI.split('ipfs://').pop();
  if (!hash) throw new IpfsError('Invalid token URI:' + tokenURI);
  const metadata = (await get(hash, true)) as ITokenMetadata;

  const imageHash = metadata.image.split('ipfs://').pop();

  if (!imageHash) throw new IpfsError('Invalid image URI:' + metadata.image);

  return {
    ...metadata,
    image: `${PUBLIC_IPFS_GATEWAY}${imageHash}`,
  };
}
