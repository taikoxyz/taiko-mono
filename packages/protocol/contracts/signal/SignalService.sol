// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { EssentialContract } from "../common/EssentialContract.sol";
import { ICrossChainSync } from "../common/ICrossChainSync.sol";
import { Proxied } from "../common/Proxied.sol";
import { LibSecureMerkleTrie } from "../thirdparty/LibSecureMerkleTrie.sol";

import { ISignalService } from "./ISignalService.sol";

/// @title SignalService
/// @notice See the documentation in {ISignalService} for more details.
contract SignalService is ISignalService, EssentialContract {
    struct Hop {
        uint256 chainId;
        bytes32 signalRoot;
        bytes mkproof;
    }

    struct SignalProof {
        uint64 height;
        bytes mkproof; // A storage proof
        Hop[] hops;
    }

    error SS_INVALID_SIGNAL();
    error SS_INVALID_APP();
    error SS_INVALID_CHAINID();

    modifier validApp(address app) {
        if (app == address(0)) revert SS_INVALID_APP();
        _;
    }

    modifier validSignal(bytes32 signal) {
        if (signal == 0) revert SS_INVALID_SIGNAL();
        _;
    }

    /// @dev Initializer to be called after being deployed behind a proxy.
    function init(address _addressManager) external initializer {
        EssentialContract._init(_addressManager);
    }

    /// @inheritdoc ISignalService
    function sendSignal(bytes32 signal)
        public
        validSignal(signal)
        returns (bytes32 storageSlot)
    {
        storageSlot = getSignalSlot(msg.sender, signal);
        assembly {
            sstore(storageSlot, 1)
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
        bytes32 slot = getSignalSlot(app, signal);
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
        validApp(app)
        validSignal(signal)
        returns (bool)
    {
        if (srcChainId == 0 || srcChainId == block.chainid) {
            revert SS_INVALID_CHAINID();
        }

        // Check a chain of inclusion proofs, from the message's source
        // chain all the way to the destination chain.
        SignalProof memory sp = abi.decode(proof, (SignalProof));
        bytes32 signalRoot = ICrossChainSync(resolve("taiko", false))
            .getCrossChainSignalRoot(sp.height);

        for (uint256 i; i < sp.hops.length; ++i) {
            Hop memory hop = sp.hops[i];
            bytes32 slot = getSignalSlot(
                resolve(hop.chainId, "taiko", false), hop.signalRoot
            );
            bool verified = LibSecureMerkleTrie.verifyInclusionProof(
                bytes.concat(slot), hex"01", hop.mkproof, signalRoot
            );
            if (!verified) return false;
            signalRoot = hop.signalRoot;
        }

        return LibSecureMerkleTrie.verifyInclusionProof(
            bytes.concat(getSignalSlot(app, signal)),
            hex"01",
            sp.mkproof,
            signalRoot
        );
    }

    /// @notice Get the storage slot of the signal.
    /// @param app The address that initiated the signal.
    /// @param signal The signal to get the storage slot of.
    /// @return signalSlot The unique storage slot of the signal which is
    /// created by encoding the sender address with the signal (message).
    function getSignalSlot(
        address app,
        bytes32 signal
    )
        public
        pure
        returns (bytes32 signalSlot)
    {
        // Equivalent to `keccak256(abi.encodePacked(app, signal))`
        assembly {
            // Load the free memory pointer
            let ptr := mload(0x40)
            // Store the app address and signal bytes32 value in the allocated
            // memory
            mstore(ptr, app)
            mstore(add(ptr, 32), signal)
            // Calculate the hash of the concatenated arguments using keccak256
            signalSlot := keccak256(add(ptr, 12), 52)
            // Update free memory pointer
            mstore(0x40, add(ptr, 64))
        }
    }
}

/// @title ProxiedSignalService
/// @notice Proxied version of the parent contract.
contract ProxiedSignalService is Proxied, SignalService { }
