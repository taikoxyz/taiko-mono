import { get } from 'svelte/store';

import { routingContractsMap } from '$bridgeConfig';
import {
  allApproved,
  destNetwork,
  enteredAmount,
  insufficientAllowance,
  needsApprovalReset,
  selectedToken,
} from '$components/Bridge/state';
import { bridges, ContractType, type RequireApprovalArgs } from '$libs/bridge';
import type { ERC20Bridge } from '$libs/bridge/ERC20Bridge';
import { getContractAddressByType } from '$libs/bridge/getContractAddressByType';
import type { NFTBridge } from '$libs/bridge/NFTBridge';
import { InvalidParametersProvidedError, NotConnectedError, NoTokenError, UnknownTokenTypeError } from '$libs/error';
import { getConnectedWallet } from '$libs/util/getConnectedWallet';
import { getLogger } from '$libs/util/logger';
import { account, connectedSourceChain } from '$stores';

import { tokenNeedsAllowanceReset } from './approvalReset';
import { checkOwnershipOfNFT } from './checkOwnership';
import { isSameNFT, tokensAreSame } from './tokenIdentity';
import { type NFT, type Token, TokenType } from './types';

const log = getLogger('util:token:getTokenApprovalStatus');

export enum ApprovalStatus {
  ETH_NO_APPROVAL_REQUIRED,
  APPROVAL_REQUIRED,
  NO_APPROVAL_REQUIRED,
  RESET_REQUIRED,
}

export const getTokenApprovalStatus = async (token: Maybe<Token | NFT>): Promise<ApprovalStatus> => {
  log('getTokenApprovalStatus called', token);
  if (!token) {
    allApproved.set(false);
    throw new NoTokenError();
  }
  if (token.type === TokenType.ETH) {
    allApproved.set(true);
    log('token is ETH');
    return ApprovalStatus.ETH_NO_APPROVAL_REQUIRED;
  }
  /**
   * Every store written below describes "the selected token". This read is polled for
   * seconds after an approval and the user can switch tokens meanwhile; a late answer for
   * the previous token must return its status without publishing it, or the new token
   * inherits an allowance nothing read for it. Compared by deployment rather than by
   * reference: the selection is rebuilt on every list refresh.
   */
  const stillSelected = () => {
    const current = get(selectedToken);
    if (!current) return false;
    return 'tokenId' in token ? isSameNFT(token as NFT, current as NFT) : tokensAreSame(token, current);
  };

  const currentChainId = get(connectedSourceChain)?.id;
  const destinationChainId = get(destNetwork)?.id;
  if (!currentChainId || !destinationChainId) {
    log('no currentChainId or destinationChainId');
    throw new NotConnectedError();
  }

  const ownerAddress = get(account)?.address;
  // The argument, not the store: this is polled after an approval and can be running for a
  // token the user has since switched away from, and reading the store here answered the
  // new token's question with the old token's name on it
  const tokenAddress = token.addresses[currentChainId];

  if (!ownerAddress || !tokenAddress) {
    log('no ownerAddress or tokenAddress', ownerAddress, tokenAddress);
    throw new InvalidParametersProvidedError('no ownerAddress or tokenAddress');
  }
  if (token.type === TokenType.ERC20) {
    log('checking approval status for ERC20');
    needsApprovalReset.set(false);

    const tokenVaultAddress = routingContractsMap[currentChainId][destinationChainId].erc20VaultAddress;
    const bridge = bridges[TokenType.ERC20] as ERC20Bridge;

    try {
      const requireAllowance = await bridge.requireAllowance({
        amount: get(enteredAmount),
        tokenAddress,
        ownerAddress,
        spenderAddress: tokenVaultAddress,
      });
      log('erc20 requiresApproval', requireAllowance);
      if (!stillSelected())
        return requireAllowance ? ApprovalStatus.APPROVAL_REQUIRED : ApprovalStatus.NO_APPROVAL_REQUIRED;
      insufficientAllowance.set(requireAllowance);
      allApproved.set(!requireAllowance);
      if (requireAllowance) {
        // USDT-style tokens must reset a non-zero allowance to 0 before it can be raised
        if (tokenNeedsAllowanceReset(token, currentChainId)) {
          const allowance = await bridge.getAllowance({
            amount: get(enteredAmount),
            tokenAddress,
            ownerAddress,
            spenderAddress: tokenVaultAddress,
          });
          if (allowance > 0n) {
            if (stillSelected()) needsApprovalReset.set(true);
            return ApprovalStatus.RESET_REQUIRED;
          }
        }
        return ApprovalStatus.APPROVAL_REQUIRED;
      }
      return ApprovalStatus.NO_APPROVAL_REQUIRED;
    } catch (error) {
      log('erc20 requireAllowance error', error);
      if (stillSelected()) allApproved.set(false);
    }
  } else if (token.type === TokenType.ERC721 || token.type === TokenType.ERC1155) {
    log('checking approval status for NFT type' + token.type);
    const nft = token as NFT;
    let ownerShipChecks;
    try {
      ownerShipChecks = await checkOwnershipOfNFT(nft, ownerAddress, currentChainId);
    } catch (error) {
      // Same reason the not-owner branch below clears it: a stale allApproved=true from a
      // previously selected token must not survive a read that could not be made, or the
      // Bridge button stays enabled for an NFT whose approval state is unknown
      log('checkOwnershipOfNFT error', error);
      if (stillSelected()) allApproved.set(false);
      throw error;
    }
    if (!ownerShipChecks.every((item) => item.isOwner === true)) {
      // A stale allApproved=true from a previously selected token must not survive
      if (stillSelected()) allApproved.set(false);
      return ApprovalStatus.APPROVAL_REQUIRED;
    }
    const wallet = await getConnectedWallet();

    const spenderAddress = getContractAddressByType({
      srcChainId: currentChainId,
      destChainId: destinationChainId,
      tokenType: nft.type,
      contractType: ContractType.VAULT,
    });

    if (!spenderAddress) {
      throw new InvalidParametersProvidedError('no spender address provided');
    }

    const args: RequireApprovalArgs = {
      tokenAddress: nft.addresses[currentChainId],
      owner: wallet.account.address,
      spenderAddress,
      tokenId: BigInt(nft.tokenId),
      chainId: currentChainId,
    };

    // One question for both standards. They answer it differently - ERC721 reads a
    // per-token approval and falls back to the operator one, ERC1155 has only the operator
    // one - but requiresApproval is where that difference belongs, and the two branches
    // here were the same code with the polarity flipped
    const bridge = bridges[nft.type] as NFTBridge;
    try {
      const requiresApproval = await bridge.requiresApproval(args);
      if (stillSelected()) allApproved.set(!requiresApproval);
      return requiresApproval ? ApprovalStatus.APPROVAL_REQUIRED : ApprovalStatus.NO_APPROVAL_REQUIRED;
    } catch (error) {
      // A read that failed says nothing, and the ERC20 branch above already knows this: a
      // stale allApproved=true from a previously selected token otherwise leaves Bridge
      // enabled for an NFT whose approval could not be read at all
      if (stillSelected()) allApproved.set(false);
      // The error itself was dropped here, leaving a bare "isApprovedForAll error" line
      console.error('Could not read the NFT approval status', error);
      // Stated rather than left to the function's final return: an unknown approval is
      // the conservative answer, and it should not depend on a fall-through fifty lines
      // below that a later edit could quietly change
      return ApprovalStatus.APPROVAL_REQUIRED;
    }
  } else {
    log('unknown token type:', token);
    throw new UnknownTokenTypeError();
  }
  return ApprovalStatus.APPROVAL_REQUIRED;
};
