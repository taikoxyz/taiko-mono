import type { Address, Hash, Hex } from 'viem';

export type GenerateProofArgs = {
  msgHash: Hash;
  contractAddress: Address;
  proofForAccountAddress: Address;
  crossChainSyncChainId: number;
  clientChainId: number;
};

export type StorageEntry = {
  key: string;
  value: Hex;

  // Array of rlp-serialized MerkleTree-Nodes, starting with the storageHash-Node, following the path of the SHA3 (key) as path.
  proof: Hex[];
};

export type EthGetProofResponse = {
  balance: bigint;
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
