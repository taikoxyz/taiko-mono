// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.9;

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

    error ErrZeroSignal();
    error ErrNullApp();
    error ErrIdenticalSourceChain();

    /// @dev Initializer to be called after being deployed behind a proxy.
    function init(address _addressManager) external initializer {
        EssentialContract._init(_addressManager);
    }

    function sendSignal(bytes32 signal) public returns (bytes32 storageSlot) {
        if (signal == 0) {
            revert ErrZeroSignal();
        }

        storageSlot = getSignalSlot(msg.sender, signal);
        assembly {
            sstore(storageSlot, 1)
        }
    }

    function isSignalSent(
        address app,
        bytes32 signal
    ) public view returns (bool) {
        if (app == address(0)) revert ErrNullApp();
        if (signal == 0) revert ErrZeroSignal();

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
        if (srcChainId == block.chainid) revert ErrIdenticalSourceChain();
        if (app == address(0)) revert ErrNullApp();
        if (signal == 0) revert ErrZeroSignal();

        SignalProof memory sp = abi.decode(proof, (SignalProof));
        bytes32 syncedHeaderHash = IHeaderSync(resolve("taiko", false))
            .getSyncedHeader(sp.header.height);

        if (
            syncedHeaderHash == 0 ||
            syncedHeaderHash != sp.header.hashBlockHeader()
        ) {
            return false;
        }

        return
            LibTrieProof.verify({
                stateRoot: sp.header.stateRoot,
                addr: resolve(srcChainId, "signal_service", false),
                slot: getSignalSlot(app, signal),
                value: bytes32(uint256(1)),
                mkproof: sp.proof
            });
    }

    function getSignalSlot(
        address app,
        bytes32 signal
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(app, signal));
    }
}
