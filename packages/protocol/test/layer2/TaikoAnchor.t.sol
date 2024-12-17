// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./Layer2Test.sol";
import "./helpers/TaikoAnchor_NoBaseFeeCheck.sol";

contract TestTaikoAnchor is Layer2Test {
    uint32 public constant BLOCK_GAS_LIMIT = 30_000_000;

    uint64 public anchorBlockId;
    TaikoAnchor public anchor;
    SignalService public signalService;

    function setUpOnTaiko() internal override {
        signalService = SignalService(
            deploy({
                name: "signal_service",
                impl: address(new SignalService()),
                data: abi.encodeCall(SignalService.init, (address(0), address(resolver)))
            })
        );

        anchor = deployAnchor(address(new TaikoAnchor_NoBaseFeeCheck()), ethereumChainId);

        signalService.authorize(address(anchor), true);
        mineOneBlockAndWrap(30 seconds);
        vm.deal(address(anchor), 100 ether);
    }

    // calling anchor in the same block more than once should fail
    function test_anchor_AnchorTx_revert_in_same_block() external onTaiko {
        vm.fee(1);

        vm.prank(anchor.GOLDEN_TOUCH_ADDRESS());
        _anchorV2(BLOCK_GAS_LIMIT);

        vm.prank(anchor.GOLDEN_TOUCH_ADDRESS());
        vm.expectRevert(TaikoAnchor.L2_PUBLIC_INPUT_HASH_MISMATCH.selector);
        _anchorV2(BLOCK_GAS_LIMIT);
    }

    // calling anchor in the same block more than once should fail
    function test_anchor_AnchorTx_revert_from_wrong_signer() external onTaiko {
        vm.fee(1);
        vm.expectRevert(TaikoAnchor.L2_INVALID_SENDER.selector);
        _anchorV2(BLOCK_GAS_LIMIT);
    }

    function test_anchor_AnchorTx_signing(bytes32 digest) external onTaiko {
        (uint8 v, uint256 r, uint256 s) = LibAnchorSigner.signAnchor(digest, uint8(1));
        address signer = ecrecover(digest, v + 27, bytes32(r), bytes32(s));
        assertEq(signer, anchor.GOLDEN_TOUCH_ADDRESS());

        (v, r, s) = LibAnchorSigner.signAnchor(digest, uint8(2));
        signer = ecrecover(digest, v + 27, bytes32(r), bytes32(s));
        assertEq(signer, anchor.GOLDEN_TOUCH_ADDRESS());

        vm.expectRevert(LibAnchorSigner.L2_INVALID_GOLDEN_TOUCH_K.selector);
        LibAnchorSigner.signAnchor(digest, uint8(0));

        vm.expectRevert(LibAnchorSigner.L2_INVALID_GOLDEN_TOUCH_K.selector);
        LibAnchorSigner.signAnchor(digest, uint8(3));
    }

    function test_anchor_withdraw() external onTaiko {
        vm.prank(anchor.owner());
        anchor.withdraw(address(0), Alice);
        assertEq(address(anchor).balance, 0 ether);
        assertEq(Alice.balance, 100 ether);

        // Random EOA cannot call withdraw
        vm.expectRevert(EssentialContract.ACCESS_DENIED.selector);
        vm.prank(Alice, Alice);
        anchor.withdraw(address(0), Alice);
    }

    function test_anchor_getBlockHash() external onTaiko {
        assertEq(anchor.getBlockHash(uint64(1000)), 0);
    }

    /// forge-config: default.fuzz_runs = 2000
    /// forge-config: default.fuzz_runs_show_logs = true
    function test_fuzz_getBasefeeV2(
        uint32 _parentGasUsed,
        uint32 _gasIssuancePerSecond,
        uint64 _minGasExcess,
        uint32 _maxGasIssuancePerBlock,
        uint8 _adjustmentQuotient,
        uint8 _sharingPctg
    )
        external
        onTaiko
    {
        LibSharedData.BaseFeeConfig memory baseFeeConfig = LibSharedData.BaseFeeConfig({
            adjustmentQuotient: _adjustmentQuotient,
            sharingPctg: uint8(_sharingPctg % 100),
            gasIssuancePerSecond: _gasIssuancePerSecond,
            minGasExcess: _minGasExcess,
            maxGasIssuancePerBlock: _maxGasIssuancePerBlock
        });

        (uint256 basefee_,,) = anchor.getBasefeeV2(_parentGasUsed, baseFeeConfig);
        assertTrue(basefee_ != 0, "basefee is 0");
    }

    /// forge-config: default.fuzz_runs = 2000
    /// forge-config: default.fuzz_runs_show_logs = true
    function test_fuzz_anchorV2(
        uint32 _parentGasUsed,
        uint32 _gasIssuancePerSecond,
        uint64 _minGasExcess,
        uint32 _maxGasIssuancePerBlock,
        uint8 _adjustmentQuotient,
        uint8 _sharingPctg
    )
        external
        onTaiko
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
        vm.prank(anchor.GOLDEN_TOUCH_ADDRESS());
        anchor.anchorV3(
            ++anchorBlockId,
            anchorStateRoot,
            bytes32(0),
            _parentGasUsed,
            baseFeeConfig,
            new bytes32[](0)
        );

        (uint256 basefee, uint64 newGasTarget,) = anchor.getBasefeeV2(_parentGasUsed, baseFeeConfig);

        assertTrue(basefee != 0, "basefee is 0");
        assertEq(newGasTarget, anchor.parentGasTarget());

        // change the gas issuance to change the gas target
        baseFeeConfig.gasIssuancePerSecond += 1;

        (basefee, newGasTarget,) = anchor.getBasefeeV2(_parentGasUsed, baseFeeConfig);

        assertTrue(basefee != 0, "basefee is 0");
        assertTrue(newGasTarget != anchor.parentGasTarget());
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

        anchor.anchorV3(
            ++anchorBlockId,
            anchorStateRoot,
            bytes32(0),
            parentGasUsed,
            baseFeeConfig,
            new bytes32[](0)
        );
    }
}
