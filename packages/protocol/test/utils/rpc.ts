import { BigNumber, ethers } from "ethers";

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

type Block = {
    number: number;
    hash: string;
    parentHash: string;
    nonce: number;
    sha3Uncles: string;
    logsBloom: string[];
    transactionsRoot: string;
    stateRoot: string;
    receiptsRoot: string;
    miner: string;
    difficulty: number;
    totalDifficulty: number;
    extraData: string;
    size: number;
    gasLimit: number;
    gasUsed: number;
    timestamp: number;
    transactions: string[];
    uncles: string[];
    baseFeePerGas?: string;
    mixHash: string;
};

type BlockHeader = {
    parentHash: string;
    ommersHash: string;
    beneficiary: string;
    stateRoot: string;
    transactionsRoot: string;
    receiptsRoot: string;
    logsBloom: string[];
    difficulty: number;
    height: number;
    gasLimit: number;
    gasUsed: number;
    timestamp: number;
    extraData: string;
    mixHash: string;
    nonce: number;
    baseFeePerGas: number;
};

async function getBlockHeader(
    provider: ethers.providers.JsonRpcProvider,
    blockNumber?: number
) {
    const b = await provider.getBlock(
        blockNumber ? BigNumber.from(blockNumber).toHexString() : "latest"
    );

    const block: Block = await provider.send("eth_getBlockByHash", [
        b.hash,
        false,
    ]);

    const logsBloom = block.logsBloom.toString().substring(2);

    const blockHeader: BlockHeader = {
        parentHash: block.parentHash,
        ommersHash: block.sha3Uncles,
        beneficiary: block.miner,
        stateRoot: block.stateRoot,
        transactionsRoot: block.transactionsRoot,
        receiptsRoot: block.receiptsRoot,
        logsBloom: logsBloom.match(/.{1,64}/g)!.map((s: string) => "0x" + s),
        difficulty: block.difficulty,
        height: block.number,
        gasLimit: block.gasLimit,
        gasUsed: block.gasUsed,
        timestamp: block.timestamp,
        extraData: block.extraData,
        mixHash: block.mixHash,
        nonce: block.nonce,
        baseFeePerGas: block.baseFeePerGas ? parseInt(block.baseFeePerGas) : 0,
    };

    return { block, blockHeader };
}

export {
    Block,
    BlockHeader,
    StorageEntry,
    EthGetProofResponse,
    getBlockHeader,
};
