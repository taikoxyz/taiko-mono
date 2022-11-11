import { BigNumber } from "ethers"

type StorageEntry = {
    key: string
    value: string
    proof: string[] // Array of rlp-serialized MerkleTree-Nodes, starting with the storageHash-Node,
}

type EthGetProofResponse = {
    balance: string
    codeHash: string
    nonce: string
    storageHash: string
    accountProof: string[] // array of rlp-serialized merkle nodes beginning with stateRoot-node
    storageProof: StorageEntry[]
}

type Block = {
    number: number
    hash: string
    parentHash: string
    nonce: number
    sha3Uncles: string
    logsBloom: string[]
    transactionsRoot: string
    stateRoot: string
    receiptsRoot: string
    miner: string
    difficulty: number
    totalDifficulty: number
    extraData: string
    size: number
    gasLimit: number
    gasUsed: number
    timestamp: number
    transactions: string[]
    uncles: string[]
    baseFeePerGas?: string
    mixHash: string
}

type BlockHeader = {
    parentHash: string
    ommersHash: string
    beneficiary: string
    stateRoot: string
    transactionsRoot: string
    receiptsRoot: string
    logsBloom: string[]
    difficulty: number
    height: number
    gasLimit: number
    gasUsed: number
    timestamp: number
    extraData: string
    mixHash: string
    nonce: number
    baseFeePerGas: BigNumber
}

export { Block, BlockHeader, StorageEntry, EthGetProofResponse }
