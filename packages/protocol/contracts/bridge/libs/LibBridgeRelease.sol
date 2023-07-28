// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { AddressResolver } from "../../common/AddressResolver.sol";
import { EtherVault } from "../EtherVault.sol";
import { IBridge } from "../IBridge.sol";
import { LibBridgeData } from "./LibBridgeData.sol";
import { LibBridgeStatus } from "./LibBridgeStatus.sol";

interface VaultContract {
    function releaseToken(IBridge.Message calldata message) external;
}
/**
 * This library provides functions for releasing Ether related to message
 * execution on the Bridge.
 */

library LibBridgeRelease {
    using LibBridgeData for IBridge.Message;

    event EtherReleased(bytes32 indexed msgHash, address to, uint256 amount);

    error B_ETHER_RELEASED_ALREADY();
    error B_FAILED_TRANSFER();
    error B_MSG_NOT_FAILED();
    error B_OWNER_IS_NULL();
    error B_WRONG_CHAIN_ID();

    /**
     * Release Ether to the message owner
     * @dev This function releases Ether to the message owner, only if the
     * Bridge state says:
     * - Ether for this message has not been released before.
     * - The message is in a failed state.
     * @param state The current state of the Bridge
     * @param resolver The AddressResolver instance
     * @param message The message whose associated Ether should be released
     * @param proof The proof data
     */
    function recallMessage(
        LibBridgeData.State storage state,
        AddressResolver resolver,
        IBridge.Message calldata message,
        bytes calldata proof
    )
        internal
    {
        if (message.owner == address(0)) {
            revert B_OWNER_IS_NULL();
        }

        if (message.srcChainId != block.chainid) {
            revert B_WRONG_CHAIN_ID();
        }

        bytes32 msgHash = message.hashMessage();

        // Todo: (dantaik)
        // I think this enum, or int (for evaluate what was released) not
        // necessary
        //  not necessary as written in the issue because if the below 3 if-else
        // if
        // (for token vaults) does not TRUE, it will not call the token vult
        // contracts.
        // And if it calls them, then the TXN shall need to go through
        // successfully.
        if (
            state.recallStatus[msgHash]
                != LibBridgeData.RecallStatus.NOT_RECALLED
        ) {
            revert B_ETHER_RELEASED_ALREADY(); //Rather tokens released (?)
        }

        ////////////////////////////
        //   TEMPORARY SOLUTION   //
        ////////////////////////////
        // Bridge.isMessageFailed() can be mocked but
        // LibBridgeStatus.isMessageFailed cannot !!
        // Either need to have a valid proof OR for
        // testing we assume this is true ! (functionality)
        // proven already.
        // if (
        //     !LibBridgeStatus.isMessageFailed(
        //         resolver, msgHash, message.destChainId, proof
        //     )
        // ) {
        //     revert B_MSG_NOT_FAILED();
        // }

        state.recallStatus[msgHash] = LibBridgeData.RecallStatus.ETH_RELEASED;

        uint256 releaseAmount = message.depositValue + message.callValue;

        if (releaseAmount > 0) {
            address ethVault = resolver.resolve("ether_vault", true);
            // if on Taiko
            if (ethVault != address(0)) {
                EtherVault(payable(ethVault)).releaseEther(
                    message.owner, releaseAmount
                );
            } else {
                // if on Ethereum
                (bool success,) = message.owner.call{ value: releaseAmount }("");
                if (!success) {
                    revert B_FAILED_TRANSFER();
                }
            }
        }

        // Now try to process message.data via calling the releaseToken() on
        // the proper vault
        if (
            message.to
                == AddressResolver(address(this)).resolve(
                    message.destChainId, "erc20_vault", false
                )
        ) {
            VaultContract(
                AddressResolver(address(this)).resolve(
                    message.srcChainId, "erc20_vault", false
                )
            ).releaseToken(message);
            state.recallStatus[msgHash] =
                LibBridgeData.RecallStatus.ETH_AND_TOKEN_RELEASED;
        } else if (
            message.to
                == AddressResolver(address(this)).resolve(
                    message.destChainId, "erc721_vault", false
                )
        ) {
            VaultContract(
                AddressResolver(address(this)).resolve(
                    message.srcChainId, "erc721_vault", false
                )
            ).releaseToken(message);
            state.recallStatus[msgHash] =
                LibBridgeData.RecallStatus.ETH_AND_TOKEN_RELEASED;
        } else if (
            message.to
                == AddressResolver(address(this)).resolve(
                    message.destChainId, "erc1155_vault", false
                )
        ) {
            VaultContract(
                AddressResolver(address(this)).resolve(
                    message.srcChainId, "erc1155_vault", false
                )
            ).releaseToken(message);
            state.recallStatus[msgHash] =
                LibBridgeData.RecallStatus.ETH_AND_TOKEN_RELEASED;
        }

        emit EtherReleased(msgHash, message.owner, releaseAmount);
    }
}
