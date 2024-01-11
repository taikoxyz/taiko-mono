import { get } from 'svelte/store';

import { routingContractsMap } from '$bridgeConfig';
import {
  allApproved,
  destNetwork,
  enteredAmount,
  insufficientAllowance,
  selectedToken,
  validatingAmount,
} from '$components/Bridge/state';
import { bridges, ContractType, type RequireApprovalArgs } from '$libs/bridge';
import type { ERC20Bridge } from '$libs/bridge/ERC20Bridge';
import type { ERC721Bridge } from '$libs/bridge/ERC721Bridge';
import type { ERC1155Bridge } from '$libs/bridge/ERC1155Bridge';
import { getContractAddressByType } from '$libs/bridge/getContractAddressByType';
import { getConnectedWallet } from '$libs/util/getConnectedWallet';
import { getLogger } from '$libs/util/logger';
import { account, network } from '$stores';

import { checkOwnershipOfNFT } from './checkOwnership';
import { type NFT, type Token, TokenType } from './types';

const log = getLogger('util:token:checkTokenApprovalStatus');

export const checkTokenApprovalStatus = async (token: Maybe<Token | NFT>): Promise<void> => {
  log('checkTokenApprovalStatus called', token);
  if (!token) {
    allApproved.set(false);
    return;
  }
  if (token.type === TokenType.ETH) {
    allApproved.set(true);
    log('token is ETH');
    return;
  }
  const currentChainId = get(network)?.id;
  const destinationChainId = get(destNetwork)?.id;
  if (!currentChainId || !destinationChainId) {
    log('no currentChainId or destinationChainId');
    return;
  }

  const ownerAddress = get(account)?.address;
  const tokenAddress = get(selectedToken)?.addresses[currentChainId];
  log('selectedToken', get(selectedToken));

  if (!ownerAddress || !tokenAddress) {
    log('no ownerAddress or tokenAddress', ownerAddress, tokenAddress);
    return;
  }
  if (token.type === TokenType.ERC20) {
    log('checking approval status for ERC20');

    const tokenVaultAddress = routingContractsMap[currentChainId][destinationChainId].erc20VaultAddress;

    const bridge = bridges[TokenType.ERC20] as ERC20Bridge;

    try {
      const requiresApproval = await bridge.requireAllowance({
        amount: get(enteredAmount),
        tokenAddress,
        ownerAddress,
        spenderAddress: tokenVaultAddress,
      });
      log('erc20 requiresApproval', requiresApproval);
      insufficientAllowance.set(requiresApproval);
      allApproved.set(!requiresApproval);
    } catch (error) {
      console.error('isApprovedForAll error');
      allApproved.set(false);
    }
  } else if (token.type === TokenType.ERC721 || token.type === TokenType.ERC1155) {
    log('checking approval status for NFT');
    const nft = token as NFT;
    const ownerShipChecks = await checkOwnershipOfNFT(token as NFT, ownerAddress, currentChainId);
    if (!ownerShipChecks.every((item) => item.isOwner === true)) {
      return;
    }
    const wallet = await getConnectedWallet();

    const spenderAddress = getContractAddressByType({
      srcChainId: currentChainId,
      destChainId: destinationChainId,
      tokenType: nft.type,
      contractType: ContractType.VAULT,
    });

    if (!spenderAddress) {
      throw new Error('No spender address found');
    }

    const args: RequireApprovalArgs = {
      tokenAddress: nft.addresses[currentChainId],
      owner: wallet.account.address,
      spenderAddress,
      tokenId: BigInt(nft.tokenId),
      chainId: currentChainId,
    };

    if (nft.type === TokenType.ERC1155) {
      log('checking approval status for ERC1155');
      const bridge = bridges[nft.type] as ERC1155Bridge;
      try {
        // Let's check if the vault is approved for all ERC1155
        const isApprovedForAll = await bridge.isApprovedForAll(args);
        allApproved.set(isApprovedForAll);
      } catch (error) {
        console.error('isApprovedForAll error');
      }
    } else if (nft.type === TokenType.ERC721) {
      log('checking approval status for ERC1155');
      const bridge = bridges[nft.type] as ERC721Bridge;
      try {
        // Let's check if the vault is approved for all ERC721
        const requiresApproval = await bridge.requiresApproval(args);
        allApproved.set(!requiresApproval);
      } catch (error) {
        console.error('isApprovedForAll error');
      } finally {
        validatingAmount.set(false);
      }
    }
  } else {
    log('unknown token type:', token);
  }
  return;
};
