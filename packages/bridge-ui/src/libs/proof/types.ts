import type { Address, Hash, Hex } from 'viem';

export type GenerateProofArgs = {
  msgHash: Hash;
  contractAddress: Address;
  signalServiceAddress: Address;
  clientChainId: number;
  blockNumber: bigint;
  action: ProofAction;
  hops: HopParams[];
};

export type GetProofArgs = {
  srcChainId: bigint;
  blockNumber: bigint;
  key: Hex;
  signalServiceAddress: Address;
};

export type StorageEntry = {
  key: string;
  value: Hex;
  // Array of rlp-serialized MerkleTree-Nodes, starting with the storageHash-Node, following the path of the SHA3 (key) as path.
  proof: Hex[];
};

export type Hop = {
  signalRootRelay: Address;
  signalRoot: Hex;
  storageProof: Hex;
};

export const enum ProofAction {
  SEND,
  RELEASE,
  CLAIM,
  RETRY,
}

export const enum CacheOptions {
  CACHE_NOTHING,
  CACHE_SIGNAL_ROOT,
  CACHE_STATE_ROOT,
  CACHE_BOTH,
}

export type HopProof = {
  chainId: bigint;
  blockId: bigint;
  rootHash: Hash;
  cacheOption: bigint;
  accountProof: Hex[];
  storageProof: Hex[];
};

export type HopParams = {
  chainId: bigint;
  signalServiceAddress: Address;
  // signalService: Address;
  key: Hex;
  // blocker: Address;
  // caller: Address;
  blockNumber: bigint;
};

export type EthGetProofResponse = {
  balance: Hex;
  codeHash: Hash;
  nonce: number;
  storageHash: Hash;

  // Array of rlp-serialized MerkleTree-Nodes, starting with the stateRoot-Node, following the path of the SHA3 (address) as key.
  accountProof: Hex[];

  // Array of storage-entries as requested
  storageProof: StorageEntry[];
};

export type ClientWithEthGetProofRequest = {
  request(getProofArgs: {
    method: 'eth_getProof';
    params: [Address, Hex[], number | Hash | 'latest' | 'earliest'];
  }): Promise<EthGetProofResponse>;
};
