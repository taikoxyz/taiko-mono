import type { Address, Hash, Hex } from 'viem';

export type GetProofArgs = {
  chainId: bigint;
  blockNumber: bigint;
  key: Hex;
  signalServiceAddress: Address;
};

export type StorageEntry = {
  key: string;
  value: Hex;
  proof: Hex[];
};

// CacheOption enum - deprecated but still required for struct encoding
export enum CacheOption {
  CACHE_NOTHING = 0,
  CACHE_SIGNAL_ROOT = 1,
  CACHE_STATE_ROOT = 2,
  CACHE_BOTH = 3,
}

export type HopProof = {
  chainId: bigint; // The hop's destination chain ID
  blockId: bigint;
  rootHash: Hash;
  cacheOption: CacheOption; // Deprecated but required for ABI encoding
  accountProof: Hex[];
  storageProof: Hex[];
};

export type EthGetProofResponse = {
  balance: Hex;
  codeHash: Hash;
  nonce: number;
  storageHash: Hash;
  accountProof: Hex[];
  storageProof: StorageEntry[];
};

export type ClientWithEthGetProofRequest = {
  request(getProofArgs: {
    method: 'eth_getProof';
    params: [Address, Hex[], number | Hash | 'latest' | 'earliest'];
  }): Promise<EthGetProofResponse>;
};
