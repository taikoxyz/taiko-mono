import * as fs from "fs"
import * as log from "./log"
import { Block, BlockHeader, EthGetProofResponse } from "../test/utils/rpc"
import RLP from "rlp"

async function deployContract(
    hre: any,
    contractName: string,
    libraries = {},
    args: any[] = [],
    overrides = {}
) {
    const contractArgs = args || []
    const contractArtifacts = await hre.ethers.getContractFactory(
        contractName,
        {
            libraries: libraries,
        }
    )

    const deployed = await contractArtifacts.deploy(...contractArgs, overrides)
    log.debug(
        `${contractName} deploying, tx ${deployed.deployTransaction.hash}, waiting for confirmations`
    )

    await deployed.deployed()

    log.debug(`${contractName} deployed at ${deployed.address}`)
    return deployed
}

async function getDeployer(hre: any) {
    const accounts = await hre.ethers.provider.listAccounts()
    if (accounts[0] !== undefined) {
        return accounts[0]
    }

    throw new Error(
        `Could not get account, check hardhat.config.ts: networks.${hre.network.name}.accounts`
    )
}

async function waitTx(hre: any, tx: any) {
    return tx.wait(hre.args.confirmations)
}

async function getContract(hre: any, abi: string[], contractAddress: string) {
    const signers = await hre.ethers.getSigners()

    if (!signers || signers.length === 0) {
        throw new Error(
            `Could not get account, check hardhat.config.ts. network: ${hre.network.name}`
        )
    }

    return new hre.ethers.Contract(contractAddress, abi, signers[0])
}

function saveDeployments(_fileName: string, deployments: any) {
    const fileName = `deployments/${_fileName}.json`
    fs.writeFileSync(fileName, JSON.stringify(deployments, undefined, 2))
    log.debug(`deployments saved to ${fileName}`)
}

function getDeployments(_fileName: string) {
    const fileName = `deployments/${_fileName}.json`
    const json = fs.readFileSync(fileName)
    return JSON.parse(`${json}`)
}

async function getSlot(hre: any, signal: any, mappingSlot: any) {
    return hre.ethers.utils.solidityKeccak256(
        ["uint256", "uint256"],
        [signal, mappingSlot]
    )
}

async function decode(hre: any, type: any, data: any) {
    return hre.ethers.utils.defaultAbiCoder.decode([type], data).toString()
}

const MessageStatus = {
    NEW: 0,
    RETRIABLE: 1,
    DONE: 2,
    FAILED: 3,
}

async function getLatestBlockHeader(hre: any) {
    const block: Block = await hre.ethers.provider.send(
        "eth_getBlockByNumber",
        ["latest", false]
    )

    const logsBloom = block.logsBloom.toString().substring(2)

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
    }

    return { block, blockHeader }
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
    )

    // RLP encode the proof together for LibTrieProof to decode
    const encodedProof = hre.ethers.utils.defaultAbiCoder.encode(
        ["bytes", "bytes"],
        [
            RLP.encode(proof.accountProof),
            RLP.encode(proof.storageProof[0].proof),
        ]
    )
    // encode the SignalProof struct from LibBridgeSignal
    const signalProof = hre.ethers.utils.defaultAbiCoder.encode(
        [
            "tuple(tuple(bytes32 parentHash, bytes32 ommersHash, address beneficiary, bytes32 stateRoot, bytes32 transactionsRoot, bytes32 receiptsRoot, bytes32[8] logsBloom, uint256 difficulty, uint128 height, uint64 gasLimit, uint64 gasUsed, uint64 timestamp, bytes extraData, bytes32 mixHash, uint64 nonce, uint256 baseFeePerGas) header, bytes proof)",
        ],
        [{ header: blockHeader, proof: encodedProof }]
    )

    return signalProof
}

export {
    deployContract,
    getDeployer,
    waitTx,
    getContract,
    saveDeployments,
    getDeployments,
    getSlot,
    decode,
    MessageStatus,
    getLatestBlockHeader,
    getSignalProof,
}
