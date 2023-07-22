import { getContract } from '@wagmi/core';
import { UserRejectedRequestError } from 'viem';

import { bridgeABI } from '$abi';
import { bridge } from '$config';
import { SendMessageError } from '$libs/error';
import { getLogger } from '$libs/util/logger';

import type { Bridge, ETHBridgeArgs, Message } from './types';

const log = getLogger('ETHBridge');

export class ETHBridge implements Bridge {
  private static async _prepareTransaction(args: ETHBridgeArgs) {
    const { to, amount, wallet, srcChainId, destChainId, bridgeAddress, processingFee, memo = '' } = args;

    const bridgeContract = getContract({
      walletClient: wallet,
      abi: bridgeABI,
      address: bridgeAddress,
    });

    const owner = wallet.account.address;

    // TODO: contract actually supports bridging to ourselves as well as
    //       to another address at the same time
    const [depositValue, callValue] =
      to.toLowerCase() === owner.toLowerCase() ? [amount, BigInt(0)] : [BigInt(0), amount];

    // If there is a processing fee, use the specified message gas limit
    // as might not be called by the owner
    const gasLimit = processingFee > 0 ? bridge.noOwnerGasLimit : BigInt(0);

    const message: Message = {
      to,
      owner,
      sender: owner,
      refundAddress: owner,

      srcChainId: BigInt(srcChainId),
      destChainId: BigInt(destChainId),

      gasLimit,
      callValue,
      depositValue,
      processingFee,

      memo,
      data: '0x',
      id: BigInt(0), // will be set in contract
    };

    log('Preparing transaction with message', message);

    return { bridgeContract, message };
  }

  async estimateGas(args: ETHBridgeArgs) {
    const { bridgeContract, message } = await ETHBridge._prepareTransaction(args);
    const { depositValue, callValue, processingFee } = message;

    const value = depositValue + callValue + processingFee;

    log('Estimating gas for sendMessage call with value', value);

    const estimatedGas = await bridgeContract.estimateGas.sendMessage([message], { value });

    log('Gas estimated', estimatedGas);

    return estimatedGas;
  }

  async bridge(args: ETHBridgeArgs) {
    const { bridgeContract, message } = await ETHBridge._prepareTransaction(args);
    const { depositValue, callValue, processingFee } = message;

    const value = depositValue + callValue + processingFee;

    try {
      log('Calling sendMessage with value', value);

      const txHash = await bridgeContract.write.sendMessage([message], { value });

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
