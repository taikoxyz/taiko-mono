import { routingContractsMap } from "$bridgeConfig";
import {
  allApproved,
  destNetwork,
  enteredAmount,
  insufficientAllowance,
  needsApprovalReset,
  selectedToken,
} from "$components/Bridge/state";
import { bridges, ContractType, type RequireApprovalArgs } from "$libs/bridge";
import type { ERC20Bridge } from "$libs/bridge/ERC20Bridge";
import type { ERC721Bridge } from "$libs/bridge/ERC721Bridge";
import type { ERC1155Bridge } from "$libs/bridge/ERC1155Bridge";
import { getContractAddressByType } from "$libs/bridge/getContractAddressByType";
import {
  InvalidParametersProvidedError,
  NotConnectedError,
  NoTokenError,
  UnknownTokenTypeError,
} from "$libs/error";
import { getConnectedWallet } from "$libs/util/getConnectedWallet";
import { getLogger } from "$libs/util/logger";
import { account } from "$stores/account";
import { connectedSourceChain } from "$stores/network";

import { checkOwnershipOfNFT } from "./checkOwnership";
import { type NFT, type Token, TokenType } from "./types";

const log = getLogger("util:token:getTokenApprovalStatus");

export enum ApprovalStatus {
  ETH_NO_APPROVAL_REQUIRED,
  APPROVAL_REQUIRED,
  NO_APPROVAL_REQUIRED,
  RESET_REQUIRED,
}

export const getTokenApprovalStatus = async (
  token: Maybe<Token | NFT>,
): Promise<ApprovalStatus> => {
  log("getTokenApprovalStatus called", token);
  if (!token) {
    allApproved.setState(false);
    throw new NoTokenError();
  }
  if (token.type === TokenType.ETH) {
    allApproved.setState(true);
    log("token is ETH");
    return ApprovalStatus.ETH_NO_APPROVAL_REQUIRED;
  }
  const currentChainId = connectedSourceChain.getState()?.id;
  const destinationChainId = destNetwork.getState()?.id;
  if (!currentChainId || !destinationChainId) {
    log("no currentChainId or destinationChainId");
    throw new NotConnectedError();
  }

  const ownerAddress = account.getState()?.address;
  const tokenAddress = selectedToken.getState()?.addresses[currentChainId];
  log("selectedToken", selectedToken.getState());

  if (!ownerAddress || !tokenAddress) {
    log("no ownerAddress or tokenAddress", ownerAddress, tokenAddress);
    throw new InvalidParametersProvidedError("no ownerAddress or tokenAddress");
  }
  if (token.type === TokenType.ERC20) {
    log("checking approval status for ERC20");
    needsApprovalReset.setState(false);

    const tokenVaultAddress =
      routingContractsMap[currentChainId][destinationChainId].erc20VaultAddress;
    const bridge = bridges[TokenType.ERC20] as ERC20Bridge;

    try {
      const requireAllowance = await bridge.requireAllowance({
        amount: enteredAmount.getState(),
        tokenAddress,
        ownerAddress,
        spenderAddress: tokenVaultAddress,
      });
      log("erc20 requiresApproval", requireAllowance);
      insufficientAllowance.setState(requireAllowance);
      allApproved.setState(!requireAllowance);
      if (requireAllowance) {
        // specific check for USDT
        if (selectedToken.getState()?.symbol === "tUSDT") {
          const allowance = await bridge.getAllowance({
            amount: enteredAmount.getState(),
            tokenAddress,
            ownerAddress,
            spenderAddress: tokenVaultAddress,
          });
          if (allowance > 0n) {
            needsApprovalReset.setState(true);
            return ApprovalStatus.RESET_REQUIRED;
          }
        }
        return ApprovalStatus.APPROVAL_REQUIRED;
      }
      return ApprovalStatus.NO_APPROVAL_REQUIRED;
    } catch (error) {
      log("erc20 requireAllowance error", error);
      allApproved.setState(false);
    }
  } else if (
    token.type === TokenType.ERC721 ||
    token.type === TokenType.ERC1155
  ) {
    log("checking approval status for NFT type" + token.type);
    const nft = token as NFT;
    const ownerShipChecks = await checkOwnershipOfNFT(
      token as NFT,
      ownerAddress,
      currentChainId,
    );
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
      throw new InvalidParametersProvidedError("no spender address provided");
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
        allApproved.setState(isApprovedForAll);
        if (isApprovedForAll) {
          return ApprovalStatus.NO_APPROVAL_REQUIRED;
        }
        return ApprovalStatus.APPROVAL_REQUIRED;
      } catch {
        console.error("isApprovedForAll error");
      }
    } else if (nft.type === TokenType.ERC721) {
      const bridge = bridges[nft.type] as ERC721Bridge;
      try {
        // Let's check if the vault is approved for all ERC721
        const requiresApproval = await bridge.requiresApproval(args);
        allApproved.setState(!requiresApproval);
        if (requiresApproval) {
          return ApprovalStatus.APPROVAL_REQUIRED;
        }
        return ApprovalStatus.NO_APPROVAL_REQUIRED;
      } catch {
        console.error("isApprovedForAll error");
      }
    }
  } else {
    log("unknown token type:", token);
    throw new UnknownTokenTypeError();
  }
  return ApprovalStatus.APPROVAL_REQUIRED;
};
