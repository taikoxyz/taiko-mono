// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { MockProofVerifier } from "./mocks/MockContracts.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Vm } from "forge-std/src/Vm.sol";
import { ICodec } from "src/layer1/core/iface/ICodec.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { Codec } from "src/layer1/core/impl/Codec.sol";
import { Inbox } from "src/layer1/core/impl/Inbox.sol";
import { LibBlobs } from "src/layer1/core/libs/LibBlobs.sol";
import { PreconfWhitelist } from "src/layer1/preconf/impl/PreconfWhitelist.sol";
import { SignalService } from "src/shared/signal/SignalService.sol";
import { CommonTest } from "test/shared/CommonTest.sol";

/// @title InboxTestBase
/// @notice Shared setup and helpers for Inbox tests.
abstract contract InboxTestBase is CommonTest {
    Inbox internal inbox;
    IInbox.Config internal config;
    ICodec internal codec;

    MockProofVerifier internal verifier;
    SignalService internal signalService;
    PreconfWhitelist internal proposerChecker;

    address internal proposer = Bob;
    address internal prover = Carol;

    uint48 internal constant INITIAL_BLOCK_NUMBER = 100;
    uint48 internal constant INITIAL_BLOCK_TIMESTAMP = 1000;
    address internal constant REMOTE_SIGNAL_SERVICE = address(0xdead);

    function setUp() public virtual override {
        super.setUp();
        vm.deal(address(this), 100 ether);
        vm.deal(proposer, 100 ether);
        vm.deal(prover, 100 ether);

        _setupMocks();
        _setupDependencies();

        config = _buildConfig();
        inbox = _deployInbox();
        _setSignalServiceSyncer(address(inbox));
        inbox.activate(bytes32(uint256(1)));

        vm.roll(INITIAL_BLOCK_NUMBER);
        vm.warp(INITIAL_BLOCK_TIMESTAMP);
    }

    function _buildConfig() internal virtual returns (IInbox.Config memory) {
        codec = ICodec(new Codec());

        return IInbox.Config({
            codec: address(codec),
            proofVerifier: address(verifier),
            proposerChecker: address(proposerChecker),
            signalService: address(signalService),
            provingWindow: 2 hours,
            extendedProvingWindow: 4 hours,
            ringBufferSize: 100,
            basefeeSharingPctg: 0,
            minForcedInclusionCount: 1,
            forcedInclusionDelay: 384,
            forcedInclusionFeeInGwei: 10_000_000,
            forcedInclusionFeeDoubleThreshold: 50,
            minCheckpointDelay: 60_000, // large enough for skipping checkpoints in prove benches
            permissionlessInclusionMultiplier: 5,
            minProposalsToFinalize: 1
        });
    }

    // ---------------------------------------------------------------
    // Hooks
    // ---------------------------------------------------------------

    function _deployInbox() internal virtual returns (Inbox) {
        address impl = address(new Inbox(config));
        return _deployProxy(impl);
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
        assertEq(proposerChecker.operatorCount(), 1, "proposer count (propose)");
        assertEq(
            proposerChecker.getOperatorForCurrentEpoch(), proposer, "active proposer (propose)"
        );
        proposerChecker.checkProposer(proposer, bytes(""));
        bytes memory encodedInput = codec.encodeProposeInput(_input);
        vm.recordLogs();
        vm.prank(proposer);
        inbox.propose(bytes(""), encodedInput);
        payload_ = _readProposedEvent();
    }

    function _proposeAndDecodeWithGas(
        IInbox.ProposeInput memory _input,
        string memory _benchName
    )
        internal
        returns (IInbox.ProposedEventPayload memory payload_)
    {
        bytes memory encodedInput = codec.encodeProposeInput(_input);
        vm.recordLogs();
        vm.startPrank(proposer);

        vm.startSnapshotGas("shasta-propose", _benchName);
        inbox.propose(bytes(""), encodedInput);
        vm.stopSnapshotGas();

        vm.stopPrank();
        payload_ = _readProposedEvent();
    }

    function _readProposedEvent() internal returns (IInbox.ProposedEventPayload memory payload_) {
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 proposedTopic = keccak256("Proposed(bytes)");
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].topics.length != 0 && logs[i].topics[0] == proposedTopic) {
                bytes memory payload = abi.decode(logs[i].data, (bytes));
                return codec.decodeProposedEvent(payload);
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

    function _proposals(
        IInbox.Proposal memory _p1,
        IInbox.Proposal memory _p2
    )
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

    function _transitions(
        IInbox.Transition memory _t1,
        IInbox.Transition memory _t2
    )
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

    function _setupMocks() internal virtual {
        verifier = new MockProofVerifier();
    }

    function _setupDependencies() internal virtual {
        signalService = _deploySignalService(address(this));
        proposerChecker = _deployProposerChecker();
        _addProposer(proposer);
    }

    function _deploySignalService(address _authorizedSyncer) internal returns (SignalService) {
        SignalService impl = new SignalService(_authorizedSyncer, REMOTE_SIGNAL_SERVICE);
        return SignalService(
            address(
                new ERC1967Proxy(address(impl), abi.encodeCall(SignalService.init, (address(this))))
            )
        );
    }

    function _setSignalServiceSyncer(address _authorizedSyncer) internal {
        signalService.upgradeTo(
            address(new SignalService(_authorizedSyncer, REMOTE_SIGNAL_SERVICE))
        );
    }

    function _deployProposerChecker() internal returns (PreconfWhitelist) {
        PreconfWhitelist impl = new PreconfWhitelist();
        return PreconfWhitelist(
            address(
                new ERC1967Proxy(
                    address(impl), abi.encodeCall(PreconfWhitelist.init, (address(this)))
                )
            )
        );
    }

    function _addProposer(address _proposer) internal {
        proposerChecker.addOperator(_proposer, _proposer);
    }
}
