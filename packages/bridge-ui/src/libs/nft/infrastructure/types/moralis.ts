import type { LimitNumberError } from 'ajv/dist/vocabularies/validation/limitNumber';
import type { Address } from 'viem';

export interface NFTApiData {
  tokenId: string | number;
  contractType: string;
  chain: LimitNumberError;
  tokenUri: string;
  tokenAddress: Address;
  tokenHash: string;
  metadata: string;
  name: string;
  symbol: string;
  ownerOf: Address;
  blockNumberMinted: bigint;
  blockNumber: bigint;
  lastMetadataSync: Date;
  lastTokenUriSync: Date;
  amount: number | string;
  possibleSpam: boolean;
}
