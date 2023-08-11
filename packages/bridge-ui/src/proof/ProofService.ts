import { Contract, ethers } from 'ethers';
import { RLP } from 'ethers/lib/utils.js';

import { crossChainSyncABI } from '../constants/abi';
import type { Block } from '../domain/block';
import type {
  EthGetProofResponse,
  GenerateProofOpts,
  GenerateReleaseProofOpts,
  Prover,
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

  private static async getBlock(
    contract: ethers.Contract,
    provider: ethers.providers.StaticJsonRpcProvider,
  ): Promise<Block> {
    const latestBlockHash = await contract.getCrossChainBlockHash(0);

    const block: Block = await provider.send('eth_getBlockByHash', [
      latestBlockHash,
      false,
    ]);

    return block;
  }

  private static getSignalProof(
    proof: EthGetProofResponse,
    blockHeight: number,
  ) {
    // RLP encode the proof together for LibTrieProof to decode
    const encodedProof = RLP.encode(proof.storageProof[0].proof);

    // Encode the SignalProof struct:
    // struct SignalProof {
    //   uint256 height;
    //   bytes proof;
    // }
    const signalProof = ethers.utils.defaultAbiCoder.encode(
      ['tuple(uint256 height, bytes proof)'],
      [{ height: blockHeight, proof: encodedProof }],
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

    const block = await ProofService.getBlock(contract, provider);

    // rpc call to get the merkle proof what value is at key on the SignalService contract
    const proof: EthGetProofResponse = await provider.send('eth_getProof', [
      opts.srcSignalServiceAddress,
      [key],
      block.hash,
    ]);

    log('Proof from eth_getProof', proof);
    log('ProofOpts', opts);
    log('Key', key);
    log('Proof value', proof.storageProof[0].value);

    if (proof.storageProof[0].value !== '0x1') {
      throw Error('invalid proof');
    }

    const signalProof = ProofService.getSignalProof(proof, block.number);

    // log('Signal proof', signalProof);

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

    const block = await ProofService.getBlock(contract, provider);

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

    const signalProof = ProofService.getSignalProof(proof, block.number);

    // log('Signal proof', signalProof);

    return signalProof;
  }
}
