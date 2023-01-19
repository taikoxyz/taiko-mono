import { ethers, Signer } from "ethers";
import RLP from "rlp";
import { ethers as hardhatEthers } from "hardhat";
import { BlockHeader, EthGetProofResponse } from "./rpc";
import { AddressManager, SignalService, LibTrieProof } from "../../typechain";

async function deploySignalService(
    signer: Signer,
    addressManager: AddressManager,
    srcChain: number
): Promise<{ signalService: SignalService }> {
    const libTrieProof: LibTrieProof = await (
        await hardhatEthers.getContractFactory("LibTrieProof")
    )
        .connect(signer)
        .deploy();

    const SignalServiceFactory = await hardhatEthers.getContractFactory(
        "SignalService",
        {
            libraries: {
                LibTrieProof: libTrieProof.address,
            },
        }
    );

    const signalService: SignalService = await SignalServiceFactory.connect(
        signer
    ).deploy();

    await signalService.connect(signer).init(addressManager.address);

    await addressManager.setAddress(
        `${srcChain}.signal_service`,
        signalService.address
    );
    return { signalService };
}

async function getSignalProof(
    provider: ethers.providers.JsonRpcProvider,
    contractAddress: string,
    slot: string,
    blockNumber: number,
    blockHeader: BlockHeader
) {
    const proof: EthGetProofResponse = await provider.send("eth_getProof", [
        contractAddress,
        [slot],
        blockNumber,
    ]);

    // RLP encode the proof together for LibTrieProof to decode
    const encodedProof = ethers.utils.defaultAbiCoder.encode(
        ["bytes", "bytes"],
        [
            RLP.encode(proof.accountProof),
            RLP.encode(proof.storageProof[0].proof),
        ]
    );
    // encode the SignalProof struct from LibBridgeSignal
    const signalProof = ethers.utils.defaultAbiCoder.encode(
        [
            "tuple(tuple(bytes32 parentHash, bytes32 ommersHash, address beneficiary, bytes32 stateRoot, bytes32 transactionsRoot, bytes32 receiptsRoot, bytes32[8] logsBloom, uint256 difficulty, uint128 height, uint64 gasLimit, uint64 gasUsed, uint64 timestamp, bytes extraData, bytes32 mixHash, uint64 nonce, uint256 baseFeePerGas) header, bytes proof)",
        ],
        [{ header: blockHeader, proof: encodedProof }]
    );

    return signalProof;
}

export { deploySignalService, getSignalProof };
