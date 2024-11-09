// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "test/layer1/Layer1Test.sol";

contract DummyGuardianProver is GuardianProver {
    uint256 public operationId;

    function init() external initializer {
        __Essential_init(address(0));
    }

    function approve(bytes32 hash) external returns (bool) {
        return _saveApproval(operationId++, hash);
    }
}

contract TestGuardianProver is Layer1Test {
    DummyGuardianProver guardianProver;

    function getSigners(uint256 numGuardians) internal returns (address[] memory signers) {
        signers = new address[](numGuardians);
        for (uint256 i = 0; i < numGuardians; ++i) {
            signers[i] = randAddress();
            vm.deal(signers[i], 1 ether);
        }
    }

    function setUpOnEthereum() internal override {
        guardianProver = DummyGuardianProver(
            deploy({
                name: "guardians",
                impl: address(new DummyGuardianProver()),
                data: abi.encodeCall(DummyGuardianProver.init, ())
            })
        );
    }

    function test_guardian_prover_set_guardians() public transactBy(deployer) {
        vm.expectRevert(GuardianProver.GP_INVALID_GUARDIAN_SET.selector);
        guardianProver.setGuardians(getSigners(0), 0, true);

        vm.expectRevert(GuardianProver.GP_INVALID_MIN_GUARDIANS.selector);
        guardianProver.setGuardians(getSigners(5), 0, true);

        vm.expectRevert(GuardianProver.GP_INVALID_MIN_GUARDIANS.selector);
        guardianProver.setGuardians(getSigners(5), 6, true);
    }

    function test_guardian_prover_set_guardians2() public transactBy(deployer) {
        address[] memory signers = getSigners(5);
        signers[0] = address(0);
        vm.expectRevert(GuardianProver.GP_INVALID_GUARDIAN.selector);
        guardianProver.setGuardians(signers, 4, true);

        signers[0] = signers[1];
        vm.expectRevert(GuardianProver.GP_INVALID_GUARDIAN_SET.selector);
        guardianProver.setGuardians(signers, 4, true);
    }

    function test_guardian_prover_approve() public {
        address[] memory signers = getSigners(6);
        vm.prank(deployer);
        guardianProver.setGuardians(signers, 4, true);

        bytes32 hash = keccak256("paris");
        for (uint256 i; i < 6; ++i) {
            vm.prank(signers[0]);
            assertEq(guardianProver.approve(hash), false);
        }

        hash = keccak256("singapore");
        for (uint256 i; i < 6; ++i) {
            vm.startPrank(signers[i]);
            guardianProver.approve(hash);

            assertEq(guardianProver.approve(hash), i >= 3);
            vm.stopPrank();
        }

        // changing the settings will invalid all approval history
        vm.prank(deployer);
        guardianProver.setGuardians(signers, 3, true);
        assertEq(guardianProver.version(), 2);
    }

    // Tests `verifyProof()` with the correct prover
    function test_guardian_prover_verifyProof() public view {
        // Context
        IVerifier.Context memory ctx = IVerifier.Context({
            metaHash: bytes32(0),
            blobHash: bytes32(0),
            prover: address(guardianProver),
            msgSender: address(guardianProver),
            blockId: 10,
            isContesting: false,
            blobUsed: false
        });

        // Transition
        TaikoData.Transition memory transition = TaikoData.Transition({
            parentHash: bytes32(0),
            blockHash: bytes32(0),
            stateRoot: bytes32(0),
            graffiti: bytes32(0)
        });

        // TierProof
        TaikoData.TierProof memory proof = TaikoData.TierProof({ tier: 74, data: "" });

        // `verifyProof()`
        guardianProver.verifyProof(ctx, transition, proof);
    }

    // Tests `verifyProof()` with the wrong prover
    function test_guardian_prover_verifyProof_invalidProver() public {
        // Context
        IVerifier.Context memory ctx = IVerifier.Context({
            metaHash: bytes32(0),
            blobHash: bytes32(0),
            prover: Alice, // invalid
            msgSender: Alice,
            blockId: 10,
            isContesting: false,
            blobUsed: false
        });

        // Transition
        TaikoData.Transition memory transition = TaikoData.Transition({
            parentHash: bytes32(0),
            blockHash: bytes32(0),
            stateRoot: bytes32(0),
            graffiti: bytes32(0)
        });

        // TierProof
        TaikoData.TierProof memory proof = TaikoData.TierProof({ tier: 74, data: "" });

        // `verifyProof()` with invalid ctx.prover
        vm.expectRevert(GuardianProver.GV_PERMISSION_DENIED.selector);
        guardianProver.verifyProof(ctx, transition, proof);
    }
}
