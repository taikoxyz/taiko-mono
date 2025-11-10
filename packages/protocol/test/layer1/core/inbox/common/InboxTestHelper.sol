// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IInboxDeployer } from "../deployers/IInboxDeployer.sol";
import { MockERC20, MockProofVerifier } from "../mocks/MockContracts.sol";
import { PreconfWhitelistSetup } from "./PreconfWhitelistSetup.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ICodec } from "src/layer1/core/iface/ICodec.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { IProposerChecker } from "src/layer1/core/iface/IProposerChecker.sol";
import { Inbox } from "src/layer1/core/impl/Inbox.sol";
import { LibBlobs } from "src/layer1/core/libs/LibBlobs.sol";
import { IProofVerifier } from "src/layer1/verifiers/IProofVerifier.sol";
import { LibBonds } from "src/shared/libs/LibBonds.sol";
import { ICheckpointStore } from "src/shared/signal/ICheckpointStore.sol";
import { SignalService } from "src/shared/signal/SignalService.sol";
import { CommonTest } from "test/shared/CommonTest.sol";

/// @title InboxTestHelper
/// @notice Combined utility functions and setup logic for Inbox tests
abstract contract InboxTestHelper is CommonTest {
    // ---------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------

    address internal constant MOCK_REMOTE_SIGNAL_SERVICE = address(1);
    bytes32 internal constant GENESIS_BLOCK_HASH = bytes32(uint256(1));
    uint48 internal constant INITIAL_BLOCK_NUMBER = 100;
    uint48 internal constant INITIAL_BLOCK_TIMESTAMP = 1000;
    uint256 internal constant DEFAULT_TEST_BLOB_COUNT = 9;

    // ---------------------------------------------------------------
    // Core Test Infrastructure
    // ---------------------------------------------------------------

    /// @notice Name of the current inbox contract being tested
    string public inboxContractName;

    // ---------------------------------------------------------------
    // Test Environment State
    // ---------------------------------------------------------------

    /// @notice The inbox contract instance under test
    Inbox internal inbox;

    /// @notice Test owner address for contract deployments
    address internal owner = Alice;

    /// @notice Mock bond token for testing
    IERC20 internal bondToken;

    /// @notice Signal service interface used for checkpoint management
    ICheckpointStore internal checkpointManager;

    /// @notice Signal service proxy used as checkpoint manager
    SignalService internal signalService;

    /// @notice Mock proof verifier for testing
    IProofVerifier internal proofVerifier;

    /// @notice Proposer checker contract for validation
    IProposerChecker internal proposerChecker;

    /// @notice Deployer instance for creating inbox contracts
    IInboxDeployer internal inboxDeployer;

    /// @notice Helper for proposer whitelist setup
    PreconfWhitelistSetup internal proposerHelper;

    /// @notice Initialize the contract name for testing
    /// @param _contractName Name of the inbox contract being tested
    function _initializeContractName(string memory _contractName) internal {
        inboxContractName = _contractName;
    }

    /// @notice Helper function to get codec from inbox configuration
    /// @return codec_ The ICodec instance from inbox config
    function _codec() internal view returns (ICodec codec_) {
        return ICodec(inbox.getConfig().codec);
    }

    // ---------------------------------------------------------------
    // Genesis State Builders
    // ---------------------------------------------------------------

    /// @notice Get the genesis core state for testing
    /// @return Genesis CoreState with initial values
    function _getGenesisCoreState() internal view returns (IInbox.CoreState memory) {
        return IInbox.CoreState({
            nextProposalId: 1,
            lastProposalBlockId: 1, // Genesis value - last proposal was made at block 1
            lastFinalizedProposalId: 0,
            lastCheckpointTimestamp: 0,
            lastFinalizedTransitionHash: _getGenesisTransitionHash(),
            bondInstructionsHash: bytes32(0)
        });
    }

    /// @notice Get the genesis transition hash
    /// @return Hash of the genesis transition
    function _getGenesisTransitionHash() internal view returns (bytes32) {
        IInbox.Transition memory transition;
        transition.checkpoint.blockHash = GENESIS_BLOCK_HASH;
        return _codec().hashTransition(transition);
    }

    /// @notice Create the genesis proposal for testing
    /// @return Genesis Proposal with default values
    function _createGenesisProposal() internal view returns (IInbox.Proposal memory) {
        IInbox.CoreState memory coreState = _getGenesisCoreState();
        IInbox.Derivation memory derivation; // Empty derivation

        return IInbox.Proposal({
            id: 0,
            proposer: address(0),
            timestamp: 0,
            endOfSubmissionWindowTimestamp: 0,
            coreStateHash: _codec().hashCoreState(coreState),
            derivationHash: _codec().hashDerivation(derivation)
        });
    }

    // ---------------------------------------------------------------
    // Blob Helpers
    // ---------------------------------------------------------------

    /// @notice Setup blob hashes with default count for testing
    function _setupBlobHashes() internal {
        _setupBlobHashes(DEFAULT_TEST_BLOB_COUNT);
    }

    /// @notice Setup blob hashes with specified count
    /// @param _numBlobs Number of blob hashes to generate
    function _setupBlobHashes(uint256 _numBlobs) internal {
        vm.blobhashes(_getBlobHashesForTest(_numBlobs));
    }

    /// @notice Generate deterministic blob hashes for testing
    /// @param _numBlobs Number of blob hashes to generate
    /// @return Array of blob hashes
    function _getBlobHashesForTest(uint256 _numBlobs) internal pure returns (bytes32[] memory) {
        bytes32[] memory hashes = new bytes32[](_numBlobs);
        for (uint256 i = 0; i < _numBlobs; i++) {
            hashes[i] = keccak256(abi.encode("blob", i));
        }
        return hashes;
    }

    /// @notice Create a blob reference for testing
    /// @param _blobStartIndex Starting index of the blob
    /// @param _numBlobs Number of blobs to reference
    /// @param _offset Offset within the blob data
    /// @return BlobReference struct
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
    // Expected Event Payload Builders
    // ---------------------------------------------------------------

    function _buildExpectedProposedPayload(
        uint48 _proposalId,
        uint8 _numBlobs,
        uint24 _offset,
        address _currentProposer
    )
        internal
        view
        returns (IInbox.ProposedEventPayload memory)
    {
        // Build the expected core state after proposal
        // Proposals set lastProposalBlockId to current block.number
        IInbox.CoreState memory expectedCoreState = IInbox.CoreState({
            nextProposalId: _proposalId + 1,
            lastProposalBlockId: uint48(block.number), // current block.number
            lastFinalizedProposalId: 0,
            lastCheckpointTimestamp: 0,
            lastFinalizedTransitionHash: _getGenesisTransitionHash(),
            bondInstructionsHash: bytes32(0)
        });

        // Build the expected derivation with multi-source format
        // Extract the correct subset of blob hashes from the full set setup by _setupBlobHashes
        bytes32[] memory fullBlobHashes = _getBlobHashesForTest(DEFAULT_TEST_BLOB_COUNT);
        bytes32[] memory selectedBlobHashes = new bytes32[](_numBlobs);
        for (uint256 i = 0; i < _numBlobs; i++) {
            selectedBlobHashes[i] = fullBlobHashes[i]; // Start from index 0 as per _createBlobRef
        }

        IInbox.DerivationSource[] memory sources = new IInbox.DerivationSource[](1);
        sources[0] = IInbox.DerivationSource({
            isForcedInclusion: false,
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: selectedBlobHashes, offset: _offset, timestamp: uint48(block.timestamp)
            })
        });

        IInbox.Derivation memory expectedDerivation = IInbox.Derivation({
            originBlockNumber: uint48(block.number - 1),
            originBlockHash: blockhash(block.number - 1),
            basefeeSharingPctg: 0, // Matches suite's test inbox config (basefeeSharingPctg = 0)
            sources: sources
        });

        // Build the expected proposal
        IInbox.Proposal memory expectedProposal = IInbox.Proposal({
            id: _proposalId,
            proposer: _currentProposer,
            timestamp: uint48(block.timestamp),
            endOfSubmissionWindowTimestamp: 0, // PreconfWhitelist returns 0 for
            // endOfSubmissionWindowTimestamp
            coreStateHash: _codec().hashCoreState(expectedCoreState),
            derivationHash: _codec().hashDerivation(expectedDerivation)
        });

        return IInbox.ProposedEventPayload({
            proposal: expectedProposal,
            derivation: expectedDerivation,
            coreState: expectedCoreState,
            bondInstructions: new LibBonds.BondInstruction[](0)
        });
    }

    // ---------------------------------------------------------------
    // ProposeInput Struct Builders
    // ---------------------------------------------------------------

    function _createProposeInputWithCustomParams(
        uint48 _deadline,
        LibBlobs.BlobReference memory _blobRef,
        IInbox.Proposal[] memory _parentProposals,
        IInbox.CoreState memory _coreState
    )
        internal
        view
        returns (IInbox.ProposeInput memory)
    {
        return IInbox.ProposeInput({
            deadline: _deadline,
            coreState: _coreState,
            parentProposals: _parentProposals,
            blobReference: _blobRef,
            checkpoint: ICheckpointStore.Checkpoint({
                blockNumber: uint48(block.number),
                blockHash: blockhash(block.number - 1),
                stateRoot: bytes32(uint256(100))
            }),
            transitionRecords: new IInbox.TransitionRecord[](0),
            numForcedInclusions: 0
        });
    }

    /// @notice Create the first proposal input with default parameters
    /// @return ProposeInput struct for the first proposal
    function _createFirstProposeInput() internal view returns (IInbox.ProposeInput memory) {
        IInbox.CoreState memory coreState = _getGenesisCoreState();
        IInbox.Proposal[] memory parentProposals = new IInbox.Proposal[](1);
        parentProposals[0] = _createGenesisProposal();
        LibBlobs.BlobReference memory blobRef = _createBlobRef(0, 1, 0);

        return IInbox.ProposeInput({
            deadline: 0,
            coreState: coreState,
            parentProposals: parentProposals,
            blobReference: blobRef,
            transitionRecords: new IInbox.TransitionRecord[](0),
            numForcedInclusions: 0,
            checkpoint: ICheckpointStore.Checkpoint({
                blockNumber: uint48(block.number),
                blockHash: blockhash(block.number - 1),
                stateRoot: bytes32(uint256(100))
            })
        });
    }

    /// @notice Create a proposal input with custom deadline
    /// @param _deadline Proposal deadline timestamp
    /// @return ProposeInput struct with specified deadline
    function _createProposeInputWithDeadline(uint48 _deadline)
        internal
        view
        returns (IInbox.ProposeInput memory)
    {
        IInbox.CoreState memory coreState = _getGenesisCoreState();
        IInbox.Proposal[] memory parentProposals = new IInbox.Proposal[](1);
        parentProposals[0] = _createGenesisProposal();

        return _createProposeInputWithCustomParams(
            _deadline, _createBlobRef(0, 1, 0), parentProposals, coreState
        );
    }

    /// @notice Create a proposal input with custom blob configuration
    /// @param _numBlobs Number of blobs to reference
    /// @param _offset Offset within the blob data
    /// @return ProposeInput struct with specified blob configuration
    function _createProposeInputWithBlobs(
        uint8 _numBlobs,
        uint24 _offset
    )
        internal
        view
        returns (IInbox.ProposeInput memory)
    {
        IInbox.CoreState memory coreState = _getGenesisCoreState();
        IInbox.Proposal[] memory parentProposals = new IInbox.Proposal[](1);
        parentProposals[0] = _createGenesisProposal();
        LibBlobs.BlobReference memory blobRef = _createBlobRef(0, _numBlobs, _offset);

        return _createProposeInputWithCustomParams(0, blobRef, parentProposals, coreState);
    }

    // ---------------------------------------------------------------
    // Setup Functions (merged from InboxTestSetup)
    // ---------------------------------------------------------------

    /// @notice Set the deployer to use for creating inbox instances
    /// @param _deployer The inbox deployer contract
    function setDeployer(IInboxDeployer _deployer) internal {
        inboxDeployer = _deployer;
    }

    function setUp() public virtual override {
        super.setUp();

        // Create proposer helper
        proposerHelper = new PreconfWhitelistSetup();

        // Deploy dependencies
        _setupDependencies();

        // Setup mocks
        _setupMocks();

        // Deploy inbox using the deployer
        require(address(inboxDeployer) != address(0), "Deployer not set");
        inbox = inboxDeployer.deployInbox(
            address(bondToken),
            address(checkpointManager), // signalService
            address(proofVerifier),
            address(proposerChecker)
        );

        assertEq(SignalService(signalService).owner(), owner, "signal service owner mismatch");
        vm.startPrank(owner);
        SignalService(signalService)
            .upgradeTo(address(new SignalService(address(inbox), MOCK_REMOTE_SIGNAL_SERVICE)));
        vm.stopPrank();

        _initializeContractName(inboxDeployer.getTestContractName());

        // Advance block to ensure we have block history
        vm.roll(INITIAL_BLOCK_NUMBER);
        vm.warp(INITIAL_BLOCK_TIMESTAMP);
    }

    /// @notice Setup mock contracts for testing
    /// @dev We use mocks only for dependencies that are not critical to the test logic
    /// or are well-tested externally (e.g. ERC20 tokens)
    function _setupMocks() internal {
        bondToken = new MockERC20();
        proofVerifier = new MockProofVerifier();
    }

    /// @notice Deploy real contracts that serve as inbox dependencies
    /// @dev Override this function in derived test contracts for custom dependency setup
    function _setupDependencies() internal virtual {
        // Deploy PreconfWhitelist as the proposer checker
        proposerChecker = proposerHelper._deployPreconfWhitelist(owner);

        SignalService signalServiceImpl =
            new SignalService(address(this), MOCK_REMOTE_SIGNAL_SERVICE);
        signalService = SignalService(
            address(
                new ERC1967Proxy(
                    address(signalServiceImpl), abi.encodeCall(SignalService.init, (owner))
                )
            )
        );

        checkpointManager = ICheckpointStore(address(signalService));
    }

    /// @notice Helper function to select and whitelist a proposer
    /// @param _proposer The address to whitelist as proposer
    /// @return The whitelisted proposer address
    function _selectProposer(address _proposer) internal returns (address) {
        return proposerHelper._selectProposer(proposerChecker, _proposer);
    }

    // ---------------------------------------------------------------
    // Additional Utility Functions
    // ---------------------------------------------------------------

    /// @notice Check if current contract name indicates an optimized implementation
    /// @return True if using optimized implementation
    function _isOptimizedImplementation() internal view returns (bool) {
        bytes32 nameHash = keccak256(bytes(inboxContractName));
        return nameHash == keccak256(bytes("InboxOptimized2"));
    }

    /// @notice Get contract-specific gas snapshot name
    /// @param _baseName Base name for the gas snapshot
    /// @return Full snapshot name with contract suffix
    function _getGasSnapshotName(string memory _baseName) internal view returns (string memory) {
        return string.concat(_baseName, "_", inboxContractName);
    }

    /// @notice Advance blockchain state to a safe testing position
    /// @param _blockNumber Target block number (must be >= 2)
    /// @param _timestamp Target timestamp
    function _advanceToSafeState(uint48 _blockNumber, uint48 _timestamp) internal {
        require(_blockNumber >= 2, "Block number must be >= 2 for safe blockhash access");
        vm.roll(_blockNumber);
        vm.warp(_timestamp);
    }

    /// @notice Create a proposal input for testing consecutive proposals
    /// @param _parentProposal The parent proposal to build upon
    /// @param _proposalId The ID for the new proposal
    /// @return ProposeInput struct for consecutive proposal
    function _createConsecutiveProposeInput(
        IInbox.Proposal memory _parentProposal,
        uint48 _proposalId
    )
        internal
        view
        returns (IInbox.ProposeInput memory)
    {
        IInbox.CoreState memory coreState = IInbox.CoreState({
            nextProposalId: _proposalId,
            lastProposalBlockId: uint48(block.number),
            lastFinalizedProposalId: 0,
            lastCheckpointTimestamp: 0,
            lastFinalizedTransitionHash: _getGenesisTransitionHash(),
            bondInstructionsHash: bytes32(0)
        });

        IInbox.Proposal[] memory parentProposals = new IInbox.Proposal[](1);
        parentProposals[0] = _parentProposal;

        return _createProposeInputWithCustomParams(
            0, _createBlobRef(0, 1, 0), parentProposals, coreState
        );
    }
}
