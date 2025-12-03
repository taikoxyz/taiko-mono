// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { Vm } from "forge-std/src/Vm.sol";

import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { Codex } from "src/layer1/core/impl/Codex.sol";
import { Inbox } from "src/layer1/core/impl/Inbox.sol";
import { LibBlobs } from "src/layer1/core/libs/LibBlobs.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";
import { SignalService } from "src/shared/signal/SignalService.sol";

import { MockProofVerifier, MockProposerChecker } from "../mocks/MockContracts.sol";
import { CommonTest } from "test/shared/CommonTest.sol";

/// @title InboxTestHelper
/// @notice Base test contract with reusable helper functions for Inbox testing
/// @custom:security-contact security@taiko.xyz
abstract contract InboxTestHelper is CommonTest {
    // ---------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------

    bytes32 internal constant GENESIS_BLOCK_HASH = bytes32(uint256(1));
    address internal constant MOCK_REMOTE_SIGNAL_SERVICE = address(1);
    uint48 internal constant INITIAL_BLOCK_NUMBER = 100;
    uint48 internal constant INITIAL_TIMESTAMP = 1000;
    uint256 internal constant DEFAULT_TEST_BLOB_COUNT = 9;

    // Default config values
    uint40 internal constant DEFAULT_PROVING_WINDOW = 1 hours;
    uint40 internal constant DEFAULT_EXTENDED_PROVING_WINDOW = 2 hours;
    uint256 internal constant DEFAULT_MAX_FINALIZATION_COUNT = 10;
    uint40 internal constant DEFAULT_FINALIZATION_GRACE_PERIOD = 30 minutes;
    uint256 internal constant DEFAULT_RING_BUFFER_SIZE = 100;
    uint8 internal constant DEFAULT_BASEFEE_SHARING_PCTG = 10;
    uint256 internal constant DEFAULT_MIN_FORCED_INCLUSION_COUNT = 1;
    uint16 internal constant DEFAULT_FORCED_INCLUSION_DELAY = 300; // 5 min
    uint64 internal constant DEFAULT_FORCED_INCLUSION_FEE_IN_GWEI = 10_000_000; // 0.01 ETH
    uint64 internal constant DEFAULT_FORCED_INCLUSION_FEE_DOUBLE_THRESHOLD = 100;
    uint16 internal constant DEFAULT_MIN_SYNC_DELAY = 10;
    uint8 internal constant DEFAULT_PERMISSIONLESS_INCLUSION_MULTIPLIER = 3;

    // Event topics
    bytes32 internal constant PROPOSED_EVENT_TOPIC = keccak256("Proposed(uint40,bytes)");
    bytes32 internal constant PROVED_EVENT_TOPIC = keccak256("Proved(uint40,bytes27,bytes)");

    // ---------------------------------------------------------------
    // Structs for test results
    // ---------------------------------------------------------------

    /// @notice Represents a proposal that has been proven
    struct ProvenProposal {
        IInbox.Proposal proposal;
        IInbox.Transition transition;
        ICheckpointStore.Checkpoint checkpoint;
        bytes27 transitionHash;
        uint40 finalizationDeadline;
    }

    /// @notice Result of filling the ring buffer
    struct RingBufferFillResult {
        IInbox.ProposedEventPayload first;
        IInbox.ProposedEventPayload second;
        IInbox.ProposedEventPayload last;
        IInbox.Proposal[] proposals;
    }

    // ---------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------

    Inbox public inbox;
    Codex public codex;
    MockProofVerifier public proofVerifier;
    MockProposerChecker public proposerChecker;
    SignalService public signalService;
    ICheckpointStore public checkpointStore;

    address internal owner = Alice;
    address internal currentProposer = Bob;
    address internal currentProver = Carol;

    // Config values cached from inbox
    uint40 internal provingWindow;
    uint40 internal extendedProvingWindow;
    uint40 internal finalizationGracePeriod;
    uint16 internal minSyncDelay;
    uint256 internal maxFinalizationCount;
    uint256 internal ringBufferSize;

    // ---------------------------------------------------------------
    // Setup
    // ---------------------------------------------------------------

    function setUp() public virtual override {
        super.setUp();

        // Deploy dependencies
        _deployDependencies();

        // Deploy inbox with default config
        inbox = _deployInbox(_createDefaultConfig());

        // Upgrade signal service to use inbox as syncer and activate inbox
        vm.startPrank(owner);
        signalService.upgradeTo(
            address(new SignalService(address(inbox), MOCK_REMOTE_SIGNAL_SERVICE))
        );
        inbox.activate(GENESIS_BLOCK_HASH);
        vm.stopPrank();

        // Setup proposer
        proposerChecker.allowProposer(currentProposer);

        // Cache config values
        _cacheConfigValues();

        // Advance to safe state
        vm.roll(INITIAL_BLOCK_NUMBER);
        vm.warp(INITIAL_TIMESTAMP);
    }

    function _deployDependencies() internal {
        // Deploy codex for encoding/decoding/hashing
        codex = new Codex();

        // Deploy mock proof verifier
        proofVerifier = new MockProofVerifier();

        // Deploy mock proposer checker
        proposerChecker = new MockProposerChecker();
        proposerChecker.setSubmissionWindowEnd(0);

        // Deploy signal service
        SignalService signalServiceImpl =
            new SignalService(address(this), MOCK_REMOTE_SIGNAL_SERVICE);
        signalService = SignalService(
            address(
                new ERC1967Proxy(
                    address(signalServiceImpl), abi.encodeCall(SignalService.init, (owner))
                )
            )
        );
        checkpointStore = ICheckpointStore(address(signalService));
    }

    function _cacheConfigValues() internal {
        IInbox.Config memory config = inbox.getConfig();
        provingWindow = config.provingWindow;
        extendedProvingWindow = config.extendedProvingWindow;
        finalizationGracePeriod = config.finalizationGracePeriod;
        minSyncDelay = config.minSyncDelay;
        maxFinalizationCount = config.maxFinalizationCount;
        ringBufferSize = config.ringBufferSize;
    }

    function _createDefaultConfig() internal view returns (IInbox.Config memory) {
        return IInbox.Config({
            proofVerifier: address(proofVerifier),
            proposerChecker: address(proposerChecker),
            checkpointStore: address(checkpointStore),
            signalService: address(signalService),
            provingWindow: DEFAULT_PROVING_WINDOW,
            extendedProvingWindow: DEFAULT_EXTENDED_PROVING_WINDOW,
            maxFinalizationCount: DEFAULT_MAX_FINALIZATION_COUNT,
            finalizationGracePeriod: DEFAULT_FINALIZATION_GRACE_PERIOD,
            ringBufferSize: DEFAULT_RING_BUFFER_SIZE,
            basefeeSharingPctg: DEFAULT_BASEFEE_SHARING_PCTG,
            minForcedInclusionCount: DEFAULT_MIN_FORCED_INCLUSION_COUNT,
            forcedInclusionDelay: DEFAULT_FORCED_INCLUSION_DELAY,
            forcedInclusionFeeInGwei: DEFAULT_FORCED_INCLUSION_FEE_IN_GWEI,
            forcedInclusionFeeDoubleThreshold: DEFAULT_FORCED_INCLUSION_FEE_DOUBLE_THRESHOLD,
            minSyncDelay: DEFAULT_MIN_SYNC_DELAY,
            permissionlessInclusionMultiplier: DEFAULT_PERMISSIONLESS_INCLUSION_MULTIPLIER
        });
    }

    function _deployInbox(IInbox.Config memory _config) internal returns (Inbox) {
        Inbox impl = new Inbox(_config);
        Inbox proxy =
            Inbox(address(new ERC1967Proxy(address(impl), abi.encodeCall(Inbox.init, (owner)))));
        return proxy;
    }

    // ---------------------------------------------------------------
    // Genesis State Helpers
    // ---------------------------------------------------------------

    function _getGenesisCoreState() internal view returns (IInbox.CoreState memory) {
        IInbox.Transition memory transition;
        transition.checkpointHash = codex.hashCheckpoint(
            ICheckpointStore.Checkpoint({ blockNumber: 0, blockHash: GENESIS_BLOCK_HASH, stateRoot: 0 })
        );

        return IInbox.CoreState({
            proposalHead: 0,
            proposalHeadContainerBlock: 1,
            finalizationHead: 0,
            synchronizationHead: 0,
            finalizationHeadTransitionHash: codex.hashTransition(transition),
            aggregatedBondInstructionsHash: bytes32(0)
        });
    }

    function _getGenesisTransitionHash() internal view returns (bytes27) {
        IInbox.Transition memory transition;
        transition.checkpointHash = codex.hashCheckpoint(
            ICheckpointStore.Checkpoint({ blockNumber: 0, blockHash: GENESIS_BLOCK_HASH, stateRoot: 0 })
        );
        return codex.hashTransition(transition);
    }

    function _createGenesisProposal() internal view returns (IInbox.Proposal memory) {
        IInbox.CoreState memory coreState = _getGenesisCoreState();
        IInbox.Derivation memory derivation;

        return IInbox.Proposal({
            id: 0,
            timestamp: 0,
            endOfSubmissionWindowTimestamp: 0,
            proposer: address(0),
            coreStateHash: codex.hashCoreState(coreState),
            derivationHash: codex.hashDerivation(derivation),
            parentProposalHash: bytes32(0)
        });
    }

    // ---------------------------------------------------------------
    // Blob Helpers
    // ---------------------------------------------------------------

    function _setupBlobHashes() internal {
        _setupBlobHashes(DEFAULT_TEST_BLOB_COUNT);
    }

    function _setupBlobHashes(uint256 _numBlobs) internal {
        vm.blobhashes(_getBlobHashesForTest(_numBlobs));
    }

    function _getBlobHashesForTest(uint256 _numBlobs) internal pure returns (bytes32[] memory) {
        bytes32[] memory hashes = new bytes32[](_numBlobs);
        for (uint256 i = 0; i < _numBlobs; i++) {
            hashes[i] = keccak256(abi.encode("blob", i));
        }
        return hashes;
    }

    function _createBlobRef(
        uint8 _blobStartIndex,
        uint8 _numBlobs,
        uint24 _offset
    )
        internal
        pure
        returns (LibBlobs.BlobReference memory)
    {
        return LibBlobs.BlobReference({
            blobStartIndex: _blobStartIndex, numBlobs: _numBlobs, offset: _offset
        });
    }

    // ---------------------------------------------------------------
    // ProposeInput Builders
    // ---------------------------------------------------------------

    function _createFirstProposeInput() internal view returns (IInbox.ProposeInput memory) {
        IInbox.CoreState memory coreState = _getGenesisCoreState();
        IInbox.Proposal[] memory headProposalAndProof = new IInbox.Proposal[](1);
        headProposalAndProof[0] = _createGenesisProposal();

        return IInbox.ProposeInput({
            deadline: 0,
            coreState: coreState,
            headProposalAndProof: headProposalAndProof,
            blobReference: _createBlobRef(0, 1, 0),
            transitions: new IInbox.Transition[](0),
            checkpoint: ICheckpointStore.Checkpoint({ blockNumber: 0, blockHash: 0, stateRoot: 0 }),
            numForcedInclusions: 0
        });
    }

    function _createProposeInputWithDeadline(uint40 _deadline)
        internal
        view
        returns (IInbox.ProposeInput memory)
    {
        IInbox.ProposeInput memory input = _createFirstProposeInput();
        input.deadline = _deadline;
        return input;
    }

    function _createProposeInputWithBlobs(
        uint8 _numBlobs,
        uint24 _offset
    )
        internal
        view
        returns (IInbox.ProposeInput memory)
    {
        IInbox.ProposeInput memory input = _createFirstProposeInput();
        input.blobReference = _createBlobRef(0, _numBlobs, _offset);
        return input;
    }

    function _createConsecutiveProposeInput(
        IInbox.Proposal memory _parentProposal,
        IInbox.CoreState memory _parentCoreState
    )
        internal
        pure
        returns (IInbox.ProposeInput memory)
    {
        IInbox.Proposal[] memory headProposalAndProof = new IInbox.Proposal[](1);
        headProposalAndProof[0] = _parentProposal;

        return IInbox.ProposeInput({
            deadline: 0,
            coreState: _parentCoreState,
            headProposalAndProof: headProposalAndProof,
            blobReference: _createBlobRef(0, 1, 0),
            transitions: new IInbox.Transition[](0),
            checkpoint: ICheckpointStore.Checkpoint({ blockNumber: 0, blockHash: 0, stateRoot: 0 }),
            numForcedInclusions: 0
        });
    }

    function _createProposeInputWithCustomParams(
        uint40 _deadline,
        LibBlobs.BlobReference memory _blobRef,
        IInbox.Proposal[] memory _headProposalAndProof,
        IInbox.CoreState memory _coreState
    )
        internal
        pure
        returns (IInbox.ProposeInput memory)
    {
        return IInbox.ProposeInput({
            deadline: _deadline,
            coreState: _coreState,
            headProposalAndProof: _headProposalAndProof,
            blobReference: _blobRef,
            transitions: new IInbox.Transition[](0),
            checkpoint: ICheckpointStore.Checkpoint({ blockNumber: 0, blockHash: 0, stateRoot: 0 }),
            numForcedInclusions: 0
        });
    }

    function _buildFinalizeInput(
        IInbox.CoreState memory _coreState,
        IInbox.Proposal[] memory _headProposalAndProof,
        IInbox.Transition[] memory _transitions,
        ICheckpointStore.Checkpoint memory _checkpoint
    )
        internal
        pure
        returns (IInbox.ProposeInput memory)
    {
        return IInbox.ProposeInput({
            deadline: 0,
            coreState: _coreState,
            headProposalAndProof: _headProposalAndProof,
            blobReference: _createBlobRef(0, 1, 0),
            transitions: _transitions,
            checkpoint: _checkpoint,
            numForcedInclusions: 0
        });
    }

    // ---------------------------------------------------------------
    // ProveInput Builders
    // ---------------------------------------------------------------

    function _createProveInput(
        IInbox.Proposal memory _proposal,
        bytes27 _parentTransitionHash
    )
        internal
        view
        returns (IInbox.ProveInput[] memory)
    {
        IInbox.ProveInput[] memory inputs = new IInbox.ProveInput[](1);
        inputs[0] = IInbox.ProveInput({
            proposal: _proposal,
            checkpoint: ICheckpointStore.Checkpoint({
                blockNumber: uint40(block.number),
                blockHash: blockhash(block.number - 1),
                stateRoot: bytes32(uint256(200))
            }),
            metadata: IInbox.TransitionMetadata({
                designatedProver: currentProver, actualProver: currentProver
            }),
            parentTransitionHash: _parentTransitionHash
        });
        return inputs;
    }

    function _createProveInputWithMetadata(
        IInbox.Proposal memory _proposal,
        bytes27 _parentTransitionHash,
        address _designatedProver,
        address _actualProver
    )
        internal
        view
        returns (IInbox.ProveInput[] memory)
    {
        IInbox.ProveInput[] memory inputs = new IInbox.ProveInput[](1);
        inputs[0] = IInbox.ProveInput({
            proposal: _proposal,
            checkpoint: ICheckpointStore.Checkpoint({
                blockNumber: uint40(block.number),
                blockHash: blockhash(block.number - 1),
                stateRoot: bytes32(uint256(200))
            }),
            metadata: IInbox.TransitionMetadata({
                designatedProver: _designatedProver, actualProver: _actualProver
            }),
            parentTransitionHash: _parentTransitionHash
        });
        return inputs;
    }

    function _createProveInputForMultipleProposals(
        IInbox.Proposal[] memory _proposals,
        bytes27 _startingParentHash,
        bool _consecutive
    )
        internal
        view
        returns (IInbox.ProveInput[] memory)
    {
        IInbox.ProveInput[] memory inputs = new IInbox.ProveInput[](_proposals.length);
        bytes27 parentHash = _startingParentHash;

        for (uint256 i = 0; i < _proposals.length; i++) {
            ICheckpointStore.Checkpoint memory checkpoint = ICheckpointStore.Checkpoint({
                blockNumber: uint40(block.number + i),
                blockHash: blockhash(block.number - 1),
                stateRoot: bytes32(uint256(200 + i))
            });

            inputs[i] = IInbox.ProveInput({
                proposal: _proposals[i],
                checkpoint: checkpoint,
                metadata: IInbox.TransitionMetadata({
                    designatedProver: currentProver, actualProver: currentProver
                }),
                parentTransitionHash: parentHash
            });

            if (_consecutive) {
                // Chain transitions for consecutive proposals
                IInbox.Transition memory transition = IInbox.Transition({
                    bondInstructionHash: bytes32(0),
                    checkpointHash: codex.hashCheckpoint(checkpoint)
                });
                parentHash = codex.hashTransition(transition);
            }
        }

        return inputs;
    }

    function _createValidProof() internal pure returns (bytes memory) {
        return abi.encode("valid_proof");
    }

    // ---------------------------------------------------------------
    // Propose and Get Result Helpers
    // ---------------------------------------------------------------

    function _proposeAndGetPayload() internal returns (IInbox.ProposedEventPayload memory) {
        _setupBlobHashes();
        if (block.number < 2) {
            vm.roll(2);
        }

        bytes memory proposeData = codex.encodeProposeInput(_createFirstProposeInput());

        vm.recordLogs();
        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData);

        return _decodeLastProposedEvent();
    }

    function _proposeConsecutive(IInbox.ProposedEventPayload memory _prevPayload)
        internal
        returns (IInbox.ProposedEventPayload memory)
    {
        _setupBlobHashes();
        vm.roll(block.number + 1);

        IInbox.ProposeInput memory input =
            _createConsecutiveProposeInput(_prevPayload.proposal, _prevPayload.coreState);
        bytes memory proposeData = codex.encodeProposeInput(input);

        vm.recordLogs();
        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData);

        return _decodeLastProposedEvent();
    }

    function _proposeConsecutiveWithTransitions(
        IInbox.ProposedEventPayload memory _prevPayload,
        IInbox.Transition memory _transition,
        ICheckpointStore.Checkpoint memory _checkpoint
    )
        internal
        returns (IInbox.ProposedEventPayload memory)
    {
        _setupBlobHashes();
        vm.roll(block.number + 1);

        IInbox.Transition[] memory transitions = new IInbox.Transition[](1);
        transitions[0] = _transition;

        IInbox.Proposal[] memory headProposalAndProof = new IInbox.Proposal[](1);
        headProposalAndProof[0] = _prevPayload.proposal;

        IInbox.ProposeInput memory input = IInbox.ProposeInput({
            deadline: 0,
            coreState: _prevPayload.coreState,
            headProposalAndProof: headProposalAndProof,
            blobReference: _createBlobRef(0, 1, 0),
            transitions: transitions,
            checkpoint: _checkpoint,
            numForcedInclusions: 0
        });

        bytes memory proposeData = codex.encodeProposeInput(input);

        vm.recordLogs();
        vm.prank(currentProposer);
        inbox.propose(bytes(""), proposeData);

        return _decodeLastProposedEvent();
    }

    function _createConsecutiveProposals(uint8 _count)
        internal
        returns (IInbox.ProposedEventPayload[] memory payloads)
    {
        payloads = new IInbox.ProposedEventPayload[](_count);

        for (uint256 i = 0; i < _count; i++) {
            if (i == 0) {
                payloads[i] = _proposeAndGetPayload();
            } else {
                vm.warp(block.timestamp + 12);
                payloads[i] = _proposeConsecutive(payloads[i - 1]);
            }
        }
    }

    // ---------------------------------------------------------------
    // Event Decoding Helpers
    // ---------------------------------------------------------------

    function _decodeLastProposedEvent()
        internal
        returns (IInbox.ProposedEventPayload memory payload)
    {
        Vm.Log[] memory logs = vm.getRecordedLogs();

        for (uint256 i = logs.length; i > 0; --i) {
            Vm.Log memory entry = logs[i - 1];
            if (entry.topics.length > 0 && entry.topics[0] == PROPOSED_EVENT_TOPIC) {
                bytes memory eventData = abi.decode(entry.data, (bytes));
                return codex.decodeProposedEventData(eventData);
            }
        }

        revert("Proposed event not found");
    }

    function _decodeLastProvedEvent() internal returns (IInbox.ProvedEventPayload memory payload) {
        Vm.Log[] memory logs = vm.getRecordedLogs();

        for (uint256 i = logs.length; i > 0; --i) {
            Vm.Log memory entry = logs[i - 1];
            if (entry.topics.length > 0 && entry.topics[0] == PROVED_EVENT_TOPIC) {
                bytes memory eventData = abi.decode(entry.data, (bytes));
                return codex.decodeProvedEventData(eventData);
            }
        }

        revert("Proved event not found");
    }

    function _decodeAllProvedEvents() internal returns (IInbox.ProvedEventPayload[] memory) {
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 eventCount = _countProvedEvents(logs);

        IInbox.ProvedEventPayload[] memory payloads = new IInbox.ProvedEventPayload[](eventCount);
        uint256 index;

        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics.length > 0 && logs[i].topics[0] == PROVED_EVENT_TOPIC) {
                bytes memory eventData = abi.decode(logs[i].data, (bytes));
                payloads[index++] = codex.decodeProvedEventData(eventData);
            }
        }

        return payloads;
    }

    function _countProposedEvents(Vm.Log[] memory logs) internal pure returns (uint256 count) {
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics.length > 0 && logs[i].topics[0] == PROPOSED_EVENT_TOPIC) {
                count++;
            }
        }
    }

    function _countProvedEvents(Vm.Log[] memory logs) internal pure returns (uint256 count) {
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics.length > 0 && logs[i].topics[0] == PROVED_EVENT_TOPIC) {
                count++;
            }
        }
    }

    function _hasCheckpointSavedEvent(Vm.Log[] memory logs) internal pure returns (bool) {
        bytes32 checkpointSavedTopic = keccak256("CheckpointSaved(uint40,bytes32,bytes32)");
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics.length > 0 && logs[i].topics[0] == checkpointSavedTopic) {
                return true;
            }
        }
        return false;
    }

    // ---------------------------------------------------------------
    // Prove Helpers
    // ---------------------------------------------------------------

    function _proveProposal(
        IInbox.Proposal memory _proposal,
        bytes27 _parentTransitionHash
    )
        internal
        returns (IInbox.ProvedEventPayload memory)
    {
        IInbox.ProveInput[] memory inputs = _createProveInput(_proposal, _parentTransitionHash);
        bytes memory proveData = codex.encodeProveInput(inputs);

        vm.recordLogs();
        vm.prank(currentProver);
        inbox.prove(proveData, _createValidProof());

        return _decodeLastProvedEvent();
    }

    function _proveProposalWithMetadata(
        IInbox.Proposal memory _proposal,
        bytes27 _parentTransitionHash,
        address _designatedProver,
        address _actualProver
    )
        internal
        returns (IInbox.ProvedEventPayload memory)
    {
        IInbox.ProveInput[] memory inputs =
            _createProveInputWithMetadata(_proposal, _parentTransitionHash, _designatedProver, _actualProver);
        bytes memory proveData = codex.encodeProveInput(inputs);

        vm.recordLogs();
        vm.prank(_actualProver);
        inbox.prove(proveData, _createValidProof());

        return _decodeLastProvedEvent();
    }

    function _proveProposalAndGetResult(
        IInbox.Proposal memory _proposal,
        bytes27 _parentTransitionHash
    )
        internal
        returns (ProvenProposal memory)
    {
        IInbox.ProveInput[] memory inputs = _createProveInput(_proposal, _parentTransitionHash);
        bytes memory proveData = codex.encodeProveInput(inputs);

        vm.recordLogs();
        vm.prank(currentProver);
        inbox.prove(proveData, _createValidProof());

        IInbox.ProvedEventPayload memory provedPayload = _decodeLastProvedEvent();

        IInbox.Transition memory transition = IInbox.Transition({
            bondInstructionHash: bytes32(0),
            checkpointHash: codex.hashCheckpoint(provedPayload.checkpoint)
        });

        return ProvenProposal({
            proposal: _proposal,
            transition: transition,
            checkpoint: provedPayload.checkpoint,
            transitionHash: codex.hashTransition(transition),
            finalizationDeadline: provedPayload.finalizationDeadline
        });
    }

    function _proveConsecutiveProposals(IInbox.ProposedEventPayload[] memory _payloads)
        internal
        returns (ProvenProposal[] memory proven)
    {
        proven = new ProvenProposal[](_payloads.length);
        bytes27 parentHash = _getGenesisTransitionHash();

        for (uint256 i = 0; i < _payloads.length; i++) {
            proven[i] = _proveProposalAndGetResult(_payloads[i].proposal, parentHash);
            parentHash = proven[i].transitionHash;
        }
    }

    // ---------------------------------------------------------------
    // Ring Buffer Helpers
    // ---------------------------------------------------------------

    function _fillRingBufferToCapacity() internal returns (RingBufferFillResult memory result) {
        _setupBlobHashes();

        if (block.number < 2) {
            vm.roll(2);
        }

        vm.warp(block.timestamp + 1);

        uint48 ringCapacity = uint48(ringBufferSize - 1);
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](ringCapacity);

        IInbox.ProposedEventPayload memory firstPayload = _proposeAndGetPayload();
        proposals[0] = firstPayload.proposal;

        IInbox.ProposedEventPayload memory lastPayload = firstPayload;
        IInbox.ProposedEventPayload memory secondPayload;

        for (uint48 proposalId = 2; proposalId <= ringCapacity; ++proposalId) {
            vm.roll(block.number + 1);
            vm.warp(block.timestamp + 1);
            _setupBlobHashes();

            IInbox.ProposedEventPayload memory payload = _proposeConsecutive(lastPayload);
            proposals[proposalId - 1] = payload.proposal;

            if (proposalId == 2) {
                secondPayload = payload;
            }

            lastPayload = payload;
        }

        result = RingBufferFillResult({
            first: firstPayload, second: secondPayload, last: lastPayload, proposals: proposals
        });
    }

    // ---------------------------------------------------------------
    // Forced Inclusion Helpers
    // ---------------------------------------------------------------

    function _enqueueForcedInclusion(
        LibBlobs.BlobReference memory _ref,
        address _payer
    )
        internal
        returns (LibBlobs.BlobSlice memory)
    {
        uint40 timestampBefore = uint40(block.timestamp);
        uint256 fee = uint256(inbox.getCurrentForcedInclusionFee()) * 1 gwei * 3;

        vm.deal(_payer, fee);
        vm.prank(_payer);
        inbox.saveForcedInclusion{ value: fee }(_ref);

        bytes32[] memory blobHashes = _getBlobHashesForForcedInclusion(_ref);

        return LibBlobs.BlobSlice({
            blobHashes: blobHashes, offset: _ref.offset, timestamp: timestampBefore
        });
    }

    function _getBlobHashesForForcedInclusion(LibBlobs.BlobReference memory _ref)
        internal
        pure
        returns (bytes32[] memory)
    {
        bytes32[] memory fullHashes = _getBlobHashesForTest(DEFAULT_TEST_BLOB_COUNT);
        bytes32[] memory selected = new bytes32[](_ref.numBlobs);

        for (uint256 i = 0; i < _ref.numBlobs; i++) {
            selected[i] = fullHashes[_ref.blobStartIndex + i];
        }

        return selected;
    }

    function _getForcedInclusionDelay() internal view returns (uint64) {
        return inbox.getConfig().forcedInclusionDelay;
    }

    function _getPermissionlessInclusionMultiplier() internal view returns (uint8) {
        return inbox.getConfig().permissionlessInclusionMultiplier;
    }

    // ---------------------------------------------------------------
    // Utility Helpers
    // ---------------------------------------------------------------

    function _advanceToSafeState(uint48 _blockNumber, uint48 _timestamp) internal {
        require(_blockNumber >= 2, "Block number must be >= 2");
        vm.roll(_blockNumber);
        vm.warp(_timestamp);
    }

    function _rollOneBlock() internal {
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 12);
    }

    function _buildParentArray(IInbox.Proposal memory _parent)
        internal
        pure
        returns (IInbox.Proposal[] memory parents)
    {
        parents = new IInbox.Proposal[](1);
        parents[0] = _parent;
    }

    function _wrapSingleTransition(IInbox.Transition memory _transition)
        internal
        pure
        returns (IInbox.Transition[] memory transitions)
    {
        transitions = new IInbox.Transition[](1);
        transitions[0] = _transition;
    }

    function _getGasSnapshotName(string memory _baseName) internal pure returns (string memory) {
        return string.concat(_baseName, "_Inbox");
    }

    function _labelForCount(
        string memory _prefix,
        uint256 _count
    )
        internal
        pure
        returns (string memory)
    {
        return string.concat(_prefix, "_", Strings.toString(_count));
    }
}
