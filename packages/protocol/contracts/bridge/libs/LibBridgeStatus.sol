// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { AddressResolver } from "../../common/AddressResolver.sol";
import { ISignalService } from "../../signal/ISignalService.sol";

import { BridgeData } from "../BridgeData.sol";

/// @title LibBridgeStatus
/// @notice This library provides functions for getting and updating the status
/// of bridge messages.
/// The library handles various aspects of message statuses, including their
/// retrieval, update, and verification of failure status on the destination
/// chain.
library LibBridgeStatus {
    event MessageStatusChanged(
        bytes32 indexed msgHash, BridgeData.Status status
    );

    /// @notice Updates the status of a bridge message.
    /// @dev If the new status is different from the current status in the
    /// mapping, the status is updated and an event is emitted.
    /// @param msgHash The hash of the message.
    /// @param status The new status of the message.
    function updateMessageStatus(
        BridgeData.State storage state,
        AddressResolver resolver,
        bytes32 msgHash,
        BridgeData.Status status
    )
        internal
    {
        if (state.statuses[msgHash] != status) {
            state.statuses[msgHash] = status;
            if (status == BridgeData.Status.FAILED) {
                ISignalService(resolver.resolve("signal_service", false))
                    .sendSignal(getDerivedSignalForFailedMessage(msgHash));
            }
            emit MessageStatusChanged(msgHash, status);
        }
    }

    function getDerivedSignalForFailedMessage(bytes32 msgHash)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encodePacked("SIGNAL", BridgeData.Status.FAILED, msgHash)
        );
    }
}
