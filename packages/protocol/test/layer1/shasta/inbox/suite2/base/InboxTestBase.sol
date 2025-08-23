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
        setupBlobHashes();
        _;
    }

    // ---------------------------------------------------------------
    // Setup Functions
    // ---------------------------------------------------------------

    /// @dev We usually avoid mocks as much as possible since they might make testing flaky
    /// @dev We use mocks for the dependencies that are not important, well tested and with uniform
    /// behavior(e.g. ERC20) or that are not implemented yet
    function setupMocks() internal {
        bondToken = new MockERC20();
        syncedBlockManager = new MockSyncedBlockManager();
        proofVerifier = new MockProofVerifier();
        proposerChecker = new MockProposerChecker();
    }

    /// @dev Deploy the real contracts that will be used as dependencies of the inbox
    ///      Some of these may need to be updgraded later because of circular references
    function setupDependencies() internal {
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
    function upgradeDependencies(address _inbox) internal {
        address newForcedInclusionStore =
            address(new ForcedInclusionStore(INCLUSION_DELAY, FEE_IN_GWEI, _inbox));

        vm.prank(owner);
        UUPSUpgradeable(address(forcedInclusionStore)).upgradeTo(newForcedInclusionStore);
    }

    // ---------------------------------------------------------------
    // Data Builders
    // ---------------------------------------------------------------

    function createProposeInput(uint48 _proposalId) internal returns (bytes memory) {
        IInbox.CoreState memory coreState = _getGenesisCoreState();

        IInbox.Proposal[] memory parentProposals = new IInbox.Proposal[](1);
        parentProposals[0] = createProposal(_proposalId - 1, coreState);

        LibBlobs.BlobReference memory blobRef =
            LibBlobs.BlobReference({ blobStartIndex: 0, numBlobs: 1, offset: 0 });

        IInbox.ProposeInput memory input = IInbox.ProposeInput({
            deadline: 0,
            coreState: coreState,
            parentProposals: parentProposals,
            blobReference: blobRef,
            endBlockMiniHeader: IInbox.BlockMiniHeader({
                number: uint48(block.number),
                hash: blockhash(block.number - 1),
                stateRoot: bytes32(uint256(100))
            }),
            transitionRecords: new IInbox.TransitionRecord[](0)
        });

        return abi.encode(input);
    }

    function createProposal(
        uint48 _id,
        IInbox.CoreState memory _coreState
    )
        internal
        view
        returns (IInbox.Proposal memory)
    {
        IInbox.Derivation memory derivation = IInbox.Derivation({
            originBlockNumber: uint48(block.number - 1),
            originBlockHash: blockhash(block.number - 1),
            isForcedInclusion: false,
            basefeeSharingPctg: DEFAULT_BASEFEE_SHARING_PCTG,
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: testBlobHashes,
                offset: 0,
                timestamp: uint48(block.timestamp)
            })
        });

        return IInbox.Proposal({
            id: _id,
            proposer: Alice,
            timestamp: uint48(block.timestamp),
            coreStateHash: keccak256(abi.encode(_coreState)),
            derivationHash: keccak256(abi.encode(derivation))
        });
    }

    function getGenesisTransitionHash() internal pure returns (bytes32) {
        IInbox.Transition memory transition;
        transition.endBlockMiniHeader.hash = GENESIS_BLOCK_HASH;
        return keccak256(abi.encode(transition));
    }

    function createGenesisProposal() internal pure returns (IInbox.Proposal memory) {
        IInbox.CoreState memory coreState = IInbox.CoreState({
            nextProposalId: 1,
            lastFinalizedProposalId: 0,
            lastFinalizedTransitionHash: getGenesisTransitionHash(),
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
    // Test Helper Functions
    // ---------------------------------------------------------------

    function createFirstProposeInput() internal returns (bytes memory) {
        // For the first proposal after genesis, we need specific state
        IInbox.CoreState memory coreState = _getGenesisCoreState();

        // Parent proposal is genesis (id=0)
        IInbox.Proposal[] memory parentProposals = new IInbox.Proposal[](1);
        parentProposals[0] = createGenesisProposal();

        // Create blob reference
        LibBlobs.BlobReference memory blobRef = _createBlobRef();

        // Create the propose input
        IInbox.ProposeInput memory input;
        input.coreState = coreState;
        input.parentProposals = parentProposals;
        input.blobReference = blobRef;

        return abi.encode(input);
    }

    function buildExpectedProposedPayload(uint48 _proposalId)
        internal
        view
        returns (IInbox.ProposedEventPayload memory)
    {
        // Build the expected core state after proposal
        IInbox.CoreState memory expectedCoreState = IInbox.CoreState({
            nextProposalId: _proposalId + 1,
            lastFinalizedProposalId: 0,
            lastFinalizedTransitionHash: getGenesisTransitionHash(),
            bondInstructionsHash: bytes32(0)
        });

        // Build the expected derivation
        IInbox.Derivation memory expectedDerivation = IInbox.Derivation({
            originBlockNumber: uint48(block.number - 1),
            originBlockHash: blockhash(block.number - 1),
            isForcedInclusion: false,
            basefeeSharingPctg: 0, // Using actual value from SimpleInbox config
            blobSlice: LibBlobs.BlobSlice({
                blobHashes: getBlobHashesForTest(1),
                offset: 0,
                timestamp: uint48(block.timestamp)
            })
        });

        // Build the expected proposal
        IInbox.Proposal memory expectedProposal = IInbox.Proposal({
            id: _proposalId,
            proposer: Alice,
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

    function getBlobHashesForTest(uint256 _numBlobs) internal pure returns (bytes32[] memory) {
        bytes32[] memory hashes = new bytes32[](_numBlobs);
        for (uint256 i = 0; i < _numBlobs; i++) {
            hashes[i] = keccak256(abi.encode("blob", i));
        }
        return hashes;
    }

    function setupBlobHashes() internal {
        // Setup test blob hashes for EIP-4844
        bytes32[] memory hashes = new bytes32[](9);
        for (uint256 i = 0; i < 9; i++) {
            hashes[i] = keccak256(abi.encode("blob", i));
            testBlobHashes.push(hashes[i]);
        }
        // Mock the blobhash function for testing
        vm.blobhashes(hashes);
    }

    function _getGenesisCoreState() internal returns (IInbox.CoreState memory) {
        return IInbox.CoreState({
            nextProposalId: 1,
            lastFinalizedProposalId: 0,
            lastFinalizedTransitionHash: getGenesisTransitionHash(),
            bondInstructionsHash: bytes32(0)
        });
    }

    function _createBlobRef() internal returns (LibBlobs.BlobReference memory) {
        return LibBlobs.BlobReference({ blobStartIndex: 0, numBlobs: 1, offset: 0 });
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
}
