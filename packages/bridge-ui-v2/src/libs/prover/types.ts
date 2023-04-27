export type StorageEntry = {
  key: string
  value: string
  proof: string[] // Array of rlp-serialized MerkleTree-Nodes, starting with the storageHash-Node,
}

export type EthGetProofResponse = {
  balance: string
  codeHash: string
  nonce: string
  storageHash: string
  accountProof: string[] // array of rlp-serialized merkle nodes beginning with stateRoot-node
  storageProof: StorageEntry[]
}

type GenerateProofCommonArgs = {
  msgHash: string
  sender: string
  srcChainId: string
  destChainId: string
  destXChainSyncAddress: string
}

export type GenerateProofArgs = GenerateProofCommonArgs & {
  srcBridgeAddress: string
  srcSignalServiceAddress: string
}

export type GenerateReleaseProofArgs = GenerateProofCommonArgs & {
  destBridgeAddress: string
  srcXChainSyncAddress: string
}
