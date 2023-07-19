import { getContract } from '@wagmi/core';

import { bridgeABI } from '$abi';
import { bridge } from '$config';
import { getLogger } from '$libs/util/logger';

import type { Bridge, ETHBridgeArgs, Message } from './types';

const log = getLogger('ETHBridge');

export class ETHBridge implements Bridge {
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

  async estimateGas(args: ETHBridgeArgs): Promise<bigint> {
    const { bridgeContract, message } = await ETHBridge._prepareTransaction(args);
    return bridgeContract.estimateGas.sendMessage([message]);
  }
}
