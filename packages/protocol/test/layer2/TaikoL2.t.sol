// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./TaikoL2Test.sol";

contract TaikoL2ForTest is TaikoL2 {
    function skipFeeCheck() public pure override returns (bool) {
        return true;
    }
}

contract TaikoL2Tests is TaikoL2Test {
    using SafeCast for uint256;

    uint64 public constant L1_CHAIN_ID = 12_345;
    uint32 public constant BLOCK_GAS_LIMIT = 30_000_000;

    address public addressManager;
    uint64 public anchorBlockId;
    TaikoL2ForTest public L2;

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

        L2 = TaikoL2ForTest(
            payable(
                deployProxy({
                    name: "taiko",
                    impl: address(new TaikoL2ForTest()),
                    data: abi.encodeCall(TaikoL2V1.init, (address(0), addressManager, L1_CHAIN_ID, 0)),
                    registerTo: addressManager
                })
            )
        );

        ss.authorize(address(L2), true);
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 30);
        vm.deal(address(L2), 100 ether);
    }

    // calling anchor in the same block more than once should fail
    function test_L2_AnchorTx_revert_in_same_block() external {
        vm.fee(1);

        vm.prank(L2.GOLDEN_TOUCH_ADDRESS());
        _anchorV2(BLOCK_GAS_LIMIT);

        vm.prank(L2.GOLDEN_TOUCH_ADDRESS());
        vm.expectRevert(TaikoL2V1.L2_PUBLIC_INPUT_HASH_MISMATCH.selector);
        _anchorV2(BLOCK_GAS_LIMIT);
    }

    // calling anchor in the same block more than once should fail
    function test_L2_AnchorTx_revert_from_wrong_signer() external {
        vm.fee(1);
        vm.expectRevert(TaikoL2V1.L2_INVALID_SENDER.selector);
        _anchorV2(BLOCK_GAS_LIMIT);
    }

    function test_L2_AnchorTx_signing(bytes32 digest) external {
        (uint8 v, uint256 r, uint256 s) = LibL2Signer.signAnchor(digest, uint8(1));
        address signer = ecrecover(digest, v + 27, bytes32(r), bytes32(s));
        assertEq(signer, L2.GOLDEN_TOUCH_ADDRESS());

        (v, r, s) = LibL2Signer.signAnchor(digest, uint8(2));
        signer = ecrecover(digest, v + 27, bytes32(r), bytes32(s));
        assertEq(signer, L2.GOLDEN_TOUCH_ADDRESS());

        vm.expectRevert(LibL2Signer.L2_INVALID_GOLDEN_TOUCH_K.selector);
        LibL2Signer.signAnchor(digest, uint8(0));

        vm.expectRevert(LibL2Signer.L2_INVALID_GOLDEN_TOUCH_K.selector);
        LibL2Signer.signAnchor(digest, uint8(3));
    }

    function test_L2_withdraw() external {
        vm.prank(L2.owner(), L2.owner());
        L2.withdraw(address(0), Alice);
        assertEq(address(L2).balance, 0 ether);
        assertEq(Alice.balance, 100 ether);

        // Random EOA cannot call withdraw
        vm.expectRevert(AddressResolver.RESOLVER_DENIED.selector);
        vm.prank(Alice, Alice);
        L2.withdraw(address(0), Alice);
    }

    function test_L2_getBlockHash() external {
        assertEq(L2.getBlockHash(uint64(1000)), 0);
    }

    /// forge-config: layer2.fuzz.runs = 2000
    /// forge-config: layer2.fuzz.show-logs = true
    function test_fuzz_getBasefeeV2(
        uint32 _parentGasUsed,
        uint32 _gasIssuancePerSecond,
        uint64 _minGasExcess,
        uint32 _maxGasIssuancePerBlock,
        uint8 _adjustmentQuotient,
        uint8 _sharingPctg
    )
        external
    {
        LibSharedData.BaseFeeConfig memory baseFeeConfig = LibSharedData.BaseFeeConfig({
            adjustmentQuotient: _adjustmentQuotient,
            sharingPctg: uint8(_sharingPctg % 100),
            gasIssuancePerSecond: _gasIssuancePerSecond,
            minGasExcess: _minGasExcess,
            maxGasIssuancePerBlock: _maxGasIssuancePerBlock
        });

        (
            uint256 basefee_,
            uint64 parentGasTarget_,
            uint64 parentGasExcess_,
            bool newGasTargetApplied_
        ) = L2.getBasefeeV2(_parentGasUsed, baseFeeConfig);

        assertTrue(basefee_ != 0, "basefee is 0");
    }

    /// forge-config: layer2.fuzz.runs = 2000
    /// forge-config: layer2.fuzz.show-logs = true
    function test_fuzz_anchorV2(
        uint32 _parentGasUsed,
        uint32 _gasIssuancePerSecond,
        uint64 _minGasExcess,
        uint32 _maxGasIssuancePerBlock,
        uint8 _adjustmentQuotient,
        uint8 _sharingPctg
    )
        external
    {
        if (_parentGasUsed == 0) _parentGasUsed = 1;
        if (_gasIssuancePerSecond == 0) _gasIssuancePerSecond = 1;
        if (_gasIssuancePerSecond == type(uint32).max) _gasIssuancePerSecond -= 1;
        if (_adjustmentQuotient == 0) _adjustmentQuotient = 1;

        LibSharedData.BaseFeeConfig memory baseFeeConfig = LibSharedData.BaseFeeConfig({
            adjustmentQuotient: _adjustmentQuotient,
            sharingPctg: uint8(_sharingPctg % 100),
            gasIssuancePerSecond: _gasIssuancePerSecond,
            minGasExcess: _minGasExcess,
            maxGasIssuancePerBlock: _maxGasIssuancePerBlock
        });

        bytes32 anchorStateRoot = bytes32(uint256(1));
        vm.prank(L2.GOLDEN_TOUCH_ADDRESS());
        L2.anchorV2(++anchorBlockId, anchorStateRoot, _parentGasUsed, baseFeeConfig);

        (
            uint256 basefee_,
            uint64 parentGasTarget_,
            uint64 parentGasExcess_,
            bool newGasTargetApplied_
        ) = L2.getBasefeeV2(_parentGasUsed, baseFeeConfig);

        assertTrue(basefee_ != 0, "basefee is 0");
        assertTrue(!newGasTargetApplied_, "newGasTargetApplied_ is true");

        // change the gas issuance to change the gas target
        baseFeeConfig.gasIssuancePerSecond += 1;

        (basefee_, parentGasTarget_, parentGasExcess_, newGasTargetApplied_) =
            L2.getBasefeeV2(_parentGasUsed, baseFeeConfig);

        assertTrue(basefee_ != 0, "basefee is 0");
        assertTrue(newGasTargetApplied_, "newGasTargetApplied_ is false");
    }

    function _anchorV2(uint32 parentGasUsed) private {
        bytes32 anchorStateRoot = randBytes32();
        LibSharedData.BaseFeeConfig memory baseFeeConfig = LibSharedData.BaseFeeConfig({
            adjustmentQuotient: 8,
            sharingPctg: 75,
            gasIssuancePerSecond: 5_000_000,
            minGasExcess: 1_340_000_000,
            maxGasIssuancePerBlock: 600_000_000 // two minutes
         });
        L2.anchorV2(++anchorBlockId, anchorStateRoot, parentGasUsed, baseFeeConfig);
    }
}
