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
import { BridgeData } from "../BridgeData.sol";
import { LibSecureMerkleTrie } from "../../thirdparty/LibSecureMerkleTrie.sol";
import { LibSignalService } from "../../signal/SignalService.sol";

/// @title LibBridgeSignal
/// @notice This library provides functions for verifying signal status
library LibBridgeSignal {
    using LibAddress for address;

    error B_SIGNAL_NULL();
    error B_WRONG_CHAIN_ID();

    /// @notice Checks if the signal was sent.
    /// @param resolver The address resolver.
    /// @param signal The hash of the sent message.
    /// @return True if the message was sent.
    function isSignalSent(
        AddressResolver resolver,
        bytes32 signal
    )
        internal
        view
        returns (bool)
    {
        return ISignalService(resolver.resolve("signal_service", false))
            .isSignalSent({ app: address(this), signal: signal });
    }

    /// @notice Checks if the signal was received.
    /// @param resolver The address resolver.
    /// @param signal The signal.
    /// @param srcChainId The ID of the source chain.
    /// @param proofs The proofs of message receipt.
    /// @return True if the message was received.
    function isSignalReceived(
        AddressResolver resolver,
        bytes32 signal,
        uint256 srcChainId,
        bytes[] calldata proofs
    )
        internal
        view
        returns (bool)
    {
        if (proofs.length == 0) return false;
        if (signal == 0x0) revert B_SIGNAL_NULL();
        if (srcChainId == block.chainid) revert B_WRONG_CHAIN_ID();

        // Check a chain of inclusion proofs, from the message's source
        // chain all the way to the destination chain.
        uint256 _srcChainId = srcChainId;
        address _app = resolver.resolve(srcChainId, "bridge", false);
        bytes32 _signal = signal;

        for (uint256 i; i < proofs.length - 1; ++i) {
            BridgeData.IntermediateProof memory iproof =
                abi.decode(proofs[i], (BridgeData.IntermediateProof));
            // perform inclusion check
            bool verified = LibSecureMerkleTrie.verifyInclusionProof(
                bytes.concat(LibSignalService.getSignalSlot(_app, _signal)),
                hex"01",
                iproof.mkproof,
                iproof.signalRoot
            );
            if (!verified) return false;

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
