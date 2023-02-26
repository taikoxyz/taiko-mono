// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import {EssentialContract} from "../common/EssentialContract.sol";
import {IHeaderSync} from "../common/IHeaderSync.sol";
import {LibBlockHeader, BlockHeader} from "../libs/LibBlockHeader.sol";
import {LibTrieProof} from "../libs/LibTrieProof.sol";
import {ISignalService} from "./ISignalService.sol";

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
            .getSyncData(sp.header.height)
            .blockHash;

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

    function getStorageRoot() public view returns (bytes32 root) {
        assembly {
            root := sload(0)
        }
    }

    /**
     * @param app The srcAddress of the app (eg. the Bridge).
     * @param signal The signal to store.
     * @return signalSlot The storage key for the signal on the signal service.
     */
    function getSignalSlot(
        address app,
        bytes32 signal
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(app, signal));
    }
}
