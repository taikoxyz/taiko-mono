// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { MockSurgeVerifier } from "./mocks/MockSurgeVerifier.sol";
import { MockSignalService } from "test/layer1/core/inbox/mocks/MockContracts.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Vm } from "forge-std/src/Vm.sol";
import { IRealTimeInbox } from "src/layer1/core/iface/IRealTimeInbox.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";
import { RealTimeInbox } from "src/layer1/core/impl/RealTimeInbox.sol";
import { LibBlobs } from "src/layer1/core/libs/LibBlobs.sol";
import { CommonTest } from "test/shared/CommonTest.sol";

/// @title RealTimeInboxTestBase
/// @notice Shared setup and helpers for RealTimeInbox tests.
abstract contract RealTimeInboxTestBase is CommonTest {
    RealTimeInbox internal inbox;
    IRealTimeInbox.Config internal config;

    MockSurgeVerifier internal verifier;
    MockSignalService internal signalService;

    address internal proposer = Bob;

    uint48 internal constant INITIAL_BLOCK_NUMBER = 100;
    uint48 internal constant INITIAL_BLOCK_TIMESTAMP = 1000;

    function setUp() public virtual override {
        super.setUp();
        vm.deal(address(this), 100 ether);
        vm.deal(proposer, 100 ether);

        verifier = new MockSurgeVerifier();
        signalService = new MockSignalService();

        config = IRealTimeInbox.Config({
            proofVerifier: address(verifier),
            signalService: address(signalService),
            basefeeSharingPctg: 0
        });

        inbox = _deployInbox(config);
        inbox.activate(bytes32(uint256(1)));

        vm.roll(INITIAL_BLOCK_NUMBER);
        vm.warp(INITIAL_BLOCK_TIMESTAMP);
    }

    // ---------------------------------------------------------------
    // Deploy helpers
    // ---------------------------------------------------------------

    function _deployInbox(IRealTimeInbox.Config memory _config) internal returns (RealTimeInbox) {
        address impl = address(new RealTimeInbox(_config));
        return RealTimeInbox(
            address(
                new ERC1967Proxy(impl, abi.encodeCall(RealTimeInbox.init, (address(this))))
            )
        );
    }

    function _deployNonActivatedInbox() internal returns (RealTimeInbox) {
        return _deployInbox(config);
    }

    // ---------------------------------------------------------------
    // Block helpers
    // ---------------------------------------------------------------

    function _advanceBlock() internal {
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 1);
    }

    function _setBlobHashes(uint256 _count) internal {
        vm.blobhashes(_getBlobHashes(_count));
    }

    function _getBlobHashes(uint256 _count) internal pure returns (bytes32[] memory hashes_) {
        hashes_ = new bytes32[](_count);
        for (uint256 i; i < _count; ++i) {
            hashes_[i] = keccak256(abi.encode("blob", i));
        }
    }

    // ---------------------------------------------------------------
    // Propose helpers
    // ---------------------------------------------------------------

    function _buildDefaultProposeInput()
        internal
        view
        returns (IRealTimeInbox.ProposeInput memory input_)
    {
        input_ = IRealTimeInbox.ProposeInput({
            blobReference: LibBlobs.BlobReference({ blobStartIndex: 0, numBlobs: 1, offset: 0 }),
            signalSlots: new bytes32[](0),
            maxAnchorBlockNumber: uint48(block.number - 1)
        });
    }

    function _buildCheckpoint() internal pure returns (ICheckpointStore.Checkpoint memory) {
        return ICheckpointStore.Checkpoint({
            blockNumber: 1,
            blockHash: keccak256("checkpoint-block-hash"),
            stateRoot: keccak256("checkpoint-state-root")
        });
    }

    function _buildCheckpoint(
        uint48 _blockNumber,
        bytes32 _blockHash,
        bytes32 _stateRoot
    )
        internal
        pure
        returns (ICheckpointStore.Checkpoint memory)
    {
        return ICheckpointStore.Checkpoint({
            blockNumber: _blockNumber,
            blockHash: _blockHash,
            stateRoot: _stateRoot
        });
    }

    /// @dev Encodes a ProposeInput, calls propose, and returns the recorded logs.
    function _proposeAndGetLogs(
        IRealTimeInbox.ProposeInput memory _input,
        ICheckpointStore.Checkpoint memory _checkpoint
    )
        internal
        returns (Vm.Log[] memory logs_)
    {
        bytes memory data = abi.encode(_input);
        _setBlobHashes(_input.blobReference.numBlobs);

        vm.recordLogs();
        vm.prank(proposer);
        inbox.propose(data, _checkpoint, bytes(""));
        logs_ = vm.getRecordedLogs();
    }
}
