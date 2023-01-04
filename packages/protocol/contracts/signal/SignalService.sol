// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
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

    /// @dev Initializer to be called after being deployed behind a proxy.
    function init(address _addressManager) external initializer {
        EssentialContract._init(_addressManager);
    }

    function sendSignal(address user, bytes32 signal) public {
        require(signal != 0, "B:signal");

        bytes32 k = getSignalSlot(msg.sender, user, signal);
        assembly {
            sstore(k, 1)
        }
    }

    function isSignalSent(
        address app,
        address user,
        bytes32 signal
    ) public view returns (bool) {
        require(app != address(0), "B:app");
        require(signal != 0, "B:signal");

        bytes32 k = getSignalSlot(app, user, signal);
        uint256 v;
        assembly {
            v := sload(k)
        }
        return v == 1;
    }

    function isSignalReceived(
        address app,
        address user,
        bytes32 signal,
        bytes calldata proof
    ) public view returns (bool) {
        require(app != address(0), "B:app");
        require(signal != 0, "B:signal");

        SignalProof memory sp = abi.decode(proof, (SignalProof));
        LibTrieProof.verify({
            stateRoot: sp.header.stateRoot,
            addr: app,
            key: getSignalSlot(app, user, signal),
            value: bytes32(uint256(1)),
            mkproof: sp.proof
        });
        // get synced header hash of the header height specified in the proof
        bytes32 syncedHeaderHash = IHeaderSync(resolve("taiko"))
            .getSyncedHeader(sp.header.height);

        // check header hash specified in the proof matches the current chain
        return
            syncedHeaderHash != 0 &&
            syncedHeaderHash == sp.header.hashBlockHeader();
    }

    function getSignalSlot(
        address app,
        address user,
        bytes32 signal
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(app, user, signal));
    }
}
