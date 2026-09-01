import { getPublicClient, readContract, simulateContract, writeContract } from '@wagmi/core';
import { get } from 'svelte/store';
import {
  type Abi,
  type Address,
  getAddress,
  getContract,
  type Hash,
  UserRejectedRequestError,
  type WalletClient,
} from 'viem';

import { bridgeAbi } from '$abi';
import { routingContractsMap } from '$bridgeConfig';
import { destOwnerAddress, gasLimitZero } from '$components/Bridge/state';
import {
  BridgePausedError,
  MessageStatusError,
  ProcessMessageError,
  ReleaseError,
  WrongChainError,
  WrongOwnerError,
} from '$libs/error';
import type { BridgeProver } from '$libs/proof';
import { isBridgePaused } from '$libs/util/checkForPausedContracts';
import { getConnectedWallet } from '$libs/util/getConnectedWallet';
import { isSmartContract } from '$libs/util/isSmartContract';
import { getLogger } from '$libs/util/logger';
import { config } from '$libs/wagmi';

import { estimateMessageGasLimitWithMinimum, type MessageGasEstimateExtras } from './estimateMessageGasLimit';
import { feeForGasLimit } from './messageFeeInvariant';
import {
  type BridgeArgs,
  type BridgeTransaction,
  type ClaimArgs,
  MessageStatus,
  type ProcessMessageType,
  type ReleaseArgs,
  type RetryMessageArgs,
} from './types';

const log = getLogger('bridge:Bridge');

export abstract class Bridge {
  protected readonly _prover: BridgeProver;

  constructor(prover: BridgeProver) {
    this._prover = prover;
  }

  /**
   * @dev The preamble every token type runs before it can build its message.
   *
   *      ETH, ERC20, ERC721 and ERC1155 differ in the vault they call and the operation
   *      they hand it, but they reach that point the same way: the same wallet guard, the
   *      same pause check, the same contract handle, the same gas-limit choice, the same
   *      destination-owner default and the same fee rule. Each carried its own copy, and
   *      every fix to one of them - the pause check, the zero-gas-limit fee, the invariant
   *      assertions - had to be made four times, which is how three of them ended up
   *      applied to only some.
   *
   * @param args The bridge arguments common to every token type
   * @param abi The vault or bridge ABI the transaction is built against
   * @param address The contract to send to
   * @param gasEstimate What the destination gas estimate needs beyond the token itself
   * @return prepared_ The contract handle, the sender, and the fields shared by every
   *                   message, including the set the invariant checks take verbatim
   */
  protected async prepareSend<const TAbi extends Abi>({
    args,
    abi,
    address,
    gasEstimate,
  }: {
    args: BridgeArgs;
    abi: TAbi;
    address: Address;
    gasEstimate?: MessageGasEstimateExtras;
  }) {
    const { to, wallet, srcChainId, destChainId, fee: processingFee, tokenObject } = args;

    // Checked before the contract is built: getContract with an undefined client throws
    // its own opaque error, which is what this guard exists to replace
    if (!wallet || !wallet.account) throw new Error('Wallet is not connected');

    await this.assertNotPaused(srcChainId);

    const contract = getContract({ client: wallet, abi, address });

    let gasLimit: number;
    /** Left undefined for a zero gas limit, where no estimate ran and the rule is moot */
    let minGasLimit: number | undefined;
    if (get(gasLimitZero)) {
      log('Gas limit is set to 0');
      gasLimit = 0;
    } else {
      const estimate = await estimateMessageGasLimitWithMinimum({
        token: tokenObject,
        srcChainId,
        destChainId,
        ...gasEstimate,
      });
      gasLimit = Number(estimate.gasLimit);
      minGasLimit = estimate.minGasLimit;
    }
    log('Calculated gasLimit for message', gasLimit);

    // A zero gas limit cannot carry a fee - the bridge reverts with B_INVALID_FEE
    const fee = feeForGasLimit(gasLimit, processingFee);
    const destOwner = get(destOwnerAddress) || to;

    return {
      contract,
      owner: wallet.account.address,
      to,
      destOwner,
      gasLimit,
      fee,
      /** Exactly what every check in messageInvariants takes, so callers add only their own */
      commonFields: { to, destOwner, srcChainId, destChainId, gasLimit, fee, minGasLimit },
    };
  }

  /**
   * @dev Refuses to build a transaction the source bridge would reject anyway.
   *
   *      Every token type goes through its own `_prepareTransaction`, so this is the one
   *      place all four send paths share. Guarding the individual `estimateGas`/`bridge`
   *      methods instead left ERC1155 unguarded entirely and ERC721 guarded only while
   *      estimating.
   *
   * @param srcChainId The chain the message would be sent from
   */
  protected async assertNotPaused(srcChainId: number) {
    if (await isBridgePaused(srcChainId)) throw new BridgePausedError('Bridge is paused');
  }

  /**
   * We are gonna run some common checks here:
   * 1. Check that the message is owned by the user
   * 2. Check that the message has not been claimed already
   */
  protected async beforeProcessing({ bridgeTx, wallet }: ClaimArgs, skipMessageStatusCheck = false) {
    const { msgHash, message } = bridgeTx;
    if (!message || !msgHash) throw new Error('Message is not defined');

    const srcChainId = Number(message.srcChainId);
    const destChainId = Number(message.destChainId);

    const { srcOwner, destOwner } = message;
    if (!wallet || !wallet.account || !wallet.chain) throw new Error('Wallet is not connected');

    const userAddress = wallet.account.address;
    // Are we the owner of the message, either src or dest?
    if (getAddress(srcOwner) !== getAddress(userAddress) && getAddress(destOwner) !== getAddress(userAddress)) {
      if (bridgeTx.message?.gasLimit === 0) {
        throw new WrongOwnerError('user cannot process this as it is not their message');
      }
    }

    const destBridgeAddress = routingContractsMap[destChainId][srcChainId].bridgeAddress;

    if (skipMessageStatusCheck) {
      return { destBridgeAddress };
    }

    const messageStatus = await readContract(config, {
      address: destBridgeAddress,
      abi: bridgeAbi,
      functionName: 'messageStatus',
      args: [msgHash],
      chainId: destChainId,
    });

    log(`Claiming message with status ${messageStatus}`);

    // Has it been claimed already?
    if (messageStatus === MessageStatus.DONE) {
      throw new MessageStatusError('message already processed');
    }
    return { messageStatus, destBridgeAddress };
  }

  protected async beforeDirectClaiming({ bridgeTx, wallet }: ClaimArgs) {
    const { message, msgHash } = bridgeTx;
    if (!message || !msgHash) throw new Error('Message is not defined');

    const connectedChainId = await wallet.getChainId();
    const destChainId = Number(message.destChainId);

    if (connectedChainId !== destChainId) {
      throw new WrongChainError('wallet must be connected to the destination chain');
    }
  }

  /**
   * 1. Check that the wallet is connected to the destination chain
   * 2. Check that the message is owned by the user
   * 3. Check that the message has not been claimed already
   * 4. Check that the message has not failed
   *
   * Important: wallet must be connected to the destination chain
   */
  protected async beforeClaiming({
    bridgeTx,
    wallet,
    messageStatus,
  }: {
    bridgeTx: BridgeTransaction;
    wallet: WalletClient;
    messageStatus: MessageStatus;
  }) {
    const connectedChainId = await wallet.getChainId();
    const { msgHash, message } = bridgeTx;
    if (!message || !msgHash) throw new Error('Message is not defined');

    const destChainId = Number(message.destChainId);

    // Are we connected to the correct chain?
    if (connectedChainId !== destChainId) {
      throw new WrongChainError('wallet must be connected to the destination chain');
    }

    log(`Claiming message with status ${messageStatus}`);

    // Has it been claimed already?
    if (messageStatus === MessageStatus.DONE) {
      throw new MessageStatusError('message already processed');
    }

    // Has it failed?
    if (messageStatus === MessageStatus.FAILED) {
      throw new MessageStatusError('user can not process this as message has failed');
    }
  }

  // Currently identical to beforeClaiming
  protected async beforeRetrying({
    bridgeTx,
    wallet,
    messageStatus,
  }: {
    bridgeTx: BridgeTransaction;
    wallet: WalletClient;
    messageStatus: MessageStatus;
  }) {
    await this.beforeClaiming({ bridgeTx, wallet, messageStatus });
  }

  /**
   * 1. Check that the wallet is connected to the destination chain
   * 2. Check that the message is owned by the user
   * 3. Check that the message has not been claimed already
   * 4. Check that the message has not failed
   *
   * Important: wallet must be connected to the destination chain
   */
  protected async beforeReleasing({
    bridgeTx,
    wallet,
    messageStatus,
  }: {
    bridgeTx: BridgeTransaction;
    wallet: WalletClient;
    messageStatus: MessageStatus;
  }) {
    const connectedChainId = await wallet.getChainId();
    const { msgHash, message } = bridgeTx;
    if (!message || !msgHash) throw new Error('Message is not defined');

    const srcChainId = Number(message.srcChainId);

    // Are we connected to the correct chain?
    if (connectedChainId !== srcChainId) {
      throw new WrongChainError('wallet must be connected to the source chain');
    }

    log(`Claiming message with status ${messageStatus}`);

    // Has it been claimed already?
    if (messageStatus === MessageStatus.DONE) {
      throw new MessageStatusError('message already processed');
    }

    if (messageStatus !== MessageStatus.FAILED) {
      throw new MessageStatusError('message must fail to release funds');
    }
    return;
  }

  abstract estimateGas(args: BridgeArgs): Promise<bigint>;
  abstract bridge(args: BridgeArgs): Promise<Hash>;

  async processMessage(args: ClaimArgs, force = false, skipMessageStatusCheck = false): Promise<Hash> {
    const { messageStatus, destBridgeAddress } = await this.beforeProcessing(args, skipMessageStatusCheck);
    let blockNumber;

    if (!args.bridgeTx.blockNumber && args.bridgeTx.receipt) {
      blockNumber = args.bridgeTx.receipt?.blockNumber;
    } else if (args.bridgeTx.blockNumber) {
      blockNumber = args.bridgeTx.blockNumber;
    } else {
      throw new ProcessMessageError('Blocknumber is not defined');
    }

    const { message, msgHash } = args.bridgeTx;
    if (!message || !msgHash)
      throw new ProcessMessageError(`message or msgHash  is not defined, ${message}, ${msgHash}, ${blockNumber}`);

    const client = await getConnectedWallet();
    if (!client) throw new Error('Client not found');

    const bridgeContract = await getContract({
      client,
      abi: bridgeAbi,
      address: destBridgeAddress,
    });

    const srcBridgeContract = await getContract({
      client,
      abi: bridgeAbi,
      address: routingContractsMap[Number(message.srcChainId)][Number(message.destChainId)].bridgeAddress,
    });

    try {
      let txHash: Hash;
      if (skipMessageStatusCheck) {
        await this.beforeDirectClaiming(args);
        txHash = await this.processNewMessage({ ...args, bridgeContract, client }, force);
      } else if (messageStatus === MessageStatus.NEW) {
        // Initial claim
        await this.beforeClaiming({ ...args, messageStatus });

        txHash = await this.processNewMessage({ ...args, bridgeContract, client }, force);
      } else if (messageStatus === MessageStatus.RETRIABLE) {
        // Claiming after a failed attempt
        await this.beforeRetrying({ ...args, messageStatus });
        txHash = await this.retryMessage({ ...args, bridgeContract, client });
      } else if (messageStatus === MessageStatus.FAILED) {
        // Release if the message has failed and the user wants to release the funds
        await this.beforeReleasing({ ...args, messageStatus });
        txHash = await this.release({ ...args, bridgeContract: srcBridgeContract, client });
      } else {
        throw new ProcessMessageError('Message status not supported for claiming.');
      }
      return txHash;
    } catch (err) {
      if (`${err}`.includes('denied transaction signature')) {
        console.error(err);
        throw new UserRejectedRequestError(err as Error);
      }
      throw err;
    }
  }

  private async processNewMessage(args: ProcessMessageType, force = false): Promise<Hash> {
    const { bridgeTx, bridgeContract, client } = args;
    const { message } = bridgeTx;
    if (!message) throw new ProcessMessageError('Message is not defined');
    const proof = await this._prover.getEncodedSignalProof({ bridgeTx });

    const destClient = getPublicClient(config, { chainId: Number(message.destChainId) });
    if (!destClient) throw new Error('Could not get public client');

    let estimatedGas;
    try {
      const estimation1 = bridgeContract.estimateGas.processMessage([message, proof], { account: client.account });
      const estimation2 = destClient.estimateContractGas({
        address: bridgeContract.address,
        abi: bridgeAbi,
        functionName: 'processMessage',
        args: [message, proof],
        account: client.account,
      });

      const results = await Promise.allSettled([estimation1, estimation2]);
      const gasEstimates = results
        .filter((result) => result.status === 'fulfilled')
        .map((result) => (result as PromiseFulfilledResult<bigint>).value);

      if (gasEstimates.length > 0) {
        log('Estimated gas for processMessage', ...gasEstimates);
        estimatedGas = gasEstimates.reduce((min, gas) => (gas < min ? gas : min), gasEstimates[0]);
      } else {
        throw new Error('All gas estimations failed');
      }
    } catch (error) {
      console.error('Failed to estimate gas, using fallback', error);
      estimatedGas = 1_300_000n;
    }

    if (message.to && (await isSmartContract(message.to, Number(message.destChainId)))) {
      log(`Recipient is a smart contract, increasing fees by 5 percent`);
      estimatedGas = (estimatedGas * 105n) / 100n;
    }
    if (force) {
      return await writeContract(config, {
        address: bridgeContract.address,
        abi: bridgeContract.abi,
        functionName: 'processMessage',
        args: [message, proof],
        gas: estimatedGas,
      });
    } else {
      const { request } = await simulateContract(config, {
        address: bridgeContract.address,
        abi: bridgeContract.abi,
        functionName: 'processMessage',
        args: [message, proof],
        gas: estimatedGas,
      });
      log('Simulate contract for processMessage', request);

      return await writeContract(config, request);
    }
  }

  private async retryMessage(args: RetryMessageArgs): Promise<Hash> {
    const { bridgeTx, bridgeContract, client } = args;
    const isFinalAttempt = args.lastAttempt || false;
    const { message } = bridgeTx;

    isFinalAttempt ? log('Retrying message for the last time') : log('Retrying message');

    if (!message) throw new ProcessMessageError('Message is not defined');

    let estimatedGas = await bridgeContract.estimateGas.retryMessage([message, isFinalAttempt], {
      account: client.account,
    });
    if (message.to && (await isSmartContract(message.to, Number(message.destChainId)))) {
      log(`Recipient is a smart contract, increasing fees by 5 percent`);
      estimatedGas = (estimatedGas * 105n) / 100n;
    }
    log('Estimated gas for retryMessage', estimatedGas);

    const { request } = await simulateContract(config, {
      address: bridgeContract.address,
      abi: bridgeContract.abi,
      functionName: 'retryMessage',
      args: [message, isFinalAttempt],
      gas: estimatedGas,
    });
    log('Simulate contract for retryMessage', request);

    return await writeContract(config, request);
  }

  private async release(args: ReleaseArgs) {
    const { bridgeTx, bridgeContract, client } = args;
    const { message } = bridgeTx;
    if (!message) throw new ReleaseError('Message is not defined');
    const proof = await this._prover.getEncodedSignalProofForRecall({ bridgeTx });

    log('Estimating gas for recallMessage', bridgeContract.address, [message, proof]);

    let estimatedGas = await bridgeContract.estimateGas.recallMessage([message, proof], { account: client.account });
    log('Estimated gas for recallMessage', estimatedGas);

    if (message.from && (await isSmartContract(message.from, Number(message.srcChainId)))) {
      log(`Sender is a smart contract, increasing fees by 5 percent`);
      estimatedGas = (estimatedGas * 105n) / 100n;
    }
    log('Estimated gas for retryMessage', estimatedGas);

    const { request } = await simulateContract(config, {
      address: bridgeContract.address,
      abi: bridgeContract.abi,
      functionName: 'recallMessage',
      args: [message, proof],
      gas: estimatedGas,
    });
    log('Simulate contract for recallMessage', request);

    return await writeContract(config, request);
  }
}
