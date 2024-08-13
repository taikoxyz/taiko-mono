// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../TaikoTest.sol";

contract TestL2ForTest is TaikoL2 {
    function setGasExcess(uint64 _newGasExcess) external virtual onlyOwner {
        parentGasExcess = _newGasExcess;
    }
}

contract SkipBasefeeCheckL2 is TestL2ForTest {
    function skipFeeCheck() internal pure override returns (bool) {
        return true;
    }
}

contract TestTaikoL2 is TaikoTest {
    using SafeCast for uint256;

    // Initial salt for semi-random generation
    uint256 salt = 2_195_684_615_435_261_315_311;
    // same as `block_gas_limit` in foundry.toml
    uint32 public constant BLOCK_GAS_LIMIT = 30_000_000;
    uint32 public constant GAS_ISSUANCE_PER_SECOND = 1_000_000;
    uint8 public constant QUOTIENT = 8;
    uint64 public constant L1_CHAIN_ID = 12_345;

    address public addressManager;
    TestL2ForTest public L2;
    SkipBasefeeCheckL2 public L2skip;

    function setUp() public {
        addressManager = deployProxy({
            name: "address_manager",
            impl: address(new AddressManager()),
            data: abi.encodeCall(AddressManager.init, (address(0)))
        });

        SignalService ss = SignalService(
            deployProxy({
                name: "signal_service",
                impl: address(new SignalService()),
                data: abi.encodeCall(SignalService.init, (address(0), addressManager)),
                registerTo: addressManager
            })
        );

        uint64 gasExcess = 0;

        L2 = TestL2ForTest(
            payable(
                deployProxy({
                    name: "taiko",
                    impl: address(new TestL2ForTest()),
                    data: abi.encodeCall(
                        TaikoL2.init, (address(0), addressManager, L1_CHAIN_ID, gasExcess)
                    ),
                    registerTo: addressManager
                })
            )
        );

        L2.setGasExcess(gasExcess);

        ss.authorize(address(L2), true);

        gasExcess = 195_420_300_100;

        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 30);

        vm.deal(address(L2), 100 ether);
    }

    // calling anchor in the same block more than once should fail
    function test_L2_AnchorTx_revert_in_same_block() external {
        vm.fee(1);

        vm.prank(L2.GOLDEN_TOUCH_ADDRESS());
        _anchor();

        vm.prank(L2.GOLDEN_TOUCH_ADDRESS());
        vm.expectRevert(); // L2_PUBLIC_INPUT_HASH_MISMATCH
        _anchor();
    }

    // calling anchor in the same block more than once should fail
    function test_L2_AnchorTx_revert_from_wrong_signer() external {
        vm.fee(1);
        vm.expectRevert();
        _anchor();
    }

    function test_L2_AnchorTx_signing(bytes32 digest) external {
        (uint8 v, uint256 r, uint256 s) = LibL2Signer.signAnchor(digest, uint8(1));
        address signer = ecrecover(digest, v + 27, bytes32(r), bytes32(s));
        assertEq(signer, L2.GOLDEN_TOUCH_ADDRESS());

        (v, r, s) = LibL2Signer.signAnchor(digest, uint8(2));
        signer = ecrecover(digest, v + 27, bytes32(r), bytes32(s));
        assertEq(signer, L2.GOLDEN_TOUCH_ADDRESS());

        vm.expectRevert();
        LibL2Signer.signAnchor(digest, uint8(0));

        vm.expectRevert();
        LibL2Signer.signAnchor(digest, uint8(3));
    }

    function test_L2_withdraw() external {
        vm.prank(L2.owner(), L2.owner());
        L2.withdraw(address(0), Alice);
        assertEq(address(L2).balance, 0 ether);
        assertEq(Alice.balance, 100 ether);

        // Random EOA cannot call withdraw
        vm.expectRevert();
        vm.prank(Alice, Alice);
        L2.withdraw(address(0), Alice);
    }

    function test_L2_getBlockHash() external {
        assertEq(L2.getBlockHash(uint64(1000)), 0);
    }

    function _anchor() private {
        bytes32 l1StateRoot = randBytes32();
        L2.anchorV2(12_345, l1StateRoot, BLOCK_GAS_LIMIT, GAS_ISSUANCE_PER_SECOND, QUOTIENT);
    }
}
