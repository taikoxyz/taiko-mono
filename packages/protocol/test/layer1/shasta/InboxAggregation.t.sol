// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/src/Test.sol";
import { Inbox } from "contracts/layer1/shasta/impl/Inbox.sol";
import { IInbox } from "contracts/layer1/shasta/iface/IInbox.sol";

/// @title InboxAggregationTest
/// @notice Tests for Shasta Inbox aggregation functionality
/// @custom:security-contact security@taiko.xyz
contract InboxAggregationTest is Test {
    Inbox private inbox;
    
    address private constant BOND_MANAGER = address(0x1);
    address private constant SYNCED_BLOCK_MANAGER = address(0x2);
    address private constant PROOF_VERIFIER = address(0x3);
    address private constant PROPOSER_CHECKER = address(0x4);
    address private constant FORCED_INCLUSION_STORE = address(0x5);
    
    function setUp() public {
        inbox = new Inbox(
            1, // provabilityBondGwei
            1, // livenessBondGwei
            100, // provingWindow
            200, // extendedProvingWindow
            1 ether, // minBondBalance
            10, // maxFinalizationCount
            100, // ringBufferSize
            BOND_MANAGER,
            SYNCED_BLOCK_MANAGER,
            PROOF_VERIFIER,
            PROPOSER_CHECKER,
            FORCED_INCLUSION_STORE
        );
        
        inbox.init(address(this), bytes32(uint256(1)));
    }
    
    function test_aggregation_nonConsecutiveProposals() public {
        // Create test data for non-consecutive proposals
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](3);
        IInbox.Claim[] memory claims = new IInbox.Claim[](3);
        
        // Proposal IDs: 1, 3, 5 (non-consecutive)
        proposals[0].id = 1;
        proposals[1].id = 3; 
        proposals[2].id = 5;
        
        // Set up claims
        for (uint256 i = 0; i < 3; i++) {
            claims[i].parentClaimHash = bytes32(uint256(1));
            claims[i].proposalHash = keccak256(abi.encode(proposals[i]));
        }
        
        // Mock the proof verifier to accept any proof
        vm.mockCall(
            PROOF_VERIFIER,
            abi.encodeWithSignature("verifyProof(bytes32,bytes)"),
            abi.encode(true)
        );
        
        // This should NOT revert with non-consecutive proposals
        // They just won't be aggregated together
        bytes memory data = abi.encode(proposals, claims);
        bytes memory proof = "";
        
        // The function should handle non-consecutive proposals gracefully
        // without reverting
        inbox.prove(data, proof);
    }
    
    function test_aggregation_consecutiveProposals() public {
        // Create test data for consecutive proposals
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](3);
        IInbox.Claim[] memory claims = new IInbox.Claim[](3);
        
        // Proposal IDs: 1, 2, 3 (consecutive)
        proposals[0].id = 1;
        proposals[1].id = 2;
        proposals[2].id = 3;
        
        // Set up claims with same parent to allow aggregation
        for (uint256 i = 0; i < 3; i++) {
            claims[i].parentClaimHash = bytes32(uint256(1));
            claims[i].proposalHash = keccak256(abi.encode(proposals[i]));
        }
        
        // Mock the proof verifier
        vm.mockCall(
            PROOF_VERIFIER,
            abi.encodeWithSignature("verifyProof(bytes32,bytes)"),
            abi.encode(true)
        );
        
        bytes memory data = abi.encode(proposals, claims);
        bytes memory proof = "";
        
        // This should succeed and aggregate the consecutive proposals
        inbox.prove(data, proof);
    }
    
    function test_aggregation_mixedProposals() public {
        // Create test data with some consecutive and some non-consecutive
        IInbox.Proposal[] memory proposals = new IInbox.Proposal[](5);
        IInbox.Claim[] memory claims = new IInbox.Claim[](5);
        
        // Proposal IDs: 1, 2, 4, 5, 7 (mixed)
        proposals[0].id = 1;
        proposals[1].id = 2; // consecutive with 1
        proposals[2].id = 4; // not consecutive  
        proposals[3].id = 5; // consecutive with 4
        proposals[4].id = 7; // not consecutive
        
        // Set up claims
        for (uint256 i = 0; i < 5; i++) {
            claims[i].parentClaimHash = bytes32(uint256(1));
            claims[i].proposalHash = keccak256(abi.encode(proposals[i]));
        }
        
        // Mock the proof verifier
        vm.mockCall(
            PROOF_VERIFIER,
            abi.encodeWithSignature("verifyProof(bytes32,bytes)"),
            abi.encode(true)
        );
        
        bytes memory data = abi.encode(proposals, claims);
        bytes memory proof = "";
        
        // Should handle mixed consecutive/non-consecutive gracefully
        // Proposals 1,2 can be aggregated together
        // Proposals 4,5 can be aggregated together
        // Proposal 7 stands alone
        inbox.prove(data, proof);
    }
}