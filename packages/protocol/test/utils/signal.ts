import RLP from "rlp";
import { BlockHeader, EthGetProofResponse } from "./rpc";

function getSignalSlot(hre: any, sender: string, signal: string) {
    return hre.ethers.utils.keccak256(
        hre.ethers.utils.solidityPack(
            ["string", "address", "bytes32"],
            ["SIGNAL", sender, signal]
        )
    );
}

async function getSignalProof(
    hre: any,
    contractAddress: string,
    key: string,
    blockNumber: number,
    blockHeader: BlockHeader
) {
    const proof: EthGetProofResponse = await hre.ethers.provider.send(
        "eth_getProof",
        [contractAddress, [key], blockNumber]
    );

    // RLP encode the proof together for LibTrieProof to decode
    const encodedProof = hre.ethers.utils.defaultAbiCoder.encode(
        ["bytes", "bytes"],
        [
            RLP.encode(proof.accountProof),
            RLP.encode(proof.storageProof[0].proof),
        ]
    );
    // encode the SignalProof struct from LibBridgeSignal
    const signalProof = hre.ethers.utils.defaultAbiCoder.encode(
        [
            "tuple(tuple(bytes32 parentHash, bytes32 ommersHash, address beneficiary, bytes32 stateRoot, bytes32 transactionsRoot, bytes32 receiptsRoot, bytes32[8] logsBloom, uint256 difficulty, uint128 height, uint64 gasLimit, uint64 gasUsed, uint64 timestamp, bytes extraData, bytes32 mixHash, uint64 nonce, uint256 baseFeePerGas) header, bytes proof)",
        ],
        [{ header: blockHeader, proof: encodedProof }]
    );

    return signalProof;
}

export { getSignalSlot, getSignalProof };
