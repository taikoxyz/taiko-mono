// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

import "../../common/AddressResolver.sol";
import "../../common/IHeaderSync.sol";
import "../../libs/LibBlockHeader.sol";
import "../../libs/LibTrieProof.sol";
import "./LibBridgeData.sol";
import "./LibBridgeStatus.sol";

/**
 * Library for working with bridge signals.
 *
 * @title LibBridgeSignal
 * @author dantaik <dan@taiko.xyz>
 */
library LibBridgeSignal {
    using LibBlockHeader for BlockHeader;

    struct SignalProof {
        BlockHeader header;
        bytes proof;
    }

    struct StatusProof {
        BlockHeader header;
        bytes proof;
    }

    modifier onlyValidSenderAndSignal(address sender, bytes32 signal) {
        require(sender != address(0), "B:sender");
        require(signal != 0, "B:signal");
        _;
    }

    /**
     * Send a signal by storing the key with a value of 1.
     *
     * @param sender The address sending the signal.
     * @param signal The signal to send.
     */
    function sendSignal(
        address sender,
        bytes32 signal
    ) internal onlyValidSenderAndSignal(sender, signal) {
        bytes32 key = _signalSlot(sender, signal);
        assembly {
            sstore(key, 1)
        }
    }

    /**
     * Check if a signal has been sent (key stored with a value of 1).
     *
     * @param sender The sender of the signal.
     * @param signal The signal to check.
     */
    function isSignalSent(
        address sender,
        bytes32 signal
    ) internal view onlyValidSenderAndSignal(sender, signal) returns (bool) {
        bytes32 key = _signalSlot(sender, signal);
        uint256 v;
        assembly {
            v := sload(key)
        }
        return v == 1;
    }

    /**
     * Check if signal has been received on the destination chain (current).
     *
     * @param resolver The address resolver.
     * @param srcBridge Address of the source bridge where the bridge
     *                  was initiated.
     * @param sender Address of the sender of the signal
     *               (also should be srcBridge).
     * @param signal The signal to check.
     * @param proof The proof of the signal being sent on the source chain.
     */
    function isSignalReceived(
        AddressResolver resolver,
        address srcBridge,
        address sender,
        bytes32 signal,
        bytes calldata proof
    ) internal view onlyValidSenderAndSignal(sender, signal) returns (bool) {
        require(srcBridge != address(0), "B:srcBridge");

        SignalProof memory sp = abi.decode(proof, (SignalProof));
        LibTrieProof.verify({
            stateRoot: sp.header.stateRoot,
            addr: srcBridge,
            key: _signalSlot(sender, signal),
            value: bytes32(uint256(1)),
            mkproof: sp.proof
        });
        // get synced header hash of the header height specified in the proof
        bytes32 syncedHeaderHash = IHeaderSync(resolver.resolve("taiko"))
            .getSyncedHeader(sp.header.height);
        // check header hash specified in the proof matches the current chain
        return
            syncedHeaderHash != 0 &&
            syncedHeaderHash == sp.header.hashBlockHeader();
    }

    /**
     * Check if signal has been received on the destination chain (current).
     *
     * @param resolver The address resolver.
     * @param destBridge Address of the destination bridge where the bridge
     *                  was initiated.
     * @param sender Address of the sender of the signal
     *               (also should be destBridge).
     * @param signal The signal to check.
     * @param proof The proof of the signal being sent on the source chain.
     */
    function verifySignalStatus(
        AddressResolver resolver,
        address destBridge,
        address sender,
        bytes32 signal,
        LibBridgeStatus.MessageStatus status,
        bytes calldata proof
    ) internal view returns (bool) {
        require(destBridge != address(0), "B:srcBridge");

        StatusProof memory sp = abi.decode(proof, (StatusProof));
        LibTrieProof.verify({
            stateRoot: sp.header.stateRoot,
            addr: destBridge,
            key: _signalSlot(sender, signal),
            value: bytes32(uint256(status)),
            mkproof: sp.proof
        });
        // get synced header hash of the header height specified in the proof
        bytes32 syncedHeaderHash = IHeaderSync(resolver.resolve("taiko"))
            .getSyncedHeader(sp.header.height);
        // check header hash specified in the proof matches the current chain
        return
            syncedHeaderHash != 0 &&
            syncedHeaderHash == sp.header.hashBlockHeader();
    }

    /**
     * Generate the storage key for a signal.
     */
    function _signalSlot(
        address sender,
        bytes32 signal
    ) private pure returns (bytes32) {
        return keccak256(abi.encodePacked("signal", sender, signal));
    }
}
