// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { AddressResolver } from "../contracts/common/AddressResolver.sol";
import { EtherVault } from "../contracts/bridge/EtherVault.sol";
import {
    IRecallableMessageSender, IBridge
} from "../contracts/bridge/IBridge.sol";
import { LibBridgeData } from "../contracts/bridge/libs/LibBridgeData.sol";
import { LibBridgeStatus } from "../contracts/bridge/libs/LibBridgeStatus.sol";
import { LibAddress } from "../contracts/libs/LibAddress.sol";

interface VaultContract {
    function releaseToken(IBridge.Message calldata message) external;
}
/**
 * This library provides functions for releasing Ether related to message
 * execution on the Bridge.
 */

library LibBridgeRecall {
    using LibBridgeData for IBridge.Message;
    using LibAddress for address;

    event MessageRecalled(
        bytes32 indexed msgHash,
        address owner,
        uint256 amount,
        LibBridgeData.RecallStatus status
    );

    error B_ETHER_RELEASED_ALREADY();
    error B_FAILED_TRANSFER();
    error B_MSG_NOT_FAILED();

    /**
     * Release Ether to the message owner
     * @dev This function releases Ether to the message owner, only if the
     * Bridge state says:
     * - Ether for this message has not been released before.
     * - The message is in a failed state.
     * @param state The current state of the Bridge
     * @param resolver The AddressResolver instance
     * @param message The message whose associated Ether should be released
     */
    function recallMessage(
        LibBridgeData.State storage state,
        AddressResolver resolver,
        IBridge.Message calldata message,
        bytes calldata
    )
        internal
    {
        bytes32 msgHash = message.hashMessage();

        ///////////////////////////
        //  Mock to avoid valid  //
        //  proofs.This part is  //
        //  already tested in    //
        //  in other tests with  //
        //  valid proofs.        //
        ///////////////////////////
        if (false) {
            revert B_MSG_NOT_FAILED();
        }

        if (
            state.recallStatus[msgHash]
                == LibBridgeData.RecallStatus.FULLY_RECALLED
        ) {
            // Both ether and tokens are released
            revert B_ETHER_RELEASED_ALREADY();
        }

        uint256 releaseAmount;

        if (
            state.recallStatus[msgHash]
                == LibBridgeData.RecallStatus.NOT_RECALLED
        ) {
            // Release ETH first
            state.recallStatus[msgHash] =
                LibBridgeData.RecallStatus.ETH_RELEASED;

            releaseAmount = message.depositValue + message.callValue;

            if (releaseAmount > 0) {
                address ethVault = resolver.resolve("ether_vault", true);
                // if on Taiko
                if (ethVault != address(0)) {
                    EtherVault(payable(ethVault)).releaseEther(
                        message.owner, releaseAmount
                    );
                } else {
                    // if on Ethereum
                    (bool success,) =
                        message.owner.call{ value: releaseAmount }("");
                    if (!success) {
                        revert B_FAILED_TRANSFER();
                    }
                }
            }
        }
        // 2nd stage is releasing the tokens
        if (
            state.recallStatus[msgHash]
                == LibBridgeData.RecallStatus.ETH_RELEASED
        ) {
            if (
                !message.sender.supportsInterface(
                    type(IRecallableMessageSender).interfaceId
                )
            ) {
                state.recallStatus[msgHash] =
                    LibBridgeData.RecallStatus.FULLY_RECALLED;
            } else {
                try IRecallableMessageSender(message.sender).onMessageRecalled(
                    message
                ) returns (bytes4 _selector) {
                    if (
                        IRecallableMessageSender.onMessageRecalled.selector
                            == _selector
                    ) {
                        state.recallStatus[msgHash] =
                            LibBridgeData.RecallStatus.FULLY_RECALLED;
                    }
                } catch { }
            }
        }
        emit MessageRecalled(
            msgHash, message.owner, releaseAmount, state.recallStatus[msgHash]
        );
    }
}
