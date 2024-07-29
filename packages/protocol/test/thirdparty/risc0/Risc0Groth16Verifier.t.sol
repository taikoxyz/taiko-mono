// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../../L1/TaikoL1TestBase.sol";
import "../../../contracts/thirdparty/risczero/groth16/RiscZeroGroth16Verifier.sol";
import "../../../contracts/thirdparty/risczero/groth16/ControlID.sol";

import "forge-std/src/console2.sol";

contract RiscZeroGroth16VerifierTest is TaikoL1TestBase {
    function deployTaikoL1() internal override returns (TaikoL1) {
        return
            TaikoL1(payable(deployProxy({ name: "taiko", impl: address(new TaikoL1()), data: "" })));
    }

    function setUp() public override {
        vm.startPrank(Emma);
        // Call the TaikoL1TestBase setUp()
        super.setUp();

        RiscZeroGroth16Verifier verifier =
            new RiscZeroGroth16Verifier(ControlID.CONTROL_ROOT, ControlID.BN254_CONTROL_ID);
        console2.log("Deployed RiscZeroGroth16Verifier to", address(verifier));

        // Deploy Taiko's RiscZero proof verifier
        rv = RiscZeroVerifier(
            deployProxy({
                name: "tier_risc_zero",
                impl: address(new RiscZeroVerifier()),
                data: abi.encodeCall(
                    RiscZeroVerifier.init, (address(0), address(addressManager), address(verifier))
                )
            })
        );

        rv.setImageIdTrusted(
            bytes32(0x4f6beb0c538971a81491c22de3995c82e6fd7938d5090366d7b618d5f6df504d), true
        );

        registerAddress("risc_zero_verifier", address(rv));
    }

    // Test `verifyProof()` happy path
    function test_risc0_groth16_verifyProof() external {
        vm.stopPrank();

        // Caller not necessary has to be TaikoL1 contract because there is no keys (as in SGX keys)
        // to be front run.
        vm.startPrank(Emma);

        bytes memory seal =
            hex"310fe59815ffa3b596af0bdccd0aaa064495d5db94fe367414d3a9212c8ce17383717e531ced511d89956c7c8aa0cc8531dac8660093581c5ae19c48a39fc14fd98dc1050684083592dab0fd9a2482c47ab4833c4f9b9a6770a7ce439a4f0e94bc035809138a7566873e34d202708ce4858665202417e645aeb299d4f7633fead7c667562b9104bdc79a0c379145ca2431598beec20b75a722915ff0a872771652583f9206e75bd317e73b1af7705f70aa52c30bc33ea6792b9e080177502fe074b87beb1add2ebe112c7bd17667a418fd9ef6d8e89e606c5efff14b5df24f7aa40c5c4f2bcaaa6f206d2d1e15356c533c5210258a6f1b1d1d22cb63cff0323863d7fe3b";
        bytes32 imageId =
            bytes32(0x4f6beb0c538971a81491c22de3995c82e6fd7938d5090366d7b618d5f6df504d);
        bytes32 journalDigest =
            bytes32(0xa82287ae36a69b51f8013851b3814ff1243da5dfa071f6fd9b46b85445895553);

        // TierProof
        TaikoData.TierProof memory proof =
            TaikoData.TierProof({ tier: 100, data: abi.encode(seal, imageId, journalDigest) });

        vm.warp(block.timestamp + 5);

        (IVerifier.Context memory ctx, TaikoData.Transition memory transition) =
            _generateTaikoMainnetContextAndTransition();

        uint64 chainId = L1.getConfig().chainId;
        bytes32 pi = LibPublicInput.hashPublicInputs(
            transition, address(rv), address(0), ctx.prover, ctx.metaHash, chainId
        );
        bytes memory header = hex"20000000"; // [32, 0, 0, 0] -- big-endian uint32(32) for hash
            // bytes len
        assert(sha256(bytes.concat(header, pi)) == journalDigest);

        // `verifyProof()`
        rv.verifyProof(ctx, transition, proof);

        vm.stopPrank();
    }

    function _generateTaikoMainnetContextAndTransition()
        internal
        pure
        returns (IVerifier.Context memory ctx, TaikoData.Transition memory transition)
    {
        // Context
        ctx = IVerifier.Context({
            metaHash: bytes32(0xd7efb262f6f25cc817452a622009a22e5868e53e1f934d899d3ec68d8c4f2c5b),
            blobHash: bytes32(0x015cc9688f24b8d2195e46829b3f726ce006884d5fd2760b7cf414bab9a1b231),
            prover: address(0x70997970C51812dc3A010C7d01b50e0d17dc79C8),
            msgSender: address(0),
            blockId: 223_248, //from mainnet
            isContesting: false,
            blobUsed: true
        });

        // Transition
        transition = TaikoData.Transition({
            parentHash: 0x317de24b32f09629524133334ad552a14e3de603d71a9cf9e88d722809f101b3,
            blockHash: 0x9966d3cf051d3d1e44e2a740169627506a619257c95374e812ca572de91ed885,
            stateRoot: 0x3ae3de1afa16b93a5c7ea20a0b36b43357061f5b8ef857053d68b2735c3df860,
            graffiti: 0x8008500000000000000000000000000000000000000000000000000000000000
        });
    }
}
