// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import {AddressResolver} from "../../common/AddressResolver.sol";
import {EtherVault} from "../EtherVault.sol";
import {IBridge} from "../IBridge.sol";
import {LibBridgeData} from "./LibBridgeData.sol";
import {LibBridgeStatus} from "./LibBridgeStatus.sol";

library LibBridgeRelease {
    using LibBridgeData for IBridge.Message;

    event EtherReleased(bytes32 indexed msgHash, address to, uint256 amount);

    error B_ETHER_RELEASED_ALREADY();
    error B_FAILED_TRANSFER();
    error B_MSG_NOT_FAILED();
    error B_OWNER_IS_NULL();
    error B_WRONG_CHAIN_ID();

    /**
     * Release Ether to the message owner, only if the Taiko Bridge state says:
     * - Ether for this message has not been released before.
     * - The message is in a failed state.
     */
    function releaseEther(
        LibBridgeData.State storage state,
        AddressResolver resolver,
        IBridge.Message calldata message,
        bytes calldata proof
    ) internal {
        if (message.owner == address(0)) {
            revert B_OWNER_IS_NULL();
        }

        if (message.srcChainId != block.chainid) {
            revert B_WRONG_CHAIN_ID();
        }

        bytes32 msgHash = message.hashMessage();

        if (state.etherReleased[msgHash] == true) {
            revert B_ETHER_RELEASED_ALREADY();
        }

        if (!LibBridgeStatus.isMessageFailed(resolver, msgHash, message.destChainId, proof)) {
            revert B_MSG_NOT_FAILED();
        }

        state.etherReleased[msgHash] = true;

        uint256 releaseAmount = message.depositValue + message.callValue;

        if (releaseAmount > 0) {
            address ethVault = resolver.resolve("ether_vault", true);
            // if on Taiko
            if (ethVault != address(0)) {
                EtherVault(payable(ethVault)).releaseEther(message.owner, releaseAmount);
            } else {
                // if on Ethereum
                (bool success,) = message.owner.call{value: releaseAmount}("");
                if (!success) {
                    revert B_FAILED_TRANSFER();
                }
            }
        }
        emit EtherReleased(msgHash, message.owner, releaseAmount);
    }
}
