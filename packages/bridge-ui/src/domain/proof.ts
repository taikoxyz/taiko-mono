export type StorageEntry = {
  key: string;
  value: string;
  proof: string[]; // Array of rlp-serialized MerkleTree-Nodes, starting with the storageHash-Node,
};

export type EthGetProofResponse = {
  balance: string;
  codeHash: string;
  nonce: string;
  storageHash: string;
  accountProof: string[]; // array of rlp-serialized merkle nodes beginning with stateRoot-node
  storageProof: StorageEntry[];
};

export type GenerateProofOpts = {
  msgHash: string;
  sender: string;
  srcBridgeAddress: string;
  destChain: number;
  destCrossChainSyncAddress: string;
  srcChain: number;
  srcSignalServiceAddress: string;
};

export type GenerateReleaseProofOpts = {
  msgHash: string;
  sender: string;
  destBridgeAddress: string;
  destChain: number;
  destCrossChainSyncAddress: string;
  srcCrossChainSyncAddress: string;
  srcChain: number;
};

export interface Prover {
  generateProof(opts: GenerateProofOpts): Promise<string>;
  generateReleaseProof(opts: GenerateReleaseProofOpts): Promise<string>;
}
