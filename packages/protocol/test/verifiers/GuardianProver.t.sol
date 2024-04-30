// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../L1/TaikoL1TestBase.sol";

/// @author Kirk Baird <kirk@sigmaprime.io>
contract TestGuardianProver is TaikoL1TestBase {
    function deployTaikoL1() internal override returns (TaikoL1) {
        return
            TaikoL1(payable(deployProxy({ name: "taiko", impl: address(new TaikoL1()), data: "" })));
    }

    function setUp() public override {
        // Call the TaikoL1TestBase setUp()
        super.setUp();
    }

    // Tests `verifyProof()` with the correct prover
    function test_verifyProof() public view {
        // Context
        IVerifier.Context memory ctx = IVerifier.Context({
            metaHash: bytes32(0),
            blobHash: bytes32(0),
            prover: address(gp),
            msgSender: address(gp),
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
        TaikoData.TierProof memory proof =
            TaikoData.TierProof({ tier: LibTiers.TIER_GUARDIAN, data: "" });

        // `verifyProof()`
        gp.verifyProof(ctx, transition, proof);
    }

    // Tests `verifyProof()` with the wrong prover
    function test_verifyProof_invalidProver() public {
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
        TaikoData.TierProof memory proof =
            TaikoData.TierProof({ tier: LibTiers.TIER_GUARDIAN, data: "" });

        // `verifyProof()` with invalid ctx.prover
        vm.expectRevert(GuardianProver.GV_PERMISSION_DENIED.selector);
        gp.verifyProof(ctx, transition, proof);
    }
}
