// SPDX-License-Identifier: MIT

// ASCII art or logo representing the contract or library.
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { EssentialContract } from "../common/EssentialContract.sol";
import { Proxied } from "../common/Proxied.sol";
import { ICrossChainSync } from "../common/ICrossChainSync.sol";
import { ISignalService } from "./ISignalService.sol";
import { LibSecureMerkleTrie } from "../thirdparty/LibSecureMerkleTrie.sol";

/**
 * @title SignalService
 *
 * @dev The SignalService contract serves as a cross-chain signaling mechanism,
 * allowing external entities to send and verify signals within the Ethereum
 * ecosystem. A "signal" in this context refers to a form of on-chain message or
 * flag that can be verified by other contracts or entities across different
 * chains. Such a mechanism is essential for cross-chain operations where
 * certain actions or states need to be validated across multiple blockchain
 * networks.
 *
 * Signals are persisted on-chain using the `sendSignal` method, which sets a
 * particular storage slot based on the sender's address and the signal itself.
 *
 * The contract also provides the ability to check whether a given signal was
 * sent by a specific address using the `isSignalSent` method. Moreover, it
 * offers cross-chain signal verification with the `isSignalReceived` method,
 * ensuring a signal sent from a source chain can be validated on a destination
 * chain.
 *
 * Internally, the SignalService contract utilizes Merkle trie proofs, provided
 * by `LibSecureMerkleTrie`, to verify the inclusion of signals.
 *
 * Note:
 * While sending and checking signals on the current chain is straightforward,
 * cross-chain signal verification requires a proof of the signal's existence on
 * the source chain.
 *
 * Important:
 * Before deploying or upgrading, always ensure you're aware of the contract's
 * nuances, and have appropriately set the security contact.
 */
contract SignalService is ISignalService, EssentialContract {
    struct SignalProof {
        uint256 height;
        bytes proof; // A storage proof
    }

    error B_ZERO_SIGNAL();
    error B_NULL_APP_ADDR();
    error B_WRONG_CHAIN_ID();

    modifier validApp(address app) {
        if (app == address(0)) revert B_NULL_APP_ADDR();
        _;
    }

    modifier validSignal(bytes32 signal) {
        if (signal == 0) revert B_ZERO_SIGNAL();
        _;
    }

    modifier validChainId(uint256 srcChainId) {
        if (srcChainId == block.chainid) revert B_WRONG_CHAIN_ID();
        _;
    }

    /// @dev Initializer to be called after being deployed behind a proxy.
    function init(address _addressManager) external initializer {
        EssentialContract._init(_addressManager);
    }

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

    function isSignalReceived(
        uint256 srcChainId,
        address app,
        bytes32 signal,
        bytes calldata proof
    )
        public
        view
        validChainId(srcChainId)
        validApp(app)
        validSignal(signal)
        returns (bool)
    {
        SignalProof memory signalProof = abi.decode(proof, (SignalProof));
        bytes32 syncedSignalRoot = ICrossChainSync(resolve("taiko", false))
            .getCrossChainSignalRoot(signalProof.height);

        return LibSecureMerkleTrie.verifyInclusionProof(
            bytes.concat(getSignalSlot(app, signal)),
            hex"01",
            signalProof.proof,
            syncedSignalRoot
        );
    }

    function getSignalSlot(
        address app,
        bytes32 signal
    )
        public
        pure
        returns (bytes32 signalSlot)
    {
        assembly {
            let ptr := mload(0x40) // Load the free memory pointer
            mstore(ptr, app)
            mstore(add(ptr, 32), signal)
            signalSlot := keccak256(add(ptr, 12), 52)
            mstore(0x40, add(ptr, 64)) // Update free memory pointer
        }
    }
}

/**
 * @title ProxiedSignalService
 * @dev Proxied version of the SignalService contract.
 */
contract ProxiedSignalService is Proxied, SignalService { }
