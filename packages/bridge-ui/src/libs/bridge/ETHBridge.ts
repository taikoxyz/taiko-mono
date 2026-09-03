import { simulateContract, writeContract } from '@wagmi/core';
import { UserRejectedRequestError } from 'viem';

import { bridgeAbi } from '$abi';
import { SendMessageError } from '$libs/error';
import type { BridgeProver } from '$libs/proof';
import { getLogger } from '$libs/util/logger';
import { config } from '$libs/wagmi';

import { Bridge } from './Bridge';
import { assertNoViolations, checkETHMessage } from './messageInvariants';
import type { ETHBridgeArgs, Message } from './types';

const log = getLogger('bridge:ETHBridge');

export class ETHBridge extends Bridge {
  private async _prepareTransaction(args: ETHBridgeArgs) {
    const { to, amount, srcChainId, destChainId, bridgeAddress } = args;

    const {
      contract: bridgeContract,
      owner,
      destOwner,
      gasLimit,
      fee,
      commonFields,
    } = await this.prepareSend({ args, abi: bridgeAbi, address: bridgeAddress });

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

      destOwner,

      srcChainId: BigInt(srcChainId),
      destChainId: BigInt(destChainId),

      gasLimit,
      value,
      fee,

      data: '0x',
      id: BigInt(0), // will be set in contract
    };

    log('Preparing transaction with message', message);

    // Refuse a message the bridge is guaranteed to reject, while the reason is still
    // something we can name
    assertNoViolations(checkETHMessage(commonFields), 'This ETH transfer');

    return { bridgeContract, message };
  }

  constructor(prover: BridgeProver) {
    super(prover);
  }

  async estimateGas(args: ETHBridgeArgs) {
    const { bridgeContract, message } = await this._prepareTransaction(args);
    const { value: callValue, fee: processingFee } = message;

    const value = callValue + processingFee;

    log('Estimating gas for sendMessage call with value', value);

    const estimatedGas = await bridgeContract.estimateGas.sendMessage([message], { value });

    log('Gas estimated', estimatedGas);

    return estimatedGas;
  }

  async bridge(args: ETHBridgeArgs) {
    const { bridgeContract, message } = await this._prepareTransaction(args);
    const { value: callValue, fee: processingFee } = message;

    const value = callValue + processingFee;

    try {
      log('Calling sendMessage with value', value);

      const { request } = await simulateContract(config, {
        address: bridgeContract.address,
        abi: bridgeAbi,
        functionName: 'sendMessage',
        args: [message],
        // The wallet this was prepared for, on the chain it was prepared for: wagmi would
        // otherwise sign with whatever account and chain the connector holds by now
        account: args.wallet.account,
        chainId: args.srcChainId,
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
