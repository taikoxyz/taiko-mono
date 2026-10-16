// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../CommonTest.sol";
import "src/shared/libs/LibEtnaRewards.sol";
import "src/shared/libs/LibTrieProof.sol";
import "test/shared/EtnaRewardProof.sol";

contract EtnaRewardProofHarness {
    /// @notice Verifies an account and storage proof through the production trie proof library.
    /// @param _root The state root authenticated by the proof.
    /// @param _inbox The account address committed in the state trie.
    /// @param _slot The storage slot committed in the storage trie.
    /// @param _value The storage value committed in the storage trie.
    /// @param _account The account proof nodes.
    /// @param _storage The storage proof nodes.
    /// @return storageRoot_ The authenticated storage root.
    function verify(
        bytes32 _root,
        address _inbox,
        bytes32 _slot,
        bytes32 _value,
        bytes[] memory _account,
        bytes[] memory _storage
    )
        external
        pure
        returns (bytes32 storageRoot_)
    {
        return LibTrieProof.verifyMerkleProof(_root, _inbox, _slot, _value, _account, _storage);
    }
}

contract LibEtnaRewardsTest is CommonTest {
    /// @notice Checks that every chain and range identity field changes the batch identifier.
    function test_batchIdBindsChainInboxGenerationRangeAndEndHash() external pure {
        LibEtnaRewards.Receipt memory r = _receipt();
        bytes32 id = LibEtnaRewards.batchId(r);

        r.l1ChainId++;
        assertTrue(LibEtnaRewards.batchId(r) != id);
        r = _receipt();
        r.l2ChainId++;
        assertTrue(LibEtnaRewards.batchId(r) != id);
        r = _receipt();
        r.inbox = address(0x1234);
        assertTrue(LibEtnaRewards.batchId(r) != id);
        r = _receipt();
        r.generation++;
        assertTrue(LibEtnaRewards.batchId(r) != id);
        r = _receipt();
        r.parentHeight++;
        assertTrue(LibEtnaRewards.batchId(r) != id);
        r = _receipt();
        r.parentHash = bytes32(uint256(r.parentHash) + 1);
        assertTrue(LibEtnaRewards.batchId(r) != id);
        r = _receipt();
        r.lastHeight++;
        assertTrue(LibEtnaRewards.batchId(r) != id);
        r = _receipt();
        r.lastBlockHash = bytes32(uint256(r.lastBlockHash) + 1);
        assertTrue(LibEtnaRewards.batchId(r) != id);
    }

    /// @notice Checks that reward details change the receipt commitment without changing its batch.
    function test_commitmentBindsRecipientAndAmountWithoutChangingBatchId() external pure {
        LibEtnaRewards.Receipt memory r = _receipt();
        bytes32 id = LibEtnaRewards.batchId(r);
        bytes32 hash = LibEtnaRewards.commitment(r);

        r.l2RewardRecipient = address(0x5678);
        assertEq(LibEtnaRewards.batchId(r), id);
        assertTrue(LibEtnaRewards.commitment(r) != hash);

        r = _receipt();
        r.baseFeeAmount++;
        assertEq(LibEtnaRewards.batchId(r), id);
        assertTrue(LibEtnaRewards.commitment(r) != hash);
    }

    /// @notice Checks that receipt storage slots match an independent mapping-slot calculation.
    function test_receiptSlotMatchesIndependentMappingSlotCast() external pure {
        bytes32 id = keccak256("batch");
        bytes32 expected = keccak256(abi.encode(id, uint256(283)));
        assertEq(LibEtnaRewards.receiptSlot(id), expected);
    }

    /// @notice Checks a real single-leaf proof and confirms that corrupting its node is rejected.
    function test_proofHelperBuildsValidSingleLeafStorageProof() external {
        address inbox = address(0x1234);
        bytes32 slot = keccak256("receipt slot");
        bytes32 value = keccak256("receipt value");
        (bytes32 root, bytes[] memory account, bytes[] memory storageProof) =
            EtnaRewardProof._proof(inbox, slot, value);
        EtnaRewardProofHarness harness = new EtnaRewardProofHarness();

        harness.verify(root, inbox, slot, value, account, storageProof);

        account[0][account[0].length - 1] ^= 0x01;
        vm.expectRevert();
        harness.verify(root, inbox, slot, value, account, storageProof);
    }

    /// @dev Returns a representative receipt used to test canonical batch and receipt encoding.
    function _receipt() private pure returns (LibEtnaRewards.Receipt memory r) {
        r = LibEtnaRewards.Receipt({
            l1ChainId: 1,
            l2ChainId: 167_000,
            inbox: address(0x1111),
            generation: 2,
            parentHeight: 100,
            parentHash: keccak256("parent"),
            lastHeight: 200,
            lastBlockHash: keccak256("last"),
            l2RewardRecipient: address(0x2222),
            baseFeeAmount: 3 ether
        });
    }
}
