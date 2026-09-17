import { readContract, simulateContract, writeContract } from '@wagmi/core';
import { type Address, type Hash, UserRejectedRequestError, type WalletClient } from 'viem';

import { erc20Abi, erc20VaultAbi } from '$abi';
import {
  ApproveError,
  InsufficientAllowanceError,
  NoAllowanceRequiredError,
  PermitBridgeError,
  SendERC20Error,
} from '$libs/error';
import type { BridgeProver } from '$libs/proof';
import { getConnectedWallet } from '$libs/util/getConnectedWallet';
import { getLogger } from '$libs/util/logger';
import { config } from '$libs/wagmi';

import { Bridge } from './Bridge';
import { assertNoViolations, checkERC20Message } from './messageInvariants';
import { type ERC20SendPlan, markPermitUnusable, planErc20Send, signPermit, signPermit2Transfer } from './permit';
import type { ApproveArgs, ERC20BridgeArgs, ERC20BridgeTransferOp, RequireAllowanceArgs } from './types';

const log = getLogger('ERC20Bridge');

/**
 * @dev Whether the wallet declined, at either of the prompts a signature flow puts up: the
 *      typed-data signature and then the transaction. Wallets word the two differently.
 * @param err What the wallet round trip rejected with
 * @return rejected_ Whether the user said no
 */
const isUserRejection = (err: unknown) =>
  err instanceof UserRejectedRequestError ||
  `${err}`.includes('denied transaction signature') ||
  `${err}`.includes('denied message signature') ||
  `${err}`.includes('User rejected the request');

export class ERC20Bridge extends Bridge {
  private async _prepareTransaction(args: ERC20BridgeArgs) {
    const { amount, destChainId, token, tokenVaultAddress, isTokenAlreadyDeployed } = args;

    const {
      contract: tokenVaultContract,
      to,
      destOwner,
      gasLimit,
      fee,
      commonFields,
    } = await this.prepareSend({
      args,
      abi: erc20VaultAbi,
      address: tokenVaultAddress,
      gasEstimate: { isTokenAlreadyDeployed },
    });

    const sendERC20Args = {
      destChainId: BigInt(destChainId),
      destOwner,
      to,
      token,
      amount,
      gasLimit,
      fee,
    } satisfies ERC20BridgeTransferOp;

    log('Preparing transaction with args', sendERC20Args);

    // Refuse a message the bridge is guaranteed to reject, while the reason is still
    // something we can name
    assertNoViolations(checkERC20Message({ ...commonFields, amount, tokenAddress: token }), 'This token transfer');

    return { tokenVaultContract, sendERC20Args };
  }

  constructor(prover: BridgeProver) {
    super(prover);
  }

  async estimateGas(args: ERC20BridgeArgs) {
    const { tokenVaultContract, sendERC20Args } = await this._prepareTransaction(args as ERC20BridgeArgs);
    const { fee } = sendERC20Args;

    const value = fee;

    log('Estimating gas for sendERC20 call with value', value);

    const estimatedGas = await tokenVaultContract.estimateGas.sendToken([sendERC20Args], { value });

    log('Gas estimated', estimatedGas);

    return estimatedGas;
  }

  async getAllowance({ amount, tokenAddress, ownerAddress, spenderAddress }: RequireAllowanceArgs) {
    // No pause check: reading an allowance is unaffected by a paused bridge, and the read
    // ran the check against every configured chain on every call. The send path guards
    // itself in _prepareTransaction, which is where a pause actually matters.
    log('Checking allowance for the amount', amount);
    const allowance = await readContract(config, {
      abi: erc20Abi,
      address: tokenAddress,
      functionName: 'allowance',
      args: [ownerAddress, spenderAddress],
      chainId: (await getConnectedWallet()).chain.id,
    });

    return allowance;
  }
  async requireAllowance({ amount, tokenAddress, ownerAddress, spenderAddress }: RequireAllowanceArgs, reset = false) {
    const allowance = await this.getAllowance({ amount, tokenAddress, ownerAddress, spenderAddress });

    if (reset) {
      return true;
    }
    const requiresAllowance = allowance < amount;

    log('Allowance is', allowance, 'requires allowance?', requiresAllowance);

    return requiresAllowance;
  }

  async approve(args: ApproveArgs, reset = false) {
    const { amount, tokenAddress, spenderAddress, wallet } = args;
    if (!wallet || !wallet.account) throw new Error('No wallet found');
    const requireAllowance = await this.requireAllowance(
      {
        amount,
        tokenAddress,
        ownerAddress: wallet.account.address,
        spenderAddress,
      },
      reset,
    );

    if (!requireAllowance) {
      throw new NoAllowanceRequiredError(`no allowance required for the amount ${amount}`);
    }

    try {
      log(`Calling approve for spender "${spenderAddress}" for token "${tokenAddress}" with amount`, amount);
      // USDT does not play nice with the default ERC20 ABI, this works for both
      const approvalABI = [
        {
          constant: false,
          inputs: [
            {
              name: '_spender',
              type: 'address',
            },
            {
              name: '_value',
              type: 'uint256',
            },
          ],
          name: 'approve',
          outputs: [],
          payable: false,
          stateMutability: 'nonpayable',
          type: 'function',
        },
      ];

      const { request } = await simulateContract(config, {
        address: tokenAddress,
        abi: approvalABI,
        functionName: 'approve',
        args: [spenderAddress, amount],
      });
      log('Simulate contract', request);

      if (!wallet || !wallet.account || !wallet.chain) throw new Error('Wallet is not connected');

      const txHash = await writeContract(config, request);

      log('Transaction hash for approve call', txHash);

      return txHash;
    } catch (err) {
      console.error(err);

      if (`${err}`.includes('denied transaction signature')) {
        throw new UserRejectedRequestError(err as Error);
      }

      throw new ApproveError('failed to approve ERC20 token', { cause: err });
    }
  }

  /**
   * @dev Signs where the plan needs it, then simulates and sends the vault call it picked.
   *
   *      Three entrypoints, one message: `sendToken` against a standing allowance,
   *      `sendTokenWithPermit` with an EIP-2612 signature the vault consumes, and
   *      `sendTokenWithPermit2` with a Permit2 transfer signature. The operation, the wallet,
   *      the chain and the value are the same for all three; each call is spelled out
   *      because viem types the arguments off the literal function name.
   *
   * @param plan The flow planErc20Send picked for this send
   * @param call The prepared operation and what it is sent with
   * @return txHash_ The hash of the transaction the wallet sent
   */
  private async _sendWithPlan(
    plan: Exclude<ERC20SendPlan, { method: 'approve' }>,
    call: { wallet: WalletClient; chainId: number; vault: Address; op: ERC20BridgeTransferOp; fee: bigint },
  ): Promise<Hash> {
    const { wallet, chainId, vault: address, op, fee: value } = call;
    // The wallet this was prepared for, on the chain it was prepared for: wagmi would
    // otherwise sign with whatever account and chain the connector holds by now
    const account = wallet.account;
    const abi = erc20VaultAbi;

    switch (plan.method) {
      case 'permit': {
        const { deadline, v, r, s } = await signPermit({
          wallet,
          domain: plan.domain,
          token: op.token,
          spender: address,
          amount: op.amount,
        });
        const { request } = await simulateContract(config, {
          address,
          abi,
          functionName: 'sendTokenWithPermit',
          args: [op, deadline, v, r, s],
          account,
          chainId,
          value,
        });
        log('Simulate contract for sendTokenWithPermit', request);
        return writeContract(config, request);
      }
      case 'permit2': {
        const { nonce, deadline, signature } = await signPermit2Transfer({
          wallet,
          chainId,
          permit2: plan.permit2,
          token: op.token,
          spender: address,
          amount: op.amount,
        });
        const { request } = await simulateContract(config, {
          address,
          abi,
          functionName: 'sendTokenWithPermit2',
          args: [op, nonce, deadline, signature],
          account,
          chainId,
          value,
        });
        log('Simulate contract for sendTokenWithPermit2', request);
        return writeContract(config, request);
      }
      default: {
        const { request } = await simulateContract(config, {
          address,
          abi,
          functionName: 'sendToken',
          args: [op],
          account,
          chainId,
          value,
        });
        log('Simulate contract for sendToken', request);
        return writeContract(config, request);
      }
    }
  }

  async bridge(args: ERC20BridgeArgs) {
    const { amount, token, wallet, tokenVaultAddress, srcChainId } = args;

    if (!wallet || !wallet.account || !wallet.chain) throw new Error('Wallet is not connected');

    // Decided here, from the arguments, rather than carried over from the confirm step: an
    // allowance can change while that step is open, and the plan is cheap to make again
    const plan = await planErc20Send({
      chainId: srcChainId,
      token,
      owner: wallet.account.address,
      vault: tokenVaultAddress,
      amount,
    });
    log('Send plan', plan);

    if (plan.method === 'approve') {
      throw new InsufficientAllowanceError(`Insufficient allowance for the amount ${amount}`);
    }

    const { tokenVaultContract, sendERC20Args } = await this._prepareTransaction(args);
    const { fee } = sendERC20Args;

    try {
      const txHash = await this._sendWithPlan(plan, {
        wallet,
        chainId: srcChainId,
        vault: tokenVaultContract.address,
        op: sendERC20Args,
        fee,
      });

      log('Transaction hash for sendERC20 call', txHash);

      return txHash;
    } catch (err) {
      console.error(err);

      if (isUserRejection(err)) {
        throw new UserRejectedRequestError(err as Error);
      }

      if (plan.method !== 'sendToken') {
        // The chain, or the wallet, refused the signed flow: a permit the token verifies
        // differently, a wallet that cannot sign typed data. Whatever it was, the plain
        // approval works, so the flow is ruled out for this token and the Approve button
        // comes back on the next status read
        markPermitUnusable(srcChainId, token, plan.method);
        throw new PermitBridgeError(`failed to bridge ERC20 token via ${plan.method}`, { cause: err });
      }

      throw new SendERC20Error('failed to bridge ERC20 token', { cause: err });
    }
  }
}
