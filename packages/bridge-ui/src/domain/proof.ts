type StorageEntry = {
  key: string;
  value: string;
  proof: string[]; // Array of rlp-serialized MerkleTree-Nodes, starting with the storageHash-Node,
};

type EthGetProofResponse = {
  balance: string;
  codeHash: string;
  nonce: string;
  storageHash: string;
  accountProof: string[]; // array of rlp-serialized merkle nodes beginning with stateRoot-node
  storageProof: StorageEntry[];
};

type GenerateProofOpts = {
  msgHash: string;
  sender: string;
  srcBridgeAddress: string;
  destChain: number;
  destHeaderSyncAddress: string;
  srcChain: number;
  srcSignalServiceAddress: string;
};

type GenerateReleaseProofOpts = {
  msgHash: string;
  sender: string;
  destBridgeAddress: string;
  destChain: number;
  destHeaderSyncAddress: string;
  srcHeaderSyncAddress: string;
  srcChain: number;
};

interface Prover {
  GenerateProof(opts: GenerateProofOpts): Promise<string>;
  GenerateReleaseProof(opts: GenerateReleaseProofOpts): Promise<string>;
}

export {
  GenerateProofOpts,
  Prover,
  StorageEntry,
  EthGetProofResponse,
  GenerateReleaseProofOpts,
};
