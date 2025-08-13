// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/src/Test.sol";
import "test/shared/CommonTest.sol";
import "./TestInboxWithMockBlobs.sol";
import "./InboxMockContracts.sol";
import "contracts/layer1/shasta/iface/IInbox.sol";
import "contracts/layer1/shasta/libs/LibBlobs.sol";
import "contracts/shared/based/libs/LibBonds.sol";
import "contracts/layer1/shasta/iface/IProofVerifier.sol";
import "contracts/layer1/shasta/iface/IProposerChecker.sol";
import "contracts/layer1/shasta/iface/IForcedInclusionStore.sol";
import "contracts/shared/based/iface/ISyncedBlockManager.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/// @title InboxOutOfOrderProving
/// @notice Tests for out-of-order proving and eventual chain advancement
/// @dev Verifies that proposals can be proven in any order but finalization respects sequence
contract InboxOutOfOrderProving is CommonTest {
    TestInboxWithMockBlobs internal inbox;
    IInbox.Config internal defaultConfig;

    // Mock dependencies
    address internal bondToken;
    address internal syncedBlockManager;
    address internal forcedInclusionStore;
    address internal proofVerifier;
    address internal proposerChecker;

    // Constants
    bytes32 internal constant GENESIS_BLOCK_HASH = bytes32(uint256(1));

    function setUp() public virtual override {
        super.setUp();

        // Deploy mock contracts
        bondToken = address(new MockERC20());
        syncedBlockManager = address(new StubSyncedBlockManager());
        forcedInclusionStore = address(new StubForcedInclusionStore());
        proofVerifier = address(new StubProofVerifier());
        proposerChecker = address(new StubProposerChecker());

        // Deploy and initialize inbox
        TestInboxWithMockBlobs impl = new TestInboxWithMockBlobs();
        bytes memory initData = abi.encodeWithSelector(
            bytes4(keccak256("init(address,bytes32)")), address(this), GENESIS_BLOCK_HASH
        );

        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
        inbox = TestInboxWithMockBlobs(address(proxy));

        // Set default config
        defaultConfig = IInbox.Config({
            bondToken: bondToken,
            provingWindow: 1 hours,
            extendedProvingWindow: 2 hours,
            maxFinalizationCount: 10,
            ringBufferSize: 100,
            basefeeSharingPctg: 10,
            syncedBlockManager: syncedBlockManager,
            proofVerifier: proofVerifier,
            proposerChecker: proposerChecker,
            forcedInclusionStore: forcedInclusionStore
        });
        inbox.setTestConfig(defaultConfig);

        // Fund test accounts
        vm.deal(Alice, 100 ether);
        vm.deal(Bob, 100 ether);
        vm.deal(Carol, 100 ether);

        // Setup blob hashes
        setupBlobHashes();
    }

    /// @notice Test proving proposals out of order with eventual finalization
    function test_prove_out_of_order_then_finalize() public {
        setupBlobHashes();
        uint48 numProposals = 3;

        // Get initial parent hash
        IInbox.Claim memory genesisClaim;
        genesisClaim.endBlockHash = GENESIS_BLOCK_HASH;
        bytes32 initialParentHash = keccak256(abi.encode(genesisClaim));

        // Phase 1: Create multiple proposals sequentially
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](numProposals);

        for (uint48 i = 1; i <= numProposals; i++) {
            IInbox.CoreState memory proposalCoreState = IInbox.CoreState({
                nextProposalId: i,
                lastFinalizedProposalId: 0,
                lastFinalizedClaimHash: initialParentHash,
                bondInstructionsHash: bytes32(0)
            });
            inbox.exposed_setCoreStateHash(keccak256(abi.encode(proposalCoreState)));

            mockProposerAllowed(Alice);
            mockForcedInclusionDue(false);

            LibBlobs.BlobReference memory proposalBlobRef = createValidBlobReference(i);
            IInbox.ClaimRecord[] memory emptyClaimRecords = new IInbox.ClaimRecord[](0);
            bytes memory proposalData =
                abi.encode(uint64(0), proposalCoreState, proposalBlobRef, emptyClaimRecords);

            vm.prank(Alice);
            inbox.propose(bytes(""), proposalData);

            // Create the proposal that was stored
            bytes32[] memory blobHashes = new bytes32[](1);
            blobHashes[0] = keccak256(abi.encode("blob", proposalBlobRef.blobStartIndex));

            proposals[i - 1] = IInbox.Proposal({
                id: i,
                proposer: Alice,
                originTimestamp: uint48(block.timestamp),
                originBlockNumber: uint48(block.number),
                isForcedInclusion: false,
                basefeeSharingPctg: defaultConfig.basefeeSharingPctg,
                blobSlice: LibBlobs.BlobSlice({
                    blobHashes: blobHashes,
                    offset: proposalBlobRef.offset,
                    timestamp: uint48(block.timestamp)
                })
            });
        }

        // Phase 2: Prove proposals in REVERSE order (3, 2, 1)
        bytes32[] memory claimHashes = new bytes32[](numProposals);
        IInbox.Claim[] memory claims = new IInbox.Claim[](numProposals);

        // First, calculate all claim hashes in forward order (for parent relationships)
        bytes32 parentHash = initialParentHash;
        for (uint48 i = 0; i < numProposals; i++) {
            bytes32 storedProposalHash = inbox.getProposalHash(i + 1);

            claims[i] = IInbox.Claim({
                proposalHash: storedProposalHash,
                parentClaimHash: parentHash,
                endBlockNumber: uint48(100 + i * 10),
                endBlockHash: keccak256(abi.encode(proposals[i].id, "endBlockHash")),
                endStateRoot: keccak256(abi.encode(proposals[i].id, "stateRoot")),
                designatedProver: Alice,
                actualProver: Alice
            });
            claimHashes[i] = keccak256(abi.encode(claims[i]));
            parentHash = claimHashes[i];
        }

        // Now prove them in reverse order
        for (uint48 i = numProposals; i > 0; i--) {
            uint48 index = i - 1;

            mockProofVerification(true);

            IInbox.Proposal[] memory proveProposals = new IInbox.Proposal[](1);
            proveProposals[0] = proposals[index];
            IInbox.Claim[] memory proveClaims = new IInbox.Claim[](1);
            proveClaims[0] = claims[index];

            bytes memory proveData = abi.encode(proveProposals, proveClaims);
            bytes memory proof = bytes("valid_proof");

            vm.prank(Bob);
            inbox.prove(proveData, proof);

            // Verify claim record was stored with correct parent
            bytes32 claimParentHash = index == 0 ? initialParentHash : claimHashes[index - 1];
            bytes32 storedClaimHash = inbox.getClaimRecordHash(proposals[index].id, claimParentHash);
            assertTrue(storedClaimHash != bytes32(0));
        }

        // Phase 3: Attempt finalization - should finalize all in correct order
        IInbox.ClaimRecord[] memory claimRecords = new IInbox.ClaimRecord[](numProposals);

        for (uint48 i = 0; i < numProposals; i++) {
            claimRecords[i] = IInbox.ClaimRecord({
                claim: claims[i],
                span: 1,
                bondInstructions: new LibBonds.BondInstruction[](0)
            });
        }

        // Setup for finalization
        IInbox.CoreState memory coreState = IInbox.CoreState({
            nextProposalId: numProposals + 1,
            lastFinalizedProposalId: 0,
            lastFinalizedClaimHash: initialParentHash,
            bondInstructionsHash: bytes32(0)
        });
        inbox.exposed_setCoreStateHash(keccak256(abi.encode(coreState)));

        mockProposerAllowed(Carol);
        mockForcedInclusionDue(false);

        // Expect final block update
        IInbox.Claim memory lastClaim = claims[numProposals - 1];
        expectSyncedBlockSave(
            lastClaim.endBlockNumber, lastClaim.endBlockHash, lastClaim.endStateRoot
        );

        // Submit new proposal that triggers finalization
        LibBlobs.BlobReference memory blobRef = createValidBlobReference(numProposals + 1);
        bytes memory proposeData = abi.encode(uint64(0), coreState, blobRef, claimRecords);

        vm.prank(Carol);
        inbox.propose(bytes(""), proposeData);

        // Verify finalization occurred (we can't directly check core state hash
        // but we can verify by checking that the synced block save was called)
    }

    /// @notice Test that unproven proposals block finalization
    function test_unproven_proposals_block_finalization() public {
        setupBlobHashes();
        // Create genesis claim
        IInbox.Claim memory genesisClaim;
        genesisClaim.endBlockHash = GENESIS_BLOCK_HASH;
        bytes32 initialParentHash = keccak256(abi.encode(genesisClaim));

        // Create 3 proposals
        for (uint48 i = 1; i <= 3; i++) {
            IInbox.CoreState memory proposalCoreState = IInbox.CoreState({
                nextProposalId: i,
                lastFinalizedProposalId: 0,
                lastFinalizedClaimHash: initialParentHash,
                bondInstructionsHash: bytes32(0)
            });
            inbox.exposed_setCoreStateHash(keccak256(abi.encode(proposalCoreState)));

            mockProposerAllowed(Alice);
            mockForcedInclusionDue(false);

            LibBlobs.BlobReference memory proposalBlobRef = createValidBlobReference(i);
            IInbox.ClaimRecord[] memory emptyClaimRecords = new IInbox.ClaimRecord[](0);
            bytes memory proposalData =
                abi.encode(uint64(0), proposalCoreState, proposalBlobRef, emptyClaimRecords);

            vm.prank(Alice);
            inbox.propose(bytes(""), proposalData);
        }

        // Prove only proposals 1 and 3 (skip 2)
        for (uint48 i = 1; i <= 3; i += 2) {
            bytes32 storedProposalHash = inbox.getProposalHash(i);

            bytes32[] memory blobHashes = new bytes32[](1);
            blobHashes[0] = keccak256(abi.encode("blob", i % 10));

            IInbox.Proposal memory proposal = IInbox.Proposal({
                id: i,
                proposer: Alice,
                originTimestamp: uint48(block.timestamp),
                originBlockNumber: uint48(block.number),
                isForcedInclusion: false,
                basefeeSharingPctg: defaultConfig.basefeeSharingPctg,
                blobSlice: LibBlobs.BlobSlice({
                    blobHashes: blobHashes,
                    offset: 0,
                    timestamp: uint48(block.timestamp)
                })
            });

            bytes32 parentHash = i == 1 ? initialParentHash : bytes32(uint256(999)); // Dummy parent
                // for 3
            IInbox.Claim memory claim = IInbox.Claim({
                proposalHash: storedProposalHash,
                parentClaimHash: parentHash,
                endBlockNumber: uint48(100 + i * 10),
                endBlockHash: keccak256(abi.encode(i, "endBlockHash")),
                endStateRoot: keccak256(abi.encode(i, "stateRoot")),
                designatedProver: Alice,
                actualProver: Alice
            });

            mockProofVerification(true);

            IInbox.Proposal[] memory proveProposals = new IInbox.Proposal[](1);
            proveProposals[0] = proposal;
            IInbox.Claim[] memory proveClaims = new IInbox.Claim[](1);
            proveClaims[0] = claim;

            bytes memory proveData = abi.encode(proveProposals, proveClaims);
            vm.prank(Bob);
            inbox.prove(proveData, bytes("proof"));
        }

        // Try to finalize - should only finalize proposal 1 because 2 is missing
        IInbox.CoreState memory coreState = IInbox.CoreState({
            nextProposalId: 4,
            lastFinalizedProposalId: 0,
            lastFinalizedClaimHash: initialParentHash,
            bondInstructionsHash: bytes32(0)
        });
        inbox.exposed_setCoreStateHash(keccak256(abi.encode(coreState)));

        // Only provide claim record for proposal 1
        bytes32 storedProposalHashForClaim = inbox.getProposalHash(1);
        IInbox.Claim memory claim1 = IInbox.Claim({
            proposalHash: storedProposalHashForClaim,
            parentClaimHash: initialParentHash,
            endBlockNumber: 110,
            endBlockHash: keccak256(abi.encode(1, "endBlockHash")),
            endStateRoot: keccak256(abi.encode(1, "stateRoot")),
            designatedProver: Alice,
            actualProver: Alice
        });

        IInbox.ClaimRecord[] memory claimRecords = new IInbox.ClaimRecord[](1);
        claimRecords[0] = IInbox.ClaimRecord({
            claim: claim1,
            span: 1,
            bondInstructions: new LibBonds.BondInstruction[](0)
        });

        mockProposerAllowed(Carol);
        mockForcedInclusionDue(false);

        // Expect only proposal 1 to be finalized
        expectSyncedBlockSave(claim1.endBlockNumber, claim1.endBlockHash, claim1.endStateRoot);

        LibBlobs.BlobReference memory blobRef = createValidBlobReference(4);
        bytes memory proposeData = abi.encode(uint64(0), coreState, blobRef, claimRecords);

        vm.prank(Carol);
        inbox.propose(bytes(""), proposeData);

        // Proposal 1 should be finalized, but 2 and 3 should remain unfinalized
        // because 2 is missing its proof
    }

    // Helper functions

    function createValidBlobReference(uint256 _seed)
        internal
        pure
        returns (LibBlobs.BlobReference memory)
    {
        return
            LibBlobs.BlobReference({ blobStartIndex: uint48(_seed % 10), numBlobs: 1, offset: 0 });
    }

    function mockProposerAllowed(address) internal {
        // Stub contract always allows proposers, no need to mock
    }

    function mockForcedInclusionDue(bool _isDue) internal {
        // Stub contract always returns false, only mock if true is needed
        if (_isDue) {
            vm.mockCall(
                forcedInclusionStore,
                abi.encodeWithSelector(IForcedInclusionStore.isOldestForcedInclusionDue.selector),
                abi.encode(_isDue)
            );
        }
    }

    function mockProofVerification(bool _valid) internal {
        // Stub contract always passes verification, no need to mock
        if (!_valid) {
            vm.mockCallRevert(
                proofVerifier,
                abi.encodeWithSelector(IProofVerifier.verifyProof.selector),
                abi.encode("Invalid proof")
            );
        }
    }

    function expectSyncedBlockSave(
        uint48 _blockNumber,
        bytes32 _blockHash,
        bytes32 _stateRoot
    )
        internal
    {
        vm.expectCall(
            syncedBlockManager,
            abi.encodeWithSelector(
                ISyncedBlockManager.saveSyncedBlock.selector, _blockNumber, _blockHash, _stateRoot
            )
        );
    }

    function setupBlobHashes() internal {
        bytes32[] memory hashes = new bytes32[](256);
        for (uint256 i = 0; i < 256; i++) {
            if (i < 10) {
                hashes[i] = keccak256(abi.encode("blob", i));
            }
        }
        vm.blobhashes(hashes);
    }
}
