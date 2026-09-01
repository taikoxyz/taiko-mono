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
  const currentChainId = get(connectedSourceChain)?.id;
  const destinationChainId = get(destNetwork)?.id;
  if (!currentChainId || !destinationChainId) {
    log('no currentChainId or destinationChainId');
    throw new NotConnectedError();
  }

  const ownerAddress = get(account)?.address;
  const tokenAddress = get(selectedToken)?.addresses[currentChainId];
  log('selectedToken', get(selectedToken));

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
            needsApprovalReset.set(true);
            return ApprovalStatus.RESET_REQUIRED;
          }
        }
        return ApprovalStatus.APPROVAL_REQUIRED;
      }
      return ApprovalStatus.NO_APPROVAL_REQUIRED;
    } catch (error) {
      log('erc20 requireAllowance error', error);
      allApproved.set(false);
    }
  } else if (token.type === TokenType.ERC721 || token.type === TokenType.ERC1155) {
    log('checking approval status for NFT type' + token.type);
    const nft = token as NFT;
    const ownerShipChecks = await checkOwnershipOfNFT(token as NFT, ownerAddress, currentChainId);
    if (!ownerShipChecks.every((item) => item.isOwner === true)) {
      // A stale allApproved=true from a previously selected token must not survive
      allApproved.set(false);
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
      allApproved.set(!requiresApproval);
      return requiresApproval ? ApprovalStatus.APPROVAL_REQUIRED : ApprovalStatus.NO_APPROVAL_REQUIRED;
    } catch (error) {
      // A read that failed says nothing, and the ERC20 branch above already knows this: a
      // stale allApproved=true from a previously selected token otherwise leaves Bridge
      // enabled for an NFT whose approval could not be read at all
      allApproved.set(false);
      // The error itself was dropped here, leaving a bare "isApprovedForAll error" line
      console.error('Could not read the NFT approval status', error);
    }
  } else {
    log('unknown token type:', token);
    throw new UnknownTokenTypeError();
  }
  return ApprovalStatus.APPROVAL_REQUIRED;
};
