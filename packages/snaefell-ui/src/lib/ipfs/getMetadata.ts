import Token from '../token';
import get from './get';

export interface ITokenMetadata {
  name: string;
  description: string;
  image: string;
}
export default async function getMetadata(tokenId: number): Promise<ITokenMetadata> {
  const tokenURI = await Token.tokenURI(tokenId);
  const metadata = (await get(tokenURI, true)) as ITokenMetadata;
  return metadata;
}
