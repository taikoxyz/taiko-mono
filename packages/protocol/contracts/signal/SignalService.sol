// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import "../common/EssentialContract.sol";
import "../common/IHeaderSync.sol";
import "../libs/LibBlockHeader.sol";
import "../libs/LibTrieProof.sol";
import "./ISignalService.sol";

contract SignalService is ISignalService, EssentialContract {
    using LibBlockHeader for BlockHeader;

    struct SignalProof {
        BlockHeader header;
        bytes proof;
    }

    /// @dev Initializer to be called after being deployed behind a proxy.
    function init(address _addressManager) external initializer {
        EssentialContract._init(_addressManager);
    }

    function sendSignal(bytes32 signal) public returns (bytes32 storageSlot) {
        require(signal != 0, "B:signal");

        storageSlot = getSignalSlot(msg.sender, signal);
        assembly {
            sstore(storageSlot, 1)
        }
    }

    function isSignalSent(
        address app,
        bytes32 signal
    ) public view returns (bool) {
        require(app != address(0), "B:app");
        require(signal != 0, "B:signal");

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
    ) public view returns (bool) {
        require(srcChainId != block.chainid, "B:srcChainId");
        require(app != address(0), "B:app");
        require(signal != 0, "B:signal");

        SignalProof memory sp = abi.decode(proof, (SignalProof));
        // Resolve the TaikoL1 or TaikoL2 contract if on Ethereum or Taiko.
        bytes32 syncedHeaderHash = IHeaderSync(resolve("taiko", false))
            .getSyncedHeader(sp.header.height);

        return
            syncedHeaderHash != 0 &&
            syncedHeaderHash == sp.header.hashBlockHeader() &&
            LibTrieProof.verify({
                stateRoot: sp.header.stateRoot,
                addr: resolve(srcChainId, "signal_service", false),
                slot: getSignalSlot(app, signal),
                value: bytes32(uint256(1)),
                mkproof: sp.proof
            });
    }

    /**
     * @param app The srcAddress of the app (eg. the Bridge).
     * @param signal The signal to store.
     * @return signalSlot The storage key for the signal on the signal service.
     */
    function getSignalSlot(
        address app,
        bytes32 signal
    ) public pure returns (bytes32 signalSlot) {
        assembly {
            // Load the free memory pointer and allocate memory for the concatenated arguments
            let input := mload(0x40)

            // Store the app address and signal bytes32 value in the allocated memory
            mstore(input, app)
            mstore(add(input, 0x20), signal)

            // Calculate the hash of the concatenated arguments using keccak256
            signalSlot := keccak256(input, 0x40)

            // Free the memory allocated for the input
            mstore(0x40, add(input, 0x60))
        }
    }
}
