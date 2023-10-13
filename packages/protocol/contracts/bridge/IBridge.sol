// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { BridgeData } from "./BridgeData.sol";

/// @title IBridge
/// @notice The bridge used in conjunction with the {ISignalService}.
/// @dev Ether is held by Bridges on L1 and by the EtherVault on L2,
/// not by token vaults.
interface IBridge {
    /// @notice Sends a message to the destination chain and takes custody
    /// of Ether required in this contract. All extra Ether will be refunded.
    /// @param message The message to be sent.
    /// @return msgHash The hash of the sent message.
    function sendMessage(BridgeData.Message memory message)
        external
        payable
        returns (bytes32 msgHash);

    /// @notice Returns the bridge state context.
    /// @return context The context of the current bridge operation.
    function context()
        external
        view
        returns (BridgeData.Context memory context);
}
