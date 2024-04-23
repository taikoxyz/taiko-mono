import { get } from 'svelte/store';

import { routingContractsMap } from '$bridgeConfig';
import {
  allApproved,
  destNetwork,
  enteredAmount,
  insufficientAllowance,
  selectedToken,
} from '$components/Bridge/state';
import { bridges, ContractType, type RequireApprovalArgs } from '$libs/bridge';
import type { ERC20Bridge } from '$libs/bridge/ERC20Bridge';
import type { ERC721Bridge } from '$libs/bridge/ERC721Bridge';
import type { ERC1155Bridge } from '$libs/bridge/ERC1155Bridge';
import { getContractAddressByType } from '$libs/bridge/getContractAddressByType';
import { InvalidParametersProvidedError, NotConnectedError, NoTokenError, UnknownTokenTypeError } from '$libs/error';
import { getConnectedWallet } from '$libs/util/getConnectedWallet';
import { getLogger } from '$libs/util/logger';
import { account, connectedSourceChain } from '$stores';

import { checkOwnershipOfNFT } from './checkOwnership';
import { type NFT, type Token, TokenType } from './types';

const log = getLogger('util:token:getTokenApprovalStatus');

export enum ApprovalStatus {
  ETH_NO_APPROVAL_REQUIRED,
  APPROVAL_REQUIRED,
  NO_APPROVAL_REQUIRED,
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

    if (nft.type === TokenType.ERC1155) {
      const bridge = bridges[nft.type] as ERC1155Bridge;
      try {
        // Let's check if the vault is approved for all ERC1155
        const isApprovedForAll = await bridge.isApprovedForAll(args);
        allApproved.set(isApprovedForAll);
        if (isApprovedForAll) {
          return ApprovalStatus.NO_APPROVAL_REQUIRED;
        }
        return ApprovalStatus.APPROVAL_REQUIRED;
      } catch (error) {
        console.error('isApprovedForAll error');
      }
    } else if (nft.type === TokenType.ERC721) {
      const bridge = bridges[nft.type] as ERC721Bridge;
      try {
        // Let's check if the vault is approved for all ERC721
        const requiresApproval = await bridge.requiresApproval(args);
        allApproved.set(!requiresApproval);
        if (requiresApproval) {
          return ApprovalStatus.APPROVAL_REQUIRED;
        }
        return ApprovalStatus.NO_APPROVAL_REQUIRED;
      } catch (error) {
        console.error('isApprovedForAll error');
      }
    }
  } else {
    log('unknown token type:', token);
    throw new UnknownTokenTypeError();
  }
  return ApprovalStatus.APPROVAL_REQUIRED;
};
