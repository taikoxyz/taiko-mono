import { getWalletClient, simulateContract, writeContract } from '@wagmi/core';
import { getContract, UserRejectedRequestError } from 'viem';

import { bridgeAbi } from '$abi';
import { BridgePausedError, SendMessageError } from '$libs/error';
import type { BridgeProver } from '$libs/proof';
import { isBridgePaused } from '$libs/util/checkForPausedContracts';
import { getLogger } from '$libs/util/logger';
import { config } from '$libs/wagmi';

import { Bridge } from './Bridge';
import type { ETHBridgeArgs, Message } from './types';

const log = getLogger('bridge:ETHBridge');

export class ETHBridge extends Bridge {
  private static async _prepareTransaction(args: ETHBridgeArgs) {
    const { to, amount, wallet, srcChainId, destChainId, bridgeAddress, fee: processingFee } = args;

    if (!wallet || !wallet.account) throw new Error('No wallet found');

    const bridgeContract = getContract({
      client: wallet,
      abi: bridgeAbi,
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

    const message: Message = {
      to,
      srcOwner: owner,
      from: owner,

      destOwner: to,

      srcChainId: BigInt(srcChainId),
      destChainId: BigInt(destChainId),

      gasLimit: 0,
      value,
      fee: processingFee,

      data: '0x',
      id: BigInt(0), // will be set in contract
    };

    const minGasLimit = await bridgeContract.read.getMessageMinGasLimit([0n]);
    log('Min gas limit for message', minGasLimit);

    const gasLimit = minGasLimit + 1;
    message.gasLimit = gasLimit;

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
        abi: bridgeAbi,
        functionName: 'sendMessage',
        args: [message],
        chainId,
        value,
      });
      log('Simulate contract', request);

      const txHash = await writeContract(config, request);
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
}
