import { getContract } from '@wagmi/core';

import { bridgeABI } from '$abi';
import { bridge } from '$config';
import { getLogger } from '$libs/util/logger';

import type { ETHBridgeArgs, Message } from './types';

const log = getLogger('ETHBridge');

export class ETHBridge {
  private static async _prepareTransaction(args: ETHBridgeArgs) {
    const { to, memo = '', amount, srcChainId, destChainId, walletClient, bridgeAddress, processingFee } = args;

    const bridgeContract = getContract({
      walletClient,
      abi: bridgeABI,
      address: bridgeAddress,
    });

    const owner = walletClient.account.address;

    // TODO: contract actually supports bridging to ourselves as well as
    //       to another address at the same time
    const [depositValue, callValue] =
      to.toLowerCase() === owner.toLowerCase() ? [amount, BigInt(0)] : [BigInt(0), amount];

    // If there is a processing fee
    const gasLimit = processingFee > 0 ? bridge.nonOwnerGasLimit : BigInt(0);

    const message: Message = {
      to,
      owner,
      sender: owner,
      refundAddress: owner,

      srcChainId,
      destChainId,

      gasLimit,
      callValue,
      depositValue,
      processingFee,

      memo,
      data: '0x',
    };

    log('Preparing transaction with message', message);

    return { bridgeContract, owner, message };
  }

  // async estimateGas(args: ): Promise<BigNumber> {
  //   const { contract, message } = await ETHBridge._prepareTransaction(opts);

  //   const value = message.depositValue
  //     .add(message.processingFee)
  //     .add(message.callValue);

  //   log(`Estimating gas for sendMessage. Value to send: ${value}`);

  //   try {
  //     // See https://docs.ethers.org/v5/api/contract/contract/#contract-estimateGas
  //     const gasEstimate = await contract.estimateGas.sendMessage(message, {
  //       value,
  //     });

  //     log('Estimated gas', gasEstimate.toString());

  //     return gasEstimate;
  //   } catch (error) {
  //     console.error(error);
  //     throw new Error('failed to estimate gas for sendMessage', {
  //       cause: error,
  //     });
  //   }
  // }
}
