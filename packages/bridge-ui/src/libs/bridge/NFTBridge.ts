import { simulateContract, writeContract } from '@wagmi/core';
import { getAddress, type Hash, UserRejectedRequestError } from 'viem';

import type { erc721VaultAbi, erc1155VaultAbi } from '$abi';
import { ApproveError, NoApprovalRequiredError, NoCanonicalInfoFoundError, NotApprovedError } from '$libs/error';
import type { TokenType } from '$libs/token';
import { getCanonicalInfoForAddress } from '$libs/token/getCanonicalInfoForToken';
import { getLogger } from '$libs/util/logger';
import { config } from '$libs/wagmi';

import { Bridge } from './Bridge';
import type { MessageGasEstimateExtras } from './estimateMessageGasLimit';
import { assertNoViolations, type CommonMessageFields, type MessageInvariantViolation } from './messageInvariants';
import type { ERC721BridgeArgs, NFTApproveArgs, NFTBridgeTransferOp, RequireApprovalArgs } from './types';

/** The message fields an NFT vault adds to the ones every token type shares */
type NFTMessageFields = CommonMessageFields & {
  tokenAddress: string;
  tokenIds: bigint[];
  amounts: bigint[];
};

/**
 * What ERC721 and ERC1155 bridging has in common, which is nearly all of it.
 *
 * The two vaults take the same `sendToken` operation, are prepared the same way, are
 * estimated the same way, and gate the send on the same question - is the vault allowed to
 * move this token. They differ in four places, each of which is an abstract member below:
 * the vault they call, the invariant rules that vault enforces, how "approved" is read, and
 * how it is granted. Everything else lived twice, and a fix to one copy routinely missed
 * the other: the pause check existed only in ERC721, the wallet guard ran after the
 * contract was built in ERC721 and before it in ERC1155, and the two disagreed on whether
 * a failed approval check should keep its own error type.
 */
export abstract class NFTBridge extends Bridge {
  /** Names the token standard in log lines and error messages */
  protected abstract readonly standard: string;
  protected abstract readonly tokenType: TokenType;
  protected abstract readonly vaultAbi: typeof erc721VaultAbi | typeof erc1155VaultAbi;

  /** @dev The logger of the concrete bridge, so log lines keep naming the standard */
  protected abstract readonly log: ReturnType<typeof getLogger>;

  /**
   * @dev Whether an approval transaction is still required before the vault can move the
   *      token. ERC721 asks per token and falls back to the operator approval; ERC1155
   *      only has the operator approval.
   * @param args The token, the vault, the id, the owner and the chain
   * @return required_ Whether the user still has to approve
   */
  abstract requiresApproval(args: RequireApprovalArgs): Promise<boolean>;

  /**
   * @dev Simulates the call that grants the vault what it needs: `approve` for a single
   *      ERC721 token, `setApprovalForAll` for ERC1155.
   * @param args The token, the vault, the id and the chain
   * @return request_ The simulated request, ready to write
   */
  protected abstract simulateApproval(args: {
    tokenAddress: `0x${string}`;
    spenderAddress: `0x${string}`;
    tokenId: bigint;
    chainId: number;
  }): Promise<{ request: unknown }>;

  /** @dev The vault's own invariant rules, on top of the ones every message shares */
  protected abstract checkMessage(message: NFTMessageFields): MessageInvariantViolation[];

  /** @dev What this vault's destination gas estimate needs beyond the token */
  protected abstract gasEstimateExtras(args: ERC721BridgeArgs): MessageGasEstimateExtras;

  /** @dev Wraps a failure to send, so each standard keeps its own error type */
  protected abstract sendError(cause: unknown): Error;

  async estimateGas(args: ERC721BridgeArgs): Promise<bigint> {
    const { tokenVaultContract, sendArgs } = await this._prepareTransaction(args);
    const { fee: value } = sendArgs;

    this.log(`Estimating gas for ${this.standard} sendToken call with args`, sendArgs);

    const estimatedGas = await tokenVaultContract.estimateGas.sendToken([sendArgs], { value });

    this.log('Gas estimated', estimatedGas);

    return estimatedGas;
  }

  async bridge(args: ERC721BridgeArgs): Promise<Hash> {
    const { token, tokenVaultAddress, tokenIds, wallet, srcChainId, destChainId } = args;

    const { tokenVaultContract, sendArgs } = await this._prepareTransaction(args);
    const { fee } = sendArgs;

    const tokenId = tokenIds[0]; // TODO: support multiple tokenIds

    if (!wallet || !wallet.account || !wallet.chain) throw new Error('Wallet is not connected');

    try {
      const info = await getCanonicalInfoForAddress({ address: token, srcChainId, destChainId, type: this.tokenType });
      if (!info) throw new NoCanonicalInfoFoundError('No canonical info found for token');
      const { address: canonicalTokenAddress } = info;

      // Checksummed before comparing. These two addresses come from different places - one
      // from the canonical lookup, one from the args - and an EVM address is the same
      // address whatever its casing. A mismatch here reads as "bridged", which skips the
      // approval check entirely and sends a transfer the vault is not allowed to make.
      if (getAddress(canonicalTokenAddress) === getAddress(token)) {
        // A native token still lives in the user's wallet, so the vault needs permission to
        // take it. A bridged one is minted by the vault itself and needs none.
        const requireApproval = await this.requiresApproval({
          tokenAddress: token,
          spenderAddress: tokenVaultAddress,
          tokenId: BigInt(tokenId),
          owner: wallet.account.address,
          chainId: wallet.chain.id,
        });
        if (requireApproval) {
          throw new NotApprovedError(`The token with id ${tokenId} is not approved for the token vault`);
        }
      } else {
        this.log('Token is bridged, no need to check for approval');
      }
    } catch (err) {
      // The two verdicts this phase exists to reach are kept as themselves - they name a
      // condition the caller can act on. Anything else here is an RPC that failed while
      // asking, which is a failure to send this token and reads better as one than as a
      // bare Error from a lookup the caller never invoked.
      if (err instanceof NotApprovedError || err instanceof NoCanonicalInfoFoundError) throw err;
      throw this.sendError(err);
    }

    try {
      this.log(`Sending ${this.standard} with fee`, fee);
      this.log(`Sending ${this.standard} with args`, sendArgs);

      const { request } = await simulateContract(config, {
        address: tokenVaultContract.address,
        abi: this.vaultAbi,
        functionName: 'sendToken',
        args: [sendArgs],
        value: fee,
      });
      this.log('Simulate contract', request);

      const txHash = await writeContract(config, request);

      this.log(`${this.standard} sent`, txHash);

      return txHash;
    } catch (err) {
      console.error(err);
      if (`${err}`.includes('denied transaction signature')) {
        throw new UserRejectedRequestError(err as Error);
      }
      throw this.sendError(err);
    }
  }

  async approve(args: NFTApproveArgs): Promise<Hash> {
    const { tokenAddress, spenderAddress, wallet, tokenIds } = args;
    if (!wallet || !wallet.account || !wallet.chain) throw new Error('Wallet is not connected');

    const tokenId = tokenIds[0]; // TODO: support multiple tokenIds
    const chainId = wallet.chain.id;

    const requireApproval = await this.requiresApproval({
      tokenAddress,
      spenderAddress,
      tokenId,
      owner: wallet.account.address,
      chainId,
    });

    this.log(`required approval for token ${tokenId}: ${requireApproval}`);

    if (!requireApproval) {
      this.log(`No approval required for the token ${tokenId}`);
      throw new NoApprovalRequiredError(`No approval required for the token ${tokenId}`);
    }

    try {
      this.log(`Calling approve for spender "${spenderAddress}" for token`, tokenIds);

      const { request } = await this.simulateApproval({ tokenAddress, spenderAddress, tokenId, chainId });
      this.log('Simulate contract', request);

      const txHash = await writeContract(config, request as Parameters<typeof writeContract>[1]);

      this.log('Transaction hash for approve call', txHash);

      return txHash;
    } catch (err) {
      console.error(err);

      if (`${err}`.includes('denied transaction signature')) {
        throw new UserRejectedRequestError(err as Error);
      }

      throw new ApproveError(`failed to approve ${this.standard} token`, { cause: err });
    }
  }

  protected async _prepareTransaction(args: ERC721BridgeArgs) {
    const { destChainId, token, tokenVaultAddress, tokenIds, amounts } = args;

    const {
      contract: tokenVaultContract,
      to,
      destOwner,
      gasLimit,
      fee,
      commonFields,
    } = await this.prepareSend({
      args,
      abi: this.vaultAbi,
      address: tokenVaultAddress,
      gasEstimate: this.gasEstimateExtras(args),
    });

    const sendArgs = {
      destChainId: BigInt(destChainId),
      to,
      destOwner,
      token,
      gasLimit,
      fee,
      tokenIds: tokenIds.map(BigInt),
      amounts,
    } satisfies NFTBridgeTransferOp;

    this.log('Preparing transaction with args', sendArgs);

    // Refuse a message the bridge is guaranteed to reject, while the reason is still
    // something we can name
    assertNoViolations(
      this.checkMessage({
        ...commonFields,
        tokenAddress: sendArgs.token,
        tokenIds: sendArgs.tokenIds,
        amounts: sendArgs.amounts,
      }),
      'This NFT transfer',
    );

    return { tokenVaultContract, sendArgs };
  }
}
