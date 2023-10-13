// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { AddressResolver } from "../../common/AddressResolver.sol";
import { IBridge } from "../IBridge.sol";
import { ISignalService } from "../../signal/ISignalService.sol";
import { LibAddress } from "../../libs/LibAddress.sol";
import { LibBridgeData } from "./LibBridgeData.sol";
import { LibSecureMerkleTrie } from "../../thirdparty/LibSecureMerkleTrie.sol";
import { LibSignalService } from "../../signal/SignalService.sol";

/// @title LibBridgeSend
/// @notice This library provides functions for sending bridge messages and
/// checking their status.
/// The library facilitates the process of sending messages to the Bridge,
/// validating input parameters, and managing Ether custody based on destination
/// chains.
library LibBridgeSend {
    using LibAddress for address;
    using LibBridgeData for IBridge.Message;

    error B_INCORRECT_VALUE();
    error B_USER_IS_NULL();
    error B_WRONG_CHAIN_ID();
    error B_WRONG_TO_ADDRESS();

    /// @notice Sends a message to the Bridge with the details of the request.
    /// @dev This function takes custody of the specified funds, sending them to
    /// the EtherVault on Taiko or storing them on the Bridge for processing on
    /// the destination chain.
    /// @param state The current state of the Bridge.
    /// @param resolver The address resolver.
    /// @param message The message to be sent, including value and fee details.
    /// @return msgHash The hash of the sent message.
    function sendMessage(
        LibBridgeData.State storage state,
        AddressResolver resolver,
        IBridge.Message memory message
    )
        internal
        returns (bytes32 msgHash)
    {
        // Ensure the message user is not null.
        if (message.user == address(0)) {
            revert B_USER_IS_NULL();
        }

        // Check if the destination chain is enabled.
        (bool destChainEnabled, address destBridge) =
            isDestChainEnabled(resolver, message.destChainId);

        // Verify destination chain and to address.
        if (!destChainEnabled || message.destChainId == block.chainid) {
            revert B_WRONG_CHAIN_ID();
        }
        if (message.to == address(0) || message.to == destBridge) {
            revert B_WRONG_TO_ADDRESS();
        }

        // Ensure the sent value matches the expected amount.
        uint256 expectedAmount = message.value + message.fee;
        if (expectedAmount != msg.value) {
            revert B_INCORRECT_VALUE();
        }

        // On Taiko, send the expectedAmount to the EtherVault; otherwise, store
        // it on the Bridge.
        address ethVault = resolver.resolve("ether_vault", true);
        ethVault.sendEther(expectedAmount);

        // Configure message details and send signal to indicate message
        // sending.
        message.id = state.nextMessageId++;
        message.from = msg.sender;
        message.srcChainId = block.chainid;

        msgHash = message.hashMessage();
        ISignalService(resolver.resolve("signal_service", false)).sendSignal(
            msgHash
        );
        emit LibBridgeData.MessageSent(msgHash, message);
    }

    /// @notice Checks if the destination chain is enabled.
    /// @param resolver The address resolver.
    /// @param chainId The destination chain ID.
    /// @return enabled True if the destination chain is enabled.
    /// @return destBridge The bridge of the destination chain.
    function isDestChainEnabled(
        AddressResolver resolver,
        uint256 chainId
    )
        internal
        view
        returns (bool enabled, address destBridge)
    {
        destBridge = resolver.resolve(chainId, "bridge", true);
        enabled = destBridge != address(0);
    }

    /// @notice Checks if the message was sent.
    /// @param resolver The address resolver.
    /// @param msgHash The hash of the sent message.
    /// @return True if the message was sent.
    function isMessageSent(
        AddressResolver resolver,
        bytes32 msgHash
    )
        internal
        view
        returns (bool)
    {
        return ISignalService(resolver.resolve("signal_service", false))
            .isSignalSent({ app: address(this), signal: msgHash });
    }

    /// @notice Checks if the message was received.
    /// @param resolver The address resolver.
    /// @param msgHash The hash of the received message.
    /// @param srcChainId The ID of the source chain.
    /// @param proofs The proofs of message receipt.
    /// @return True if the message was received.
    function isMessageReceived(
        AddressResolver resolver,
        bytes32 msgHash,
        uint256 srcChainId,
        bytes[] calldata proofs
    )
        internal
        view
        returns (bool)
    {
        if (proofs.length == 0) return false;

        // Check a chain of inclusion proofs, from the message's source
        // chain all the way to the destination chain.
        uint256 _srcChainId = srcChainId;
        address _app = resolver.resolve(srcChainId, "bridge", false);
        bytes32 _signal = msgHash;

        for (uint256 i; i < proofs.length - 1; ++i) {
            IBridge.IntermediateProof memory iproof =
                abi.decode(proofs[i], (IBridge.IntermediateProof));
            // perform inclusion check
            if (
                !LibSecureMerkleTrie.verifyInclusionProof(
                    bytes.concat(LibSignalService.getSignalSlot(_app, _signal)),
                    hex"01",
                    iproof.mkproof,
                    iproof.signalRoot
                )
            ) return false;

            _srcChainId = iproof.chainId;
            _app = resolver.resolve(iproof.chainId, "taiko", false);
            _signal = iproof.signalRoot;
        }

        return ISignalService(resolver.resolve("signal_service", false))
            .isSignalReceived({
            srcChainId: srcChainId,
            app: _app,
            signal: _signal,
            proof: proofs[proofs.length - 1]
        });
    }
}
