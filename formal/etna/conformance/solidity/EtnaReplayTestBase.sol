// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {EtnaLandTestBase} from "../EtnaLandTestBase.sol";
import {IEtnaInbox} from "src/layer1/etna/iface/IEtnaInbox.sol";
import {ICheckpointStore} from "src/shared/signal/ICheckpointStore.sol";

/// @notice Observes successful publication independently of the Inbox's checkpoint getter.
abstract contract EtnaReplayTestBase is EtnaLandTestBase {
    /// @dev Expected values come from the original mapped call, never post-call Inbox state.
    /// The concrete state root is an adapter/proof premise; the abstract receipts do not export it.
    /// @param _input Original input accepted by the actual land call.
    function _assertSuccessfulPublication(IEtnaInbox.LandInput memory _input) internal view {
        (bool exists, bytes memory encoded) = address(signalService)
            .staticcall(abi.encodeCall(ICheckpointStore.getCheckpoint, (uint48(_input.lastHeight))));
        assertTrue(exists, "publication: SignalService missing");
        ICheckpointStore.Checkpoint memory checkpoint = abi.decode(encoded, (ICheckpointStore.Checkpoint));
        assertEq(checkpoint.blockNumber, _input.lastHeight, "publication: SignalService height");
        assertEq(checkpoint.blockHash, _input.lastBlockHash, "publication: SignalService block hash");
        assertEq(checkpoint.stateRoot, _input.lastStateRoot, "publication: SignalService state root");
        assertEq(
            _inbox().activeCommitteeSnapshot(), _input.activeCommitteeSnapshot, "publication: active committee snapshot"
        );
    }
}
