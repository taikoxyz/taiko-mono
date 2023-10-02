import type { Address, Hash, Hex } from 'viem';

export type GenerateProofArgs = {
  msgHash: Hash;
  contractAddress: Address;
  proofForAccountAddress: Address;
  srcChainId: number;
  destChainId: number;
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

export type Block = {
  number: Hex;
  hash: Hex;
  parentHash: Hex;
  nonce: bigint;
  sha3Uncles: Hex;
  logsBloom: Hex[] | Hex;
  transactionsRoot: Hex;
  stateRoot: Hex;
  receiptsRoot: Hex;
  miner: Hex;
  difficulty: bigint;
  totalDifficulty: bigint;
  extraData: Hex;
  size: bigint;
  gasLimit: bigint;
  gasUsed: bigint;
  timestamp: bigint;
  transactions: Hex[];
  uncles: Hex[];
  baseFeePerGas?: number;
  mixHash: Hex;
  withdrawalsRoot?: Hex;
};

export type BlockHeader = {
  parentHash: Hex;
  ommersHash: Hex;
  proposer: Address;
  stateRoot: Hex;
  transactionsRoot: Hex;
  receiptsRoot: Hex;
  logsBloom: Hex[];
  difficulty: bigint;
  height: bigint;
  gasLimit: bigint;
  gasUsed: bigint;
  timestamp: bigint;
  extraData: Hex;
  mixHash: Hex;
  nonce: bigint | null;
  baseFeePerGas: bigint | 0;
  withdrawalsRoot: Hex;
};
