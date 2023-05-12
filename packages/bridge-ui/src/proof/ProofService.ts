import { Contract, ethers } from 'ethers';
import { RLP } from 'ethers/lib/utils.js';
import { crossChainSyncABI } from '../constants/abi';
import type { Block, BlockHeader } from '../domain/block';
import type {
  Prover,
  GenerateProofOpts,
  EthGetProofResponse,
  GenerateReleaseProofOpts,
} from '../domain/proof';
import { getLogger } from '../utils/logger';

const log = getLogger('ProofService');

export class ProofService implements Prover {
  private readonly providers: Record<
    number,
    ethers.providers.StaticJsonRpcProvider
  >;

  constructor(
    providers: Record<number, ethers.providers.StaticJsonRpcProvider>,
  ) {
    this.providers = providers;
  }

  private static getKey(opts: GenerateProofOpts | GenerateReleaseProofOpts) {
    const key = ethers.utils.keccak256(
      ethers.utils.solidityPack(
        ['address', 'bytes32'],
        [opts.sender, opts.msgHash],
      ),
    );

    return key;
  }

  private static async getBlockAndBlockHeader(
    contract: ethers.Contract,
    provider: ethers.providers.StaticJsonRpcProvider,
  ): Promise<{ block: Block; blockHeader: BlockHeader }> {
    const latestSyncedHeader = await contract.getCrossChainBlockHash(0);

    const block: Block = await provider.send('eth_getBlockByHash', [
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
      logsBloom: logsBloom.match(/.{1,64}/g)!.map((s: string) => '0x' + s),
      difficulty: block.difficulty,
      height: block.number,
      gasLimit: block.gasLimit,
      gasUsed: block.gasUsed,
      timestamp: block.timestamp,
      extraData: block.extraData,
      mixHash: block.mixHash,
      nonce: block.nonce,
      baseFeePerGas: block.baseFeePerGas ? parseInt(block.baseFeePerGas) : 0,
      withdrawalsRoot: block.withdrawalsRoot ?? ethers.constants.HashZero,
    };

    return { block, blockHeader };
  }

  private static getSignalProof(
    proof: EthGetProofResponse,
    blockHeader: BlockHeader,
  ) {
    // RLP encode the proof together for LibTrieProof to decode
    const encodedProof = RLP.encode(proof.storageProof[0].proof);

    // encode the SignalProof struct from LibBridgeSignal
    const signalProof = ethers.utils.defaultAbiCoder.encode(
      ['tuple(uint256 height, bytes proof)'],
      [{ height: blockHeader.height, proof: encodedProof }],
    );

    return signalProof;
  }

  async generateProof(opts: GenerateProofOpts): Promise<string> {
    const key = ProofService.getKey(opts);

    const provider = this.providers[opts.srcChain];

    const contract = new Contract(
      opts.destCrossChainSyncAddress,
      crossChainSyncABI,
      this.providers[opts.destChain],
    );

    const { block, blockHeader } = await ProofService.getBlockAndBlockHeader(
      contract,
      provider,
    );

    // rpc call to get the merkle proof what value is at key on the SignalService contract
    const proof: EthGetProofResponse = await provider.send('eth_getProof', [
      opts.srcSignalServiceAddress,
      [key],
      block.hash,
    ]);

    log('Proof from eth_getProof', proof);

    if (proof.storageProof[0].value !== '0x1') {
      throw Error('invalid proof');
    }

    const signalProof = ProofService.getSignalProof(proof, blockHeader);

    return signalProof;
  }

  async generateReleaseProof(opts: GenerateReleaseProofOpts): Promise<string> {
    const key = ProofService.getKey(opts);

    const provider = this.providers[opts.destChain];

    const contract = new Contract(
      opts.srcCrossChainSyncAddress,
      crossChainSyncABI,
      this.providers[opts.srcChain],
    );

    const { block, blockHeader } = await ProofService.getBlockAndBlockHeader(
      contract,
      provider,
    );

    // rpc call to get the merkle proof what value is at key on the SignalService contract
    const proof: EthGetProofResponse = await provider.send('eth_getProof', [
      opts.destBridgeAddress,
      [key],
      block.hash,
    ]);

    log('Proof from eth_getProof', proof);

    if (proof.storageProof[0].value !== '0x3') {
      throw Error('invalid proof');
    }

    const signalProof = ProofService.getSignalProof(proof, blockHeader);

    return signalProof;
  }
}
