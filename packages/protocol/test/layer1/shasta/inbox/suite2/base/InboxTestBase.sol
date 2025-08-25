// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { CommonTest } from "test/shared/CommonTest.sol";
import { IInbox } from "src/layer1/shasta/iface/IInbox.sol";
import { Inbox } from "src/layer1/shasta/impl/Inbox.sol";
import { LibBlobs } from "src/layer1/shasta/libs/LibBlobs.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {
    MockERC20,
    MockSyncedBlockManager,
    MockProofVerifier,
    MockProposerChecker
} from "../mocks/MockContracts.sol";
import { ForcedInclusionStore } from "src/layer1/shasta/impl/ForcedInclusionStore.sol";
import { IProofVerifier } from "src/layer1/shasta/iface/IProofVerifier.sol";
import { IProposerChecker } from "src/layer1/shasta/iface/IProposerChecker.sol";
import { IForcedInclusionStore } from "src/layer1/shasta/iface/IForcedInclusionStore.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ISyncedBlockManager } from "src/shared/based/iface/ISyncedBlockManager.sol";
import { UUPSUpgradeable } from "@openzeppelin-upgrades/contracts/proxy/utils/UUPSUpgradeable.sol";

/// @title InboxTestBase
/// @notice Base setup and helpers for Inbox tests
/// @custom:security-contact security@taiko.xyz
abstract contract InboxTestBase is CommonTest {
    // ---------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------

    Inbox internal inbox;
    address internal owner = Alice;
    address internal currentProposer = Bob;
    address internal nextProposer = Carol;

    // Mock contracts
    IERC20 internal bondToken;
    ISyncedBlockManager internal syncedBlockManager;
    IProofVerifier internal proofVerifier;
    IProposerChecker internal proposerChecker;

    // Dependencies
    IForcedInclusionStore internal forcedInclusionStore;

    // Constants
    bytes32 internal constant GENESIS_BLOCK_HASH = bytes32(uint256(1));
    uint256 internal constant DEFAULT_RING_BUFFER_SIZE = 100;
    uint256 internal constant DEFAULT_MAX_FINALIZATION_COUNT = 10;
    uint48 internal constant DEFAULT_PROVING_WINDOW = 1 hours;
    uint48 internal constant DEFAULT_EXTENDED_PROVING_WINDOW = 2 hours;
    uint8 internal constant DEFAULT_BASEFEE_SHARING_PCTG = 10;
    uint48 internal constant INITIAL_BLOCK_NUMBER = 100;
    uint48 internal constant INITIAL_BLOCK_TIMESTAMP = 1000;

    // Test blob hashes
    bytes32[] internal testBlobHashes;

    // Forced inclusion
    uint64 internal constant INCLUSION_DELAY = 10 minutes;
    uint64 internal constant FEE_IN_GWEI = 100;

    // ---------------------------------------------------------------
    // modifiers
    // ---------------------------------------------------------------

    modifier withBlobs() {
        _setupBlobHashes();
        _;
    }

    // ---------------------------------------------------------------
    // Setup Functions
    // ---------------------------------------------------------------

    /// @dev We usually avoid mocks as much as possible since they might make testing flaky
    /// @dev We use mocks for the dependencies that are not important, well tested and with uniform
    /// behavior(e.g. ERC20) or that are not implemented yet
    function _setupMocks() internal {
        bondToken = new MockERC20();
        syncedBlockManager = new MockSyncedBlockManager();
        proofVerifier = new MockProofVerifier();
        proposerChecker = new MockProposerChecker();
    }

    /// @dev Deploy the real contracts that will be used as dependencies of the inbox
    ///      Some of these may need to be updgraded later because of circular references
    function _setupDependencies() internal {
        // we then need to update the ForcedInclusionStore to use the inbox address
        address forcedInclusionStoreImplementation =
            address(new ForcedInclusionStore(INCLUSION_DELAY, FEE_IN_GWEI, address(0)));

        forcedInclusionStore = IForcedInclusionStore(
            deploy({
                name: "",
                impl: forcedInclusionStoreImplementation,
                data: abi.encodeCall(ForcedInclusionStore.init, (owner))
            })
        );
    }

    /// @dev Upgrade the dependencies of the inbox
    ///      This is used to upgrade the dependencies of the inbox after the inbox is deployed
    ///      and the dependencies are not upgradable
    function _upgradeDependencies(address _inbox) internal {
        address newForcedInclusionStore =
            address(new ForcedInclusionStore(INCLUSION_DELAY, FEE_IN_GWEI, _inbox));

        vm.prank(owner);
        UUPSUpgradeable(address(forcedInclusionStore)).upgradeTo(newForcedInclusionStore);
    }

    // ---------------------------------------------------------------
    // Genesis State Builders
    // ---------------------------------------------------------------

    function _getGenesisCoreState() internal pure returns (IInbox.CoreState memory) {
        return IInbox.CoreState({
            nextProposalId: 1,
            lastFinalizedProposalId: 0,
            lastFinalizedTransitionHash: _getGenesisTransitionHash(),
            bondInstructionsHash: bytes32(0)
        });
    }

    function _getGenesisTransitionHash() internal pure returns (bytes32) {
        IInbox.Transition memory transition;
        transition.endBlockMiniHeader.hash = GENESIS_BLOCK_HASH;
        return keccak256(abi.encode(transition));
    }

    function _createGenesisProposal() internal pure returns (IInbox.Proposal memory) {
        IInbox.CoreState memory coreState = IInbox.CoreState({
            nextProposalId: 1,
            lastFinalizedProposalId: 0,
            lastFinalizedTransitionHash: _getGenesisTransitionHash(),
            bondInstructionsHash: bytes32(0)
        });

        IInbox.Derivation memory derivation;

        return IInbox.Proposal({
            id: 0,
            proposer: address(0),
            timestamp: 0,
            coreStateHash: keccak256(abi.encode(coreState)),
            derivationHash: keccak256(abi.encode(derivation))
        });
    }

    // ---------------------------------------------------------------
    // Blob Helpers
    // ---------------------------------------------------------------

    function _setupBlobHashes() internal {
        // Setup test blob hashes for EIP-4844
        bytes32[] memory hashes = new bytes32[](9);
        for (uint256 i = 0; i < 9; i++) {
            hashes[i] = keccak256(abi.encode("blob", i));
            testBlobHashes.push(hashes[i]);
        }
        // Mock the blobhash function for testing
        vm.blobhashes(hashes);
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
            blobStartIndex: _blobStartIndex,
            numBlobs: _numBlobs,
            offset: _offset
        });
    }

    // ---------------------------------------------------------------
    // Propose Input Builders
    // ---------------------------------------------------------------

    function _createProposeInputWithCustomParams(
        uint48 _deadline,
        LibBlobs.BlobReference memory _blobRef,
        IInbox.Proposal[] memory _parentProposals,
        IInbox.CoreState memory _coreState
    )
        internal
        view
        returns (bytes memory)
    {
        IInbox.ProposeInput memory input = IInbox.ProposeInput({
            deadline: _deadline,
            coreState: _coreState,
            parentProposals: _parentProposals,
            blobReference: _blobRef,
            endBlockMiniHeader: IInbox.BlockMiniHeader({
                number: uint48(block.number),
                hash: blockhash(block.number - 1),
                stateRoot: bytes32(uint256(100))
            }),
            transitionRecords: new IInbox.TransitionRecord[](0)
        });
        
        return inbox.encodeProposeInput(input);
    }

    function _createFirstProposeInput() internal view returns (bytes memory) {
        // For the first proposal after genesis, we need specific state
        IInbox.CoreState memory coreState = _getGenesisCoreState();

        // Parent proposal is genesis (id=0)
        IInbox.Proposal[] memory parentProposals = new IInbox.Proposal[](1);
        parentProposals[0] = _createGenesisProposal();

        // Create blob reference
        LibBlobs.BlobReference memory blobRef = _createBlobRef(0, 1, 0);

        // Create the propose input
        IInbox.ProposeInput memory input;
        input.coreState = coreState;
        input.parentProposals = parentProposals;
        input.blobReference = blobRef;

        return inbox.encodeProposeInput(input);
    }

    function _createProposeInputWithDeadline(uint48 _deadline) internal view returns (bytes memory) {
        IInbox.CoreState memory coreState = _getGenesisCoreState();
        IInbox.Proposal[] memory parentProposals = new IInbox.Proposal[](1);
        parentProposals[0] = _createGenesisProposal();
        
        return _createProposeInputWithCustomParams(
            _deadline,
            _createBlobRef(0, 1, 0),
            parentProposals,
            coreState
        );
    }

    function _createProposeInputWithBlobs(
        uint8 _numBlobs,
        uint24 _offset
    )
        internal
        view
        returns (bytes memory)
    {
        IInbox.CoreState memory coreState = _getGenesisCoreState();
        IInbox.Proposal[] memory parentProposals = new IInbox.Proposal[](1);
        parentProposals[0] = _createGenesisProposal();
        
        LibBlobs.BlobReference memory blobRef = _createBlobRef(0, _numBlobs, _offset);
        
        return _createProposeInputWithCustomParams(
            0, // no deadline
            blobRef,
            parentProposals,
            coreState
        );
    }

    // ---------------------------------------------------------------
    // Expected Event Payload Builders
    // ---------------------------------------------------------------

    function _buildExpectedProposedPayload(
        uint48 _proposalId,
        uint8 _numBlobs,
        uint24 _offset
    )
        internal
        view
        returns (IInbox.ProposedEventPayload memory)
    {
        // Build the expected core state after proposal
        IInbox.CoreState memory expectedCoreState = IInbox.CoreState({
            nextProposalId: _proposalId + 1,
            lastFinalizedProposalId: 0,
            lastFinalizedTransitionHash: _getGenesisTransitionHash(),
            bondInstructionsHash: bytes32(0)
        });

        // Build the expected derivation
        IInbox.Derivation memory expectedDerivation = IInbox.Derivation({
            originBlockNumber: uint48(block.number - 1),
            originBlockHash: blockhash(block.number - 1),
            isForcedInclusion: false,
            basefeeSharingPctg: 0, // Using actual value from SimpleInbox config
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: _getBlobHashesForTest(_numBlobs),
                offset: _offset,
                timestamp: uint48(block.timestamp)
            })
        });

        // Build the expected proposal
        IInbox.Proposal memory expectedProposal = IInbox.Proposal({
            id: _proposalId,
            proposer: currentProposer,
            timestamp: uint48(block.timestamp),
            coreStateHash: keccak256(abi.encode(expectedCoreState)),
            derivationHash: keccak256(abi.encode(expectedDerivation))
        });

        return IInbox.ProposedEventPayload({
            proposal: expectedProposal,
            derivation: expectedDerivation,
            coreState: expectedCoreState
        });
    }

    // Convenience overload with default blob parameters
    function _buildExpectedProposedPayload(uint48 _proposalId)
        internal
        view
        returns (IInbox.ProposedEventPayload memory)
    {
        return _buildExpectedProposedPayload(_proposalId, 1, 0);
    }

    // Convenience function for buildExpectedProposedPayload with custom blob params
    function _buildExpectedProposedPayloadWithBlobs(
        uint48 _proposalId,
        uint8 _numBlobs,
        uint24 _offset
    )
        internal
        view
        returns (IInbox.ProposedEventPayload memory)
    {
        return _buildExpectedProposedPayload(_proposalId, _numBlobs, _offset);
    }

    // ---------------------------------------------------------------
    // Abstract Functions
    // ---------------------------------------------------------------

    function deployInbox(
        address bondToken,
        address syncedBlockManager,
        address proofVerifier,
        address proposerChecker,
        address forcedInclusionStore
    )
        internal
        virtual
        returns (Inbox);

    /// @dev Returns the name of the test contract for snapshot identification
    function getTestContractName() internal pure virtual returns (string memory);
}
