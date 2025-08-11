// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./ShastaInboxTestBase.sol";
import "contracts/layer1/shasta/impl/InboxBase.sol";
import "contracts/layer1/shasta/impl/InboxWithSlotOptimization.sol";

/// @title InboxGasComparison
/// @notice Compares gas usage between InboxBase and InboxWithSlotOptimization
/// @dev Focus on the most common case: single claim per proposal (default slot usage)
contract InboxGasComparison is ShastaInboxTestBase {
    
    TestInboxBase inboxBase;
    TestInboxOptimized inboxOptimized;
    
    // Test data
    IInbox.Proposal[] proposals;
    IInbox.Claim[] claims;
    bytes proofData;
    
    function setUp() public override {
        super.setUp();
        
        // Deploy both implementations
        inboxBase = TestInboxBase(deployInboxBase());
        inboxOptimized = TestInboxOptimized(deployInboxOptimized());
        
        // Prepare test data for single claim per proposal
        _prepareTestData();
        
        // IMPORTANT: Warm up the ring buffer by filling it once
        // This ensures we're comparing warm storage writes (non-zero to non-zero)
        // rather than cold storage writes (zero to non-zero)
        _warmUpRingBuffer(address(inboxBase));
        _warmUpRingBuffer(address(inboxOptimized));
    }
    
    /// @notice Test gas usage for prove with single claim (default slot optimization case)
    /// @dev This represents the most common scenario where each proposal has only one claim
    function test_gas_comparison_single_claim_per_proposal() public {
        console2.log("=== Gas Comparison: Single Claim Per Proposal ===");
        console2.log("");
        
        // Test with different numbers of proposals to see scaling
        uint256[] memory proposalCounts = new uint256[](4);
        proposalCounts[0] = 1;
        proposalCounts[1] = 5;
        proposalCounts[2] = 10;
        proposalCounts[3] = 20;
        
        for (uint256 i = 0; i < proposalCounts.length; i++) {
            uint256 count = proposalCounts[i];
            console2.log("Testing with", count, "proposal(s):");
            
            // Prepare proposals and claims for this test
            (IInbox.Proposal[] memory testProposals, IInbox.Claim[] memory testClaims) = 
                _prepareProposalsAndClaims(count);
            
            // Test InboxBase
            uint256 gasBase = _measureProveGas(address(inboxBase), testProposals, testClaims);
            
            // Test InboxWithSlotOptimization  
            uint256 gasOptimized = _measureProveGas(address(inboxOptimized), testProposals, testClaims);
            
            // Calculate savings
            uint256 gasSaved = gasBase > gasOptimized ? gasBase - gasOptimized : 0;
            uint256 percentSaved = gasBase > 0 ? (gasSaved * 100) / gasBase : 0;
            
            console2.log("  InboxBase gas used:", gasBase);
            console2.log("  InboxOptimized gas used:", gasOptimized);
            console2.log("  Gas saved:", gasSaved);
            console2.log("  Percent saved:", percentSaved, "%");
            console2.log("");
        }
    }
    
    /// @notice Test gas usage for storage operations in prove function
    /// @dev Isolates the storage write operations to see the optimization impact
    function test_gas_comparison_storage_operations() public {
        console2.log("=== Gas Comparison: Storage Operations ===");
        console2.log("");
        
        // Single proposal and claim for isolated testing
        (IInbox.Proposal[] memory testProposals, IInbox.Claim[] memory testClaims) = 
            _prepareProposalsAndClaims(1);
        
        // Measure gas for just the storage operations
        uint256 gasBaseStorage = _measureStorageGas(address(inboxBase), testProposals[0], testClaims[0]);
        uint256 gasOptimizedStorage = _measureStorageGas(address(inboxOptimized), testProposals[0], testClaims[0]);
        
        console2.log("Storage operation gas comparison:");
        console2.log("  InboxBase storage gas:", gasBaseStorage);
        console2.log("  InboxOptimized storage gas:", gasOptimizedStorage);
        console2.log("  Gas saved:", gasBaseStorage > gasOptimizedStorage ? gasBaseStorage - gasOptimizedStorage : 0);
        console2.log("");
        
        // Test multiple writes to same proposal (should show optimization benefit)
        console2.log("Multiple writes to same proposal (updating claims):");
        uint256 gasBaseMultiple = _measureMultipleWrites(address(inboxBase), testProposals[0]);
        uint256 gasOptimizedMultiple = _measureMultipleWrites(address(inboxOptimized), testProposals[0]);
        
        console2.log("  InboxBase multiple writes gas:", gasBaseMultiple);
        console2.log("  InboxOptimized multiple writes gas:", gasOptimizedMultiple);
        console2.log("  Gas saved:", gasBaseMultiple > gasOptimizedMultiple ? gasBaseMultiple - gasOptimizedMultiple : 0);
    }
    
    // ---------------------------------------------------------------
    // Helper Functions
    // ---------------------------------------------------------------
    
    function _warmUpRingBuffer(address inboxImpl) private {
        // Fill the ring buffer once to warm up all storage slots
        // This simulates a realistic scenario where the inbox has been used before
        uint256 ringBufferSize = defaultConfig.ringBufferSize;
        
        for (uint256 i = 0; i < ringBufferSize; i++) {
            // Create dummy proposal and claim
            IInbox.Proposal memory warmupProposal = IInbox.Proposal({
                id: uint48(i + 1),
                proposer: Alice,
                originTimestamp: uint48(block.timestamp),
                originBlockNumber: uint48(block.number),
                isForcedInclusion: false,
                basefeeSharingPctg: 10,
                provabilityBondGwei: DEFAULT_PROVABILITY_BOND,
                livenessBondGwei: DEFAULT_LIVENESS_BOND,
                blobSlice: createValidBlobSlice(i)
            });
            
            bytes32 proposalHash = keccak256(abi.encode(warmupProposal));
            bytes32 parentClaimHash = keccak256(abi.encode("parent", i));
            bytes32 claimRecordHash = keccak256(abi.encode("claim", i));
            
            // Store proposal and claim to warm up the slots
            if (inboxImpl == address(inboxBase)) {
                TestInboxBase(inboxImpl).exposed_setProposalHash(warmupProposal.id, proposalHash);
                TestInboxBase(inboxImpl).exposed_setClaimRecordHash(
                    warmupProposal.id,
                    parentClaimHash,
                    claimRecordHash
                );
            } else {
                TestInboxOptimized(inboxImpl).exposed_setProposalHash(warmupProposal.id, proposalHash);
                TestInboxOptimized(inboxImpl).exposed_setClaimRecordHash(
                    warmupProposal.id,
                    parentClaimHash,
                    claimRecordHash
                );
            }
        }
        
        // Now the ring buffer is full and all slots are warm
        // The next writes will overwrite existing data (warm writes)
    }
    
    function createValidBlobSlice(uint256 index) private view returns (LibBlobs.BlobSlice memory) {
        bytes32[] memory blobHashes = new bytes32[](1);
        blobHashes[0] = keccak256(abi.encode("blob", index));
        
        return LibBlobs.BlobSlice({
            blobHashes: blobHashes,
            offset: 0,
            timestamp: uint48(block.timestamp)
        });
    }
    
    function deployInboxBase() private returns (address) {
        TestInboxBase impl = new TestInboxBase();
        bytes memory initData = abi.encodeWithSelector(
            bytes4(keccak256("init(address,bytes32)")), 
            address(this), 
            GENESIS_BLOCK_HASH
        );
        TestInboxBase proxy = TestInboxBase(deployProxy(address(impl), initData));
        proxy.setConfig(defaultConfig);
        return address(proxy);
    }
    
    function deployInboxOptimized() private returns (address) {
        TestInboxOptimized impl = new TestInboxOptimized();
        bytes memory initData = abi.encodeWithSelector(
            bytes4(keccak256("init(address,bytes32)")), 
            address(this), 
            GENESIS_BLOCK_HASH
        );
        TestInboxOptimized proxy = TestInboxOptimized(deployProxy(address(impl), initData));
        proxy.setConfig(defaultConfig);
        return address(proxy);
    }
    
    function _prepareTestData() private {
        // Create a valid proof that will pass verification
        proofData = abi.encode("valid_proof");
        
        // Mock the proof verifier to accept our proof
        vm.mockCall(
            proofVerifier,
            abi.encodeWithSelector(IProofVerifier.verifyProof.selector),
            abi.encode(true)
        );
    }
    
    function _prepareProposalsAndClaims(uint256 count) 
        private 
        view
        returns (IInbox.Proposal[] memory, IInbox.Claim[] memory) 
    {
        IInbox.Proposal[] memory props = new IInbox.Proposal[](count);
        IInbox.Claim[] memory clms = new IInbox.Claim[](count);
        
        for (uint256 i = 0; i < count; i++) {
            // Create proposal - use IDs that will overwrite warmed slots
            // After warmup, we filled slots 0-99, so we start at 101 to wrap around
            props[i] = IInbox.Proposal({
                id: uint48(101 + i),
                proposer: Alice,
                originTimestamp: uint48(block.timestamp),
                originBlockNumber: uint48(block.number),
                isForcedInclusion: false,
                basefeeSharingPctg: 10,
                provabilityBondGwei: DEFAULT_PROVABILITY_BOND,
                livenessBondGwei: DEFAULT_LIVENESS_BOND,
                blobSlice: createValidBlobSlice(i)
            });
            
            // Create claim with same parent (optimizes to default slot)
            clms[i] = IInbox.Claim({
                proposalHash: keccak256(abi.encode(props[i])),
                parentClaimHash: i == 0 ? 
                    keccak256(abi.encode(IInbox.Claim({
                        proposalHash: bytes32(0),
                        parentClaimHash: bytes32(0),
                        endBlockNumber: 0,
                        endBlockHash: GENESIS_BLOCK_HASH,
                        endStateRoot: bytes32(0),
                        actualProver: address(0),
                        designatedProver: address(0)
                    }))) : 
                    keccak256(abi.encode(clms[i-1])),
                endBlockNumber: uint48((i + 1) * 100),
                endBlockHash: keccak256(abi.encode("block", i)),
                endStateRoot: keccak256(abi.encode("state", i)),
                actualProver: Bob,
                designatedProver: Alice
            });
        }
        
        return (props, clms);
    }
    
    function _measureProveGas(
        address inboxImpl,
        IInbox.Proposal[] memory props,
        IInbox.Claim[] memory clms
    ) private returns (uint256) {
        // First, setup the proposals
        for (uint256 i = 0; i < props.length; i++) {
            _setupProposal(inboxImpl, props[i]);
        }
        
        // Encode prove data
        bytes memory proveData = abi.encode(props, clms);
        
        // Measure gas for prove
        vm.prank(Bob);
        uint256 gasBefore = gasleft();
        (bool success,) = inboxImpl.call(
            abi.encodeWithSelector(IInbox.prove.selector, proveData, proofData)
        );
        uint256 gasAfter = gasleft();
        require(success, "Prove failed");
        
        return gasBefore - gasAfter;
    }
    
    function _measureStorageGas(
        address inboxImpl,
        IInbox.Proposal memory proposal,
        IInbox.Claim memory claim
    ) private returns (uint256) {
        // Setup proposal first
        _setupProposal(inboxImpl, proposal);
        
        // Measure just the setClaimRecordHash operation
        if (inboxImpl == address(inboxBase)) {
            TestInboxBase impl = TestInboxBase(inboxImpl);
            uint256 gasBefore = gasleft();
            impl.exposed_setClaimRecordHash(
                proposal.id,
                claim.parentClaimHash,
                keccak256(abi.encode(claim))
            );
            uint256 gasAfter = gasleft();
            return gasBefore - gasAfter;
        } else {
            TestInboxOptimized impl = TestInboxOptimized(inboxImpl);
            uint256 gasBefore = gasleft();
            impl.exposed_setClaimRecordHash(
                proposal.id,
                claim.parentClaimHash,
                keccak256(abi.encode(claim))
            );
            uint256 gasAfter = gasleft();
            return gasBefore - gasAfter;
        }
    }
    
    function _measureMultipleWrites(
        address inboxImpl,
        IInbox.Proposal memory proposal
    ) private returns (uint256 totalGas) {
        _setupProposal(inboxImpl, proposal);
        
        // Write multiple times to same proposal (simulating updates)
        for (uint256 i = 0; i < 3; i++) {
            bytes32 claimHash = keccak256(abi.encode("claim", i));
            
            if (inboxImpl == address(inboxBase)) {
                TestInboxBase impl = TestInboxBase(inboxImpl);
                uint256 gasBefore = gasleft();
                impl.exposed_setClaimRecordHash(
                    proposal.id,
                    keccak256(abi.encode(proposal)), // Same parent for all
                    claimHash
                );
                uint256 gasAfter = gasleft();
                totalGas += gasBefore - gasAfter;
            } else {
                TestInboxOptimized impl = TestInboxOptimized(inboxImpl);
                uint256 gasBefore = gasleft();
                impl.exposed_setClaimRecordHash(
                    proposal.id,
                    keccak256(abi.encode(proposal)), // Same parent for all
                    claimHash
                );
                uint256 gasAfter = gasleft();
                totalGas += gasBefore - gasAfter;
            }
        }
    }
    
    function _setupProposal(address inboxImpl, IInbox.Proposal memory proposal) private {
        // Store the proposal hash in the inbox
        if (inboxImpl == address(inboxBase)) {
            TestInboxBase(inboxImpl).exposed_setProposalHash(
                proposal.id,
                keccak256(abi.encode(proposal))
            );
        } else {
            TestInboxOptimized(inboxImpl).exposed_setProposalHash(
                proposal.id,
                keccak256(abi.encode(proposal))
            );
        }
    }
}

// Test contract for InboxBase
contract TestInboxBase is InboxBase {
    IInbox.Config private _config;
    
    function setConfig(IInbox.Config memory config) external {
        _config = config;
    }
    
    function getConfig() public view override returns (IInbox.Config memory) {
        return _config;
    }
    
    // Expose internal functions for testing
    function exposed_setClaimRecordHash(
        uint48 proposalId,
        bytes32 parentClaimHash,
        bytes32 claimRecordHash
    ) external {
        _setClaimRecordHash(_config, proposalId, parentClaimHash, claimRecordHash);
    }
    
    function exposed_setProposalHash(
        uint48 proposalId,
        bytes32 proposalHash
    ) external {
        _setProposalHash(_config, proposalId, proposalHash);
    }
}

// Test contract for InboxWithSlotOptimization  
contract TestInboxOptimized is InboxWithSlotOptimization {
    IInbox.Config private _config;
    
    function setConfig(IInbox.Config memory config) external {
        _config = config;
    }
    
    function getConfig() public view override returns (IInbox.Config memory) {
        return _config;
    }
    
    // Expose internal functions for testing
    function exposed_setClaimRecordHash(
        uint48 proposalId,
        bytes32 parentClaimHash,
        bytes32 claimRecordHash
    ) external {
        _setClaimRecordHash(_config, proposalId, parentClaimHash, claimRecordHash);
    }
    
    function exposed_setProposalHash(
        uint48 proposalId,
        bytes32 proposalHash
    ) external {
        _setProposalHash(_config, proposalId, proposalHash);
    }
}