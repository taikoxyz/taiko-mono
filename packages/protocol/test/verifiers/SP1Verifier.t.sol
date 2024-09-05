// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import "../L1/TaikoL1TestBase.sol";

contract MockSP1Gateway is ISP1Verifier {
    // To simulate failing and succeeding
    bool public verifying;

    error SP1_INVALID_PROOF();

    function setVerifying(bool _verifying) public {
        verifying = _verifying;
    }

    function verifyProof(
        bytes32, /*programVKey*/
        bytes calldata, /*publicValues*/
        bytes calldata /*proofBytes*/
    )
        external
        view
    {
        require(verifying, "SP1Verifier: invalid proof");
    }
}

contract TestSP1Verifier is TaikoL1TestBase {
    MockSP1Gateway sp1Gateway;

    function deployTaikoL1() internal override returns (TaikoL1) {
        return
            TaikoL1(payable(deployProxy({ name: "taiko", impl: address(new TaikoL1()), data: "" })));
    }

    function setUp() public override {
        // Call the TaikoL1TestBase setUp()
        super.setUp();

        sp1Gateway = new MockSP1Gateway();
        sp1Gateway.setVerifying(true);

        // Deploy Taiko's SP1 proof verifier ('remitter')
        sp1 = SP1Verifier(
            deployProxy({
                name: "tier_zkvm_sp1",
                impl: address(new SP1Verifier()),
                data: abi.encodeCall(SP1Verifier.init, (address(0), address(addressManager)))
            })
        );

        sp1.setProgramTrusted(bytes32("105"), true);

        registerAddress("sp1_verifier", address(sp1));
        registerAddress("sp1_remote_verifier", address(sp1Gateway));
    }

    // Test `verifyProof()` happy path
    function test_verifyProof() external {
        vm.stopPrank();

        // Caller not necessary has to be TaikoL1 contract because there is no keys (as in SGX keys)
        // to be front run.
        vm.startPrank(Alice);

        bytes32 programVKey = bytes32("105");
        bytes memory sp1Proof = hex"00";

        // TierProof
        TaikoData.TierProof memory proof =
            TaikoData.TierProof({ tier: 100, data: abi.encode(programVKey, sp1Proof) });

        vm.warp(block.timestamp + 5);

        (IVerifier.Context memory ctx, TaikoData.Transition memory transition) =
            _getDummyContextAndTransition();

        // `verifyProof()`
        sp1.verifyProof(ctx, transition, proof);

        vm.stopPrank();
    }

    function test_verifyProof_invalidProgramVKeyd() external {
        vm.stopPrank();

        // Caller not necessary has to be TaikoL1 contract because there is no keys (as in SGX keys)
        // to be front run.
        vm.startPrank(Alice);

        bytes32 programVKey = bytes32("101");
        bytes memory sp1Proof = hex"00";

        // TierProof
        TaikoData.TierProof memory proof =
            TaikoData.TierProof({ tier: 100, data: abi.encode(programVKey, sp1Proof) });

        vm.warp(block.timestamp + 5);

        (IVerifier.Context memory ctx, TaikoData.Transition memory transition) =
            _getDummyContextAndTransition();

        // `verifyProof()`
        vm.expectRevert(SP1Verifier.SP1_INVALID_PROGRAM_VKEY.selector);
        sp1.verifyProof(ctx, transition, proof);

        vm.stopPrank();
    }

    function test_verifyProof_invalidProof() external {
        sp1Gateway.setVerifying(false);
        vm.stopPrank();

        // Caller not necessary has to be TaikoL1 contract because there is no keys (as in SGX keys)
        // to be front run.
        vm.startPrank(Alice);

        bytes32 programVKey = bytes32("105");
        bytes memory sp1Proof = hex"00";

        // TierProof
        TaikoData.TierProof memory proof =
            TaikoData.TierProof({ tier: 100, data: abi.encode(programVKey, sp1Proof) });

        vm.warp(block.timestamp + 5);

        (IVerifier.Context memory ctx, TaikoData.Transition memory transition) =
            _getDummyContextAndTransition();

        vm.expectRevert(SP1Verifier.SP1_INVALID_PROOF.selector);
        sp1.verifyProof(ctx, transition, proof);

        vm.stopPrank();
    }

    function _getDummyContextAndTransition()
        internal
        pure
        returns (IVerifier.Context memory ctx, TaikoData.Transition memory transition)
    {
        // Context
        ctx = IVerifier.Context({
            metaHash: bytes32("ab"),
            blobHash: bytes32("cd"),
            prover: address(0),
            msgSender: address(0),
            blockId: 10,
            isContesting: false,
            blobUsed: false
        });

        // Transition
        transition = TaikoData.Transition({
            parentHash: bytes32("12"),
            blockHash: bytes32("34"),
            stateRoot: bytes32("56"),
            graffiti: bytes32("78")
        });
    }
}
