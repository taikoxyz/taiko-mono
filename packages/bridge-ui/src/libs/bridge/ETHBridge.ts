import { getWalletClient, simulateContract, writeContract } from '@wagmi/core';
import { getContract, type Hash, UserRejectedRequestError } from 'viem';

import { bridgeABI } from '$abi';
import { routingContractsMap } from '$bridgeConfig';
import { bridgeService } from '$config';
import { BridgePausedError, ProcessMessageError, ReleaseError, SendMessageError } from '$libs/error';
import type { BridgeProver } from '$libs/proof';
import { isBridgePaused } from '$libs/util/checkForPausedContracts';
import { getConnectedWallet } from '$libs/util/getConnectedWallet';
import { getLogger } from '$libs/util/logger';
import { config } from '$libs/wagmi';

import { Bridge } from './Bridge';
import { type ClaimArgs, type ETHBridgeArgs, type Message, MessageStatus, type ReleaseArgs } from './types';

const log = getLogger('bridge:ETHBridge');

export class ETHBridge extends Bridge {
  private static async _prepareTransaction(args: ETHBridgeArgs) {
    const { to, amount, wallet, srcChainId, destChainId, bridgeAddress, fee: processingFee, memo = '' } = args;

    if (!wallet || !wallet.account) throw new Error('No wallet found');

    const bridgeContract = getContract({
      client: wallet,
      abi: bridgeABI,
      address: bridgeAddress,
    });

    const owner = wallet.account.address;

    // TODO: contract actually supports bridging to ourselves as well as
    //       to another address at the same time
    const [senderAmount, recipientAmount] =
      to.toLowerCase() === owner.toLowerCase() ? [amount, BigInt(0)] : [BigInt(0), amount];
    let value;
    if (senderAmount === BigInt(0)) {
      value = recipientAmount;
    } else {
      value = senderAmount;
    }

    // If there is a processing fee, use the specified message gas limit
    // as might not be called by the owner
    const gasLimit = processingFee > 0 ? bridgeService.noOwnerGasLimit : BigInt(0);

    const message: Message = {
      to,
      owner,
      from: owner,
      refundTo: owner,

      srcChainId: BigInt(srcChainId),
      destChainId: BigInt(destChainId),

      gasLimit,
      value,
      fee: processingFee,

      memo,
      data: '0x',
      id: BigInt(0), // will be set in contract
    };

    log('Preparing transaction with message', message);

    return { bridgeContract, message };
  }

  constructor(prover: BridgeProver) {
    super(prover);
  }

  async estimateGas(args: ETHBridgeArgs) {
    const { bridgeContract, message } = await ETHBridge._prepareTransaction(args);
    const { value: callValue, fee: processingFee } = message;

    const value = callValue + processingFee;

    log('Estimating gas for sendMessage call with value', value);

    const estimatedGas = await bridgeContract.estimateGas.sendMessage([message], { value });

    log('Gas estimated', estimatedGas);

    return estimatedGas;
  }

  async bridge(args: ETHBridgeArgs) {
    isBridgePaused().then((paused) => {
      if (paused) throw new BridgePausedError('Bridge is paused');
    });

    const { bridgeContract, message } = await ETHBridge._prepareTransaction(args);
    const { value: callValue, fee: processingFee } = message;

    const value = callValue + processingFee;

    try {
      log('Calling sendMessage with value', value);

      const chainId = (await getWalletClient(config)).chain.id;

      const { request } = await simulateContract(config, {
        address: bridgeContract.address,
        abi: bridgeABI,
        functionName: 'sendMessage',
        args: [message],
        chainId,
        value,
      });
      log('Simulate contract', request);

      const txHash = await writeContract(config, {
        address: bridgeContract.address,
        abi: bridgeABI,
        functionName: 'sendMessage',
        args: [message],
        chainId,
        value,
      });
      log('Transaction hash for sendMessage call', txHash);

      return txHash;
    } catch (err) {
      console.error(err);

      if (`${err}`.includes('denied transaction signature')) {
        throw new UserRejectedRequestError(err as Error);
      }

      throw new SendMessageError('failed to bridge ETH', { cause: err });
    }
  }

  async claim(args: ClaimArgs) {
    const { messageStatus, destBridgeAddress } = await super.beforeClaiming(args);

    let txHash: Hash;
    const { msgHash, message } = args;
    const srcChainId = Number(message.srcChainId);
    const destChainId = Number(message.destChainId);

    const client = await getConnectedWallet();
    if (!client) throw new Error('Client not found');

    const bridgeContract = await getContract({
      client,
      abi: bridgeABI,
      address: destBridgeAddress,
    });

    if (messageStatus === MessageStatus.NEW) {
      const proof = await this._prover.encodedSignalProof(msgHash, srcChainId, destChainId);

      const estimatedGas = await bridgeContract.estimateGas.processMessage([message, proof], {
        account: client.account,
      });
      log('Estimated gas', estimatedGas);

      try {
        const { request } = await simulateContract(config, {
          address: destBridgeAddress,
          abi: bridgeABI,
          functionName: 'processMessage',
          args: [message, proof],
          gas: estimatedGas,
        });
        log('Simulate contract', request);

        txHash = await writeContract(config, {
          address: destBridgeAddress,
          abi: bridgeABI,
          functionName: 'processMessage',
          args: [message, proof],
          gas: estimatedGas,
        });
        return txHash;
        log('Transaction hash for processMessage call', txHash);
      } catch (err) {
        console.error(err);

        // TODO: possibly same logic as ERC20Bridge

        // TODO: handle unpredictable gas limit error
        //       by trying with a higher gas limit

        if (`${err}`.includes('denied transaction signature')) {
          throw new UserRejectedRequestError(err as Error);
        }

        throw new ProcessMessageError('failed to claim ETH', { cause: err });
      }
    } else {
      // MessageStatus.RETRIABLE
      //TODO IMPLEMENT RETRY
      throw new Error('Not implemented');
      // txHash = await super.retryClaim(message, destBridgeContract);
    }
  }

  async release(args: ReleaseArgs) {
    await super.beforeReleasing(args);

    const { msgHash, message, wallet } = args;
    const srcChainId = Number(message.srcChainId);
    const destChainId = Number(message.destChainId);
    const connectedChainId = await wallet.getChainId();

    const proof = await this._prover.generateProofToRelease(msgHash, srcChainId, destChainId);

    const srcBridgeAddress = routingContractsMap[connectedChainId][destChainId].bridgeAddress;
    if (!wallet || !wallet.account || !wallet.chain) throw new Error('Wallet is not connected');

    try {
      const { request } = await simulateContract(config, {
        address: srcBridgeAddress,
        abi: bridgeABI,
        functionName: 'recallMessage',
        args: [message, proof],
        chainId: wallet.chain.id,
      });
      log('Simulate contract', request);

      const txHash = await writeContract(config, {
        address: srcBridgeAddress,
        abi: bridgeABI,
        functionName: 'recallMessage',
        args: [message, proof],
        chainId: wallet.chain.id,
      });

      log('Transaction hash for releaseEther call', txHash);

      return txHash;
    } catch (err) {
      console.error(err);

      if (`${err}`.includes('denied transaction signature')) {
        throw new UserRejectedRequestError(err as Error);
      }

      throw new ReleaseError('failed to release ETH', { cause: err });
    }
  }
}
