// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { AddressResolver } from "../../../common/AddressResolver.sol";
import { Erc721Vault } from "../../Erc721Vault.sol";
import { IErc721Bridge } from "../IErc721Bridge.sol";
import { LibErc721BridgeData } from "./LibErc721BridgeData.sol";
import { LibErc721BridgeStatus } from "./LibErc721BridgeStatus.sol";

/**
 * This library provides functions for releasing tokens related to message
 * execution on the Bridge.
 */
library LibErc721BridgeRelease {
    using LibErc721BridgeData for IErc721Bridge.Message;

    //event TokenReleasedErc721(bytes32 indexed msgHash, address to, address
    // token, uint256[] tokenIds);

    error ERC721_B_TOKEN_RELEASED_ALREADY();
    error ERC721_B_FAILED_TRANSFER();
    error ERC721_B_MSG_NOT_FAILED();
    error ERC721_B_OWNER_IS_NULL();
    error ERC721_B_WRONG_CHAIN_ID();

    /**
     * Release Token(s) to the message owner
     * @dev This function releases Ether to the message owner, only if the
     * Bridge state says:
     * - Ether for this message has not been released before.
     * - The message is in a failed state.
     * @param state The current state of the Bridge
     * @param resolver The AddressResolver instance
     * @param message The message whose associated Ether should be released
     * @param proof The proof data
     */
    function releaseTokensErc721(
        LibErc721BridgeData.State storage state,
        AddressResolver resolver,
        IErc721Bridge.Message calldata message,
        bytes calldata proof
    )
        internal
    {
        if (message.owner == address(0)) {
            revert ERC721_B_OWNER_IS_NULL();
        }

        if (message.srcChainId != block.chainid) {
            revert ERC721_B_WRONG_CHAIN_ID();
        }

        bytes32 msgHash = message.hashMessage();

        if (state.tokensReleased[msgHash] == true) {
            revert ERC721_B_TOKEN_RELEASED_ALREADY();
        }

        if (
            !LibErc721BridgeStatus.isMessageFailedErc721(
                resolver, msgHash, message.destChainId, proof
            )
        ) {
            revert ERC721_B_MSG_NOT_FAILED();
        }

        state.tokensReleased[msgHash] = true;

        // Send tokens to vault
        address erc20Vault = resolver.resolve("erc721_vault", false);

        // User has to accept address(this) to transfer NFT tokens on behalf
        // prior to using the ERC721 Birdge (!) just as with ERC20
        if (erc20Vault != address(0)) {
            Erc721Vault(erc20Vault).releaseTokens(
                message.owner, message.tokenContract, message.tokenIds
            );
        }

        //emit TokenReleasedErc721(msgHash, message.owner,
        // message.tokenContract, message.tokenIds);
    }
}
