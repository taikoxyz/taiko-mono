// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { AddressResolver } from "../common/AddressResolver.sol";
import { AuthorizableContract } from "../common/AuthorizableContract.sol";
import { ICrossChainSync } from "../common/ICrossChainSync.sol";
import { Proxied } from "../common/Proxied.sol";
import { LibSecureMerkleTrie } from "../thirdparty/LibSecureMerkleTrie.sol";

import { ISignalService } from "./ISignalService.sol";

/// @title SignalService
/// @notice See the documentation in {ISignalService} for more details.
contract SignalService is AuthorizableContract, ISignalService {
    struct Hop {
        uint256 chainId;
        bytes32 signalRoot;
        bytes storageProof;
    }

    struct Proof {
        uint64 height;
        bytes storageProof;
        Hop[] hops;
    }

    error SS_INVALID_APP();
    error SS_INVALID_SIGNAL();

    modifier validApp(address app) {
        if (app == address(0)) revert SS_INVALID_APP();
        _;
    }

    modifier validSignal(bytes32 signal) {
        if (signal == 0) revert SS_INVALID_SIGNAL();
        _;
    }

    // TODO(daniel): _addressManager must be address(0)
    /// @dev Initializer to be called after being deployed behind a proxy.
    function init(address _addressManager) external initializer {
        AuthorizableContract._init(_addressManager);
    }

    /// @inheritdoc ISignalService
    function sendSignal(bytes32 signal)
        public
        validSignal(signal)
        returns (bytes32 slot)
    {
        slot = getSignalSlot(block.chainid, msg.sender, signal);
        assembly {
            sstore(slot, 1)
        }
    }

    /// @inheritdoc ISignalService
    function isSignalSent(
        address app,
        bytes32 signal
    )
        public
        view
        validApp(app)
        validSignal(signal)
        returns (bool)
    {
        bytes32 slot = getSignalSlot(block.chainid, app, signal);
        uint256 value;
        assembly {
            value := sload(slot)
        }
        return value == 1;
    }

    /// @inheritdoc ISignalService
    function proveSignalReceived(
        uint256 srcChainId,
        address app,
        bytes32 signal,
        bytes calldata proof
    )
        public
        view
        returns (bool)
    {
        if (skipProofCheck()) return true;

        if (
            app == address(0) || signal == 0 || srcChainId == 0
                || srcChainId == block.chainid
        ) {
            return false;
        }

        Proof memory p = abi.decode(proof, (Proof));
        if (p.storageProof.length == 0) return false;

        for (uint256 i; i < p.hops.length; ++i) {
            if (p.hops[i].signalRoot == 0) return false;
            if (p.hops[i].storageProof.length == 0) return false;
        }

        // Check a chain of inclusion proofs. If this chain is chainA, and the
        // message is sent on chainC, and we have chainB in the middle, we
        // verify that chainB's signalRoot has been sent as a signal by chainB's
        // "taiko" contract, then using chainB's signalRoot, we further check
        // the signal is sent by chainC's "bridge" contract.

        // TODO(daniel): remove ussage of "resolve" and use "isAuthorized"
        address taiko = resolve("taiko", false);

        bytes32 signalRoot =
            ICrossChainSync(taiko).getSyncedSnippet(p.height).signalRoot;

        if (signalRoot == 0) return false;

        for (uint256 i; i < p.hops.length; ++i) {
            Hop memory hop = p.hops[i];
            bytes32 slot = getSignalSlot(
                hop.chainId,
                // TODO: use the following
                // AddressResolver(taiko).resolve(hop.chainId, "taiko", false),
                resolve(hop.chainId, "taiko", false),
                hop.signalRoot // as a signal
            );
            bool verified = LibSecureMerkleTrie.verifyInclusionProof(
                bytes.concat(slot), hex"01", hop.storageProof, signalRoot
            );
            if (!verified) return false;

            signalRoot = hop.signalRoot;
        }

        return LibSecureMerkleTrie.verifyInclusionProof(
            bytes.concat(getSignalSlot(srcChainId, app, signal)),
            hex"01",
            p.storageProof,
            signalRoot
        );
    }

    /// @notice Get the storage slot of the signal.
    /// @param chainId The address's chainId.
    /// @param app The address that initiated the signal.
    /// @param signal The signal to get the storage slot of.
    /// @return The unique storage slot of the signal which is
    /// created by encoding the sender address with the signal (message).
    function getSignalSlot(
        uint256 chainId,
        address app,
        bytes32 signal
    )
        public
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked("SIGNAL", chainId, app, signal));
    }

    /// @notice Tells if we need to check real proof or it is a test.
    /// @return Returns true to skip checking inclusion proofs.
    function skipProofCheck() public pure virtual returns (bool) { }
}

/// @title ProxiedSignalService
/// @notice Proxied version of the parent contract.
contract ProxiedSignalService is Proxied, SignalService { }
