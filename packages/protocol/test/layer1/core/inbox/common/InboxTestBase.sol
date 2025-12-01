// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { CommonTest } from "test/shared/CommonTest.sol";
import { Vm } from "forge-std/src/Vm.sol";
import { Inbox } from "src/layer1/core/impl/Inbox.sol";
import { InboxOptimized } from "src/layer1/core/impl/InboxOptimized.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { CodecOptimized } from "src/layer1/core/impl/CodecOptimized.sol";
import { LibBlobs } from "src/layer1/core/libs/LibBlobs.sol";
import { LibHashOptimized } from "src/layer1/core/libs/LibHashOptimized.sol";
import { LibHashSimple } from "src/layer1/core/libs/LibHashSimple.sol";
import { LibProposeInputDecoder } from "src/layer1/core/libs/LibProposeInputDecoder.sol";
import { LibProposedEventEncoder } from "src/layer1/core/libs/LibProposedEventEncoder.sol";
import { LibProveInputDecoder } from "src/layer1/core/libs/LibProveInputDecoder.sol";
import { LibProvedEventEncoder } from "src/layer1/core/libs/LibProvedEventEncoder.sol";
import { MockCheckpointStore, MockERC20, MockProofVerifier } from "../mocks/MockContracts.sol";
import { MockProposerChecker } from "../mocks/MockProposerChecker.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

enum InboxVariant {
    Simple,
    Optimized
}

/// @title InboxTestBase
/// @notice Shared setup and helpers for Inbox tests with minimal duplication between variants.
abstract contract InboxTestBase is CommonTest {
    InboxVariant internal variant;
    Inbox internal inbox;
    IInbox.Config internal config;

    MockERC20 internal token;
    MockProofVerifier internal verifier;
    MockCheckpointStore internal checkpointStore;
    MockProposerChecker internal proposerChecker;

    address internal proposer = Bob;
    address internal prover = Carol;

    constructor(InboxVariant _variant) {
        variant = _variant;
    }

    function setUp() public virtual override {
        vm.deal(address(this), 100 ether);
        vm.deal(proposer, 100 ether);
        vm.deal(prover, 100 ether);

        token = new MockERC20();
        verifier = new MockProofVerifier();
        checkpointStore = new MockCheckpointStore();
        proposerChecker = new MockProposerChecker();

        config = _buildConfig();
        inbox = _deployInbox();
        inbox.activate(bytes32(uint256(1)));

        vm.roll(100);
        vm.warp(1_000);
    }

    function _buildConfig() internal virtual returns (IInbox.Config memory) {
        return IInbox.Config({
            bondToken: address(token),
            codec: address(new CodecOptimized()), // preserved for compatibility
            checkpointStore: address(checkpointStore),
            proofVerifier: address(verifier),
            proposerChecker: address(proposerChecker),
            provingWindow: 2 hours,
            extendedProvingWindow: 4 hours,
            ringBufferSize: 100,
            basefeeSharingPctg: 0,
            minForcedInclusionCount: 1,
            forcedInclusionDelay: 384,
            forcedInclusionFeeInGwei: 10_000_000,
            forcedInclusionFeeDoubleThreshold: 50,
            minCheckpointDelay: 0,
            permissionlessInclusionMultiplier: 5
        });
    }

    // ---------------------------------------------------------------
    // Hooks
    // ---------------------------------------------------------------

    function _deployInbox() internal virtual returns (Inbox) {
        address impl = _isOptimized() ? address(new InboxOptimized(config)) : address(new Inbox(config));
        return _deployProxy(impl);
    }

    function _encodeProposeInput(IInbox.ProposeInput memory _input)
        internal
        view
        virtual
        returns (bytes memory)
    {
        return _isOptimized() ? LibProposeInputDecoder.encode(_input) : abi.encode(_input);
    }

    function _encodeProveInput(IInbox.ProveInput memory _input)
        internal
        view
        virtual
        returns (bytes memory)
    {
        return _isOptimized() ? LibProveInputDecoder.encode(_input) : abi.encode(_input);
    }

    function _encodeProveInputExternal(IInbox.ProveInput memory _input)
        public
        pure
        returns (bytes memory)
    {
        return LibProveInputDecoder.encode(_input);
    }

    function _encodeProposedEvent(IInbox.ProposedEventPayload memory _payload)
        internal
        view
        virtual
        returns (bytes memory)
    {
        return _isOptimized() ? LibProposedEventEncoder.encode(_payload) : abi.encode(_payload);
    }

    function _encodeProvedEvent(IInbox.ProvedEventPayload memory _payload)
        internal
        view
        virtual
        returns (bytes memory)
    {
        return _isOptimized() ? LibProvedEventEncoder.encode(_payload) : abi.encode(_payload);
    }

    function _decodeProposedEvent(bytes memory _data)
        internal
        view
        virtual
        returns (IInbox.ProposedEventPayload memory)
    {
        return _isOptimized() ? LibProposedEventEncoder.decode(_data) : abi.decode(_data, (IInbox.ProposedEventPayload));
    }

    function _decodeProvedEvent(bytes memory _data)
        internal
        view
        virtual
        returns (IInbox.ProvedEventPayload memory)
    {
        return _isOptimized() ? LibProvedEventEncoder.decode(_data) : abi.decode(_data, (IInbox.ProvedEventPayload));
    }

    function _hashProposal(IInbox.Proposal memory _proposal)
        internal
        view
        virtual
        returns (bytes32)
    {
        return _isOptimized() ? LibHashOptimized.hashProposal(_proposal) : LibHashSimple.hashProposal(_proposal);
    }

    function _hashTransition(IInbox.Transition memory _transition)
        internal
        view
        virtual
        returns (bytes32)
    {
        return _isOptimized()
            ? LibHashOptimized.hashTransition(_transition)
            : LibHashSimple.hashTransition(_transition);
    }

    function _hashCoreState(IInbox.CoreState memory _state)
        internal
        view
        virtual
        returns (bytes32)
    {
        return _isOptimized() ? LibHashOptimized.hashCoreState(_state) : LibHashSimple.hashCoreState(_state);
    }

    function _hashDerivation(IInbox.Derivation memory _derivation)
        internal
        view
        virtual
        returns (bytes32)
    {
        return _isOptimized() ? LibHashOptimized.hashDerivation(_derivation) : LibHashSimple.hashDerivation(_derivation);
    }

    function _isOptimized() internal view virtual returns (bool) {
        return variant == InboxVariant.Optimized;
    }

    // ---------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------

    function _deployProxy(address _impl) internal returns (Inbox) {
        return Inbox(address(new ERC1967Proxy(_impl, abi.encodeCall(Inbox.init, (address(this))))));
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

    function _defaultProposeInput() internal pure returns (IInbox.ProposeInput memory input_) {
        input_.deadline = 0;
        input_.blobReference = LibBlobs.BlobReference({ blobStartIndex: 0, numBlobs: 1, offset: 0 });
        input_.numForcedInclusions = 0;
    }

    function _proposeAndDecode(IInbox.ProposeInput memory _input)
        internal
        returns (IInbox.ProposedEventPayload memory payload_)
    {
        vm.recordLogs();
        vm.prank(proposer);
        inbox.propose(bytes(""), _encodeProposeInput(_input));
        payload_ = _readProposedEvent();
    }

    function _proposeAndDecodeWithGas(IInbox.ProposeInput memory _input, string memory _benchName)
        internal
        returns (IInbox.ProposedEventPayload memory payload_)
    {
        vm.recordLogs();
        vm.prank(proposer);
        vm.startSnapshotGas("shasta-propose", _benchLabel(_benchName));
        inbox.propose(bytes(""), _encodeProposeInput(_input));
        vm.stopSnapshotGas();
        payload_ = _readProposedEvent();
    }

    function _readProposedEvent() private returns (IInbox.ProposedEventPayload memory payload_) {
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 proposedTopic = keccak256("Proposed(bytes)");
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].topics.length != 0 && logs[i].topics[0] == proposedTopic) {
                bytes memory payload = abi.decode(logs[i].data, (bytes));
                return _decodeProposedEvent(payload);
            }
        }
        revert("Proposed event not found");
    }

    // ---------------------------------------------------------------------
    // Array helpers (reusable across suites)
    // ---------------------------------------------------------------------

    function _proposals(IInbox.Proposal memory _p1)
        internal
        pure
        returns (IInbox.Proposal[] memory proposals_)
    {
        proposals_ = new IInbox.Proposal[](1);
        proposals_[0] = _p1;
    }

    function _proposals(IInbox.Proposal memory _p1, IInbox.Proposal memory _p2)
        internal
        pure
        returns (IInbox.Proposal[] memory proposals_)
    {
        proposals_ = new IInbox.Proposal[](2);
        proposals_[0] = _p1;
        proposals_[1] = _p2;
    }

    function _proposals(
        IInbox.Proposal memory _p1,
        IInbox.Proposal memory _p2,
        IInbox.Proposal memory _p3
    )
        internal
        pure
        returns (IInbox.Proposal[] memory proposals_)
    {
        proposals_ = new IInbox.Proposal[](3);
        proposals_[0] = _p1;
        proposals_[1] = _p2;
        proposals_[2] = _p3;
    }

    function _proposals(
        IInbox.Proposal memory _p1,
        IInbox.Proposal memory _p2,
        IInbox.Proposal memory _p3,
        IInbox.Proposal memory _p4,
        IInbox.Proposal memory _p5
    )
        internal
        pure
        returns (IInbox.Proposal[] memory proposals_)
    {
        proposals_ = new IInbox.Proposal[](5);
        proposals_[0] = _p1;
        proposals_[1] = _p2;
        proposals_[2] = _p3;
        proposals_[3] = _p4;
        proposals_[4] = _p5;
    }

    function _transitions(IInbox.Transition memory _t1)
        internal
        pure
        returns (IInbox.Transition[] memory transitions_)
    {
        transitions_ = new IInbox.Transition[](1);
        transitions_[0] = _t1;
    }

    function _transitions(IInbox.Transition memory _t1, IInbox.Transition memory _t2)
        internal
        pure
        returns (IInbox.Transition[] memory transitions_)
    {
        transitions_ = new IInbox.Transition[](2);
        transitions_[0] = _t1;
        transitions_[1] = _t2;
    }

    function _transitions(
        IInbox.Transition memory _t1,
        IInbox.Transition memory _t2,
        IInbox.Transition memory _t3
    )
        internal
        pure
        returns (IInbox.Transition[] memory transitions_)
    {
        transitions_ = new IInbox.Transition[](3);
        transitions_[0] = _t1;
        transitions_[1] = _t2;
        transitions_[2] = _t3;
    }

    function _transitions(
        IInbox.Transition memory _t1,
        IInbox.Transition memory _t2,
        IInbox.Transition memory _t3,
        IInbox.Transition memory _t4,
        IInbox.Transition memory _t5
    )
        internal
        pure
        returns (IInbox.Transition[] memory transitions_)
    {
        transitions_ = new IInbox.Transition[](5);
        transitions_[0] = _t1;
        transitions_[1] = _t2;
        transitions_[2] = _t3;
        transitions_[3] = _t4;
        transitions_[4] = _t5;
    }

    function _metadata(address _d1, address _a1)
        internal
        pure
        returns (IInbox.TransitionMetadata[] memory metadata_)
    {
        metadata_ = new IInbox.TransitionMetadata[](1);
        metadata_[0] =
            IInbox.TransitionMetadata({ designatedProver: _d1, actualProver: _a1 });
    }

    function _metadata(
        address _d1,
        address _a1,
        address _d2,
        address _a2
    )
        internal
        pure
        returns (IInbox.TransitionMetadata[] memory metadata_)
    {
        metadata_ = new IInbox.TransitionMetadata[](2);
        metadata_[0] =
            IInbox.TransitionMetadata({ designatedProver: _d1, actualProver: _a1 });
        metadata_[1] =
            IInbox.TransitionMetadata({ designatedProver: _d2, actualProver: _a2 });
    }

    function _metadata(
        address _d1,
        address _a1,
        address _d2,
        address _a2,
        address _d3,
        address _a3
    )
        internal
        pure
        returns (IInbox.TransitionMetadata[] memory metadata_)
    {
        metadata_ = new IInbox.TransitionMetadata[](3);
        metadata_[0] =
            IInbox.TransitionMetadata({ designatedProver: _d1, actualProver: _a1 });
        metadata_[1] =
            IInbox.TransitionMetadata({ designatedProver: _d2, actualProver: _a2 });
        metadata_[2] =
            IInbox.TransitionMetadata({ designatedProver: _d3, actualProver: _a3 });
    }

    function _metadata(
        address _d1,
        address _a1,
        address _d2,
        address _a2,
        address _d3,
        address _a3,
        address _d4,
        address _a4,
        address _d5,
        address _a5
    )
        internal
        pure
        returns (IInbox.TransitionMetadata[] memory metadata_)
    {
        metadata_ = new IInbox.TransitionMetadata[](5);
        metadata_[0] =
            IInbox.TransitionMetadata({ designatedProver: _d1, actualProver: _a1 });
        metadata_[1] =
            IInbox.TransitionMetadata({ designatedProver: _d2, actualProver: _a2 });
        metadata_[2] =
            IInbox.TransitionMetadata({ designatedProver: _d3, actualProver: _a3 });
        metadata_[3] =
            IInbox.TransitionMetadata({ designatedProver: _d4, actualProver: _a4 });
        metadata_[4] =
            IInbox.TransitionMetadata({ designatedProver: _d5, actualProver: _a5 });
    }

    function _benchLabel(string memory _base) internal view returns (string memory) {
        return string.concat(_base, _isOptimized() ? "_InboxOptimized" : "_Inbox");
    }
}
