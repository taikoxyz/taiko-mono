// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../../TaikoTest.sol";

contract MockMerkleClaimable is MerkleClaimable {
    function init(uint64 _claimStart, uint64 _claimEnd, bytes32 _merkleRoot) external initializer {
        __MerkleClaimable_init(_claimStart, _claimEnd, _merkleRoot);
    }

    function verifyClaim(bytes calldata data, bytes32[] calldata proof) external {
        _verifyClaim(data, proof);
    }
}

contract TestMerkleClaimable is TaikoTest {
    bytes public data = abi.encode(Alice, 100);

    bytes32 public constant merkleRoot =
        0x73a7330a8657ad864b954215a8f636bb3709d2edea60bcd4fcb8a448dbc6d70f;
    bytes32[] public merkleProof;
    uint64 public claimStart;
    uint64 public claimEnd;

    MockMerkleClaimable public merkleClaimable;

    function setUp() public {
        claimStart = uint64(block.timestamp + 10);
        claimEnd = uint64(block.timestamp + 10_000);

        merkleProof = new bytes32[](3);
        merkleProof[0] = 0x4014b456db813d18e801fe3b30bbe14542c9c84caa9a92b643f7f46849283077;
        merkleProof[1] = 0xfc2f09b34fb9437f9bde16049237a2ab3caa6d772bd794da57a8c314aea22b3f;
        merkleProof[2] = 0xc13844b93533d8aec9c7c86a3d9399efb4e834f4069b9fd8a88e7290be612d05;

        merkleClaimable = MockMerkleClaimable(
            deployProxy({
                name: "MockMerkleClaimable",
                impl: address(new MockMerkleClaimable()),
                data: abi.encodeCall(MockMerkleClaimable.init, (0, 0, merkleRoot))
            })
        );

        vm.startPrank(merkleClaimable.owner());
        merkleClaimable.setConfig(claimStart, claimEnd, merkleRoot);

        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 12);
    }

    function test_verifyClaim_when_it_starts() public {
        vm.warp(claimStart);
        merkleClaimable.verifyClaim(data, merkleProof);
    }

    function test_verifyClaim_before_it_starts() public {
        vm.warp(claimStart - 1);
        vm.expectRevert(MerkleClaimable.CLAIM_NOT_ONGOING.selector);
        merkleClaimable.verifyClaim(data, merkleProof);
    }

    function test_verifyClaim_when_it_ends() public {
        vm.warp(claimEnd);
        merkleClaimable.verifyClaim(data, merkleProof);
    }

    function test_verifyClaim_after_it_ends() public {
        vm.warp(claimEnd + 1);
        vm.expectRevert(MerkleClaimable.CLAIM_NOT_ONGOING.selector);
        merkleClaimable.verifyClaim(data, merkleProof);
    }

    function test_verifyClaim_twice_while_its_ongoing() public {
        vm.warp(claimStart);
        merkleClaimable.verifyClaim(data, merkleProof);

        vm.expectRevert(MerkleClaimable.CLAIMED_ALREADY.selector);
        merkleClaimable.verifyClaim(data, merkleProof);
    }

    function test_verifyClaim_with_invalid_proofs_while_its_ongoing() public {
        vm.warp(claimStart);
        merkleProof[1] = randBytes32();
        vm.expectRevert(MerkleClaimable.INVALID_PROOF.selector);
        merkleClaimable.verifyClaim(data, merkleProof);
    }
}
