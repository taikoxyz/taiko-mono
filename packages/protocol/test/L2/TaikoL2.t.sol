// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../TaikoTest.sol";

contract SkipBasefeeCheckL2 is TaikoL2EIP1559Configurable {
    function skipFeeCheck() public pure override returns (bool) {
        return true;
    }
}

contract TestTaikoL2 is TaikoTest {
    using SafeCast for uint256;

    // Initial salt for semi-random generation
    uint256 salt = 2_195_684_615_435_261_315_311;
    // same as `block_gas_limit` in foundry.toml
    uint32 public constant BLOCK_GAS_LIMIT = 30_000_000;

    address public addressManager;
    TaikoL2EIP1559Configurable public L2;
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
        uint8 quotient = 8;
        uint32 gasTarget = 60_000_000;
        uint64 l1ChainId = 12_345;

        L2 = TaikoL2EIP1559Configurable(
            payable(
                deployProxy({
                    name: "taiko",
                    impl: address(new TaikoL2EIP1559Configurable()),
                    data: abi.encodeCall(
                        TaikoL2.init, (address(0), addressManager, l1ChainId, gasExcess)
                        ),
                    registerTo: addressManager
                })
            )
        );

        L2.setConfigAndExcess(
            LibL2Config.Config(gasTarget, quotient, uint64(gasTarget) * 300), gasExcess
        );

        ss.authorize(address(L2), true);

        gasExcess = 195_420_300_100;

        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 30);

        vm.deal(address(L2), 100 ether);
    }

    // calling anchor in the same block more than once should fail
    function test_L2_AnchorTx_revert_in_same_block() external {
        vm.fee(40_253_331);

        vm.prank(L2.GOLDEN_TOUCH_ADDRESS());
        _anchor(BLOCK_GAS_LIMIT);

        vm.prank(L2.GOLDEN_TOUCH_ADDRESS());
        vm.expectRevert(); // L2_PUBLIC_INPUT_HASH_MISMATCH
        _anchor(BLOCK_GAS_LIMIT);
    }

    // calling anchor in the same block more than once should fail
    function test_L2_AnchorTx_revert_from_wrong_signer() external {
        vm.fee(1);
        vm.expectRevert();
        _anchor(BLOCK_GAS_LIMIT);
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

    function _anchor(uint32 parentGasLimit) private {
        bytes32 l1Hash = randBytes32();
        bytes32 l1StateRoot = randBytes32();
        L2.anchor(l1Hash, l1StateRoot, 12_345, parentGasLimit);
    }
}
