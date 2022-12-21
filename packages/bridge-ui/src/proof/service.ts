import { Contract, ethers } from "ethers";
import { RLP } from "ethers/lib/utils.js";
import HeaderSync from "../constants/abi/HeaderSync";
import type { Block, BlockHeader } from "../domain/block";
import type {
  Prover,
  GenerateProofOpts,
  EthGetProofResponse,
} from "../domain/proof";

class ProofService implements Prover {
  private readonly providerMap: Map<number, ethers.providers.JsonRpcProvider>;

  constructor(providerMap: Map<number, ethers.providers.JsonRpcProvider>) {
    this.providerMap = providerMap;
  }

  async GenerateProof(opts: GenerateProofOpts): Promise<string> {
    const key = ethers.utils.keccak256(
      ethers.utils.solidityPack(
        ["address", "bytes32"],
        [opts.sender, opts.signal]
      )
    );

    const provider = this.providerMap.get(opts.srcChain);

    const contract = new Contract(
      opts.destHeaderSyncAddress,
      HeaderSync,
      this.providerMap.get(opts.destChain)
    );

    const latestSyncedHeader = await contract.getLatestSyncedHeader();

    const block: Block = await provider.send("eth_getBlockByHash", [
      latestSyncedHeader,
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

    // rpc call to get the merkle proof what value is at key on the bridge contract
    const proof: EthGetProofResponse = await provider.send("eth_getProof", [
      opts.srcBridgeAddress,
      [key],
      block.hash,
    ]);

    if (proof.storageProof[0].value !== "0x1") {
      throw Error("invalid proof");
    }

    // RLP encode the proof together for LibTrieProof to decode
    const encodedProof = ethers.utils.defaultAbiCoder.encode(
      ["bytes", "bytes"],
      [RLP.encode(proof.accountProof), RLP.encode(proof.storageProof[0].proof)]
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
}

export { ProofService };
