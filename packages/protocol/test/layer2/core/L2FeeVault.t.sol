// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "forge-std/src/Test.sol";
import { IL2FeeVault } from "src/layer2/core/IL2FeeVault.sol";
import { L2FeeVault } from "src/layer2/core/L2FeeVault.sol";

contract L2FeeVaultTest is Test {
    address private constant ANCHOR = address(0x1670);
    address private constant PROPOSER = address(0xB0B);
    address private constant RANDOM = address(0xBEEF);
    uint256 private constant BLOB_GAS_PER_BLOB = 131_072;
    uint256 private constant KP_WAD = 2e18; // 2.0

    L2FeeVault private vault;

    function setUp() external {
        vault = _deployVault(
            100 ether, // targetBalanceWei
            100, // minFeePerGasWei
            1_000_100, // maxFeePerGasWei
            8000, // lossReimbursementBps
            KP_WAD // Kp (wad-scaled)
        );
    }

    // ---------------------------------------------------------------
    // Accounting / access control
    // ---------------------------------------------------------------

    function test_importProposalFee_revertWhenUnauthorized() external {
        IL2FeeVault.ProposalFeeData memory data = _singleFeeData(1, 10, 1, 2, 3, 1000);
        vm.expectRevert(abi.encodeWithSignature("ACCESS_DENIED()"));
        vm.prank(RANDOM);
        vault.importProposalFee(data);
    }

    function test_importProposalFee_updatesAccounting() external {
        uint256 l1Cost = _l1Cost(10, 1, 2, 3);
        IL2FeeVault.ProposalFeeData memory data = _singleFeeData(1, 10, 1, 2, 3, l1Cost + 1);

        vm.prank(ANCHOR);
        vault.importProposalFee(data);

        assertEq(vault.claimable(PROPOSER), l1Cost, "claimable");
        assertEq(vault.totalLiabilities(), l1Cost, "liabilities");
    }

    function test_importProposalFee_partialWhenLoss() external {
        uint256 l1Cost = _l1Cost(10, 1, 2, 3);
        uint256 expected = (l1Cost * 8000) / 10_000;

        IL2FeeVault.ProposalFeeData memory data = _singleFeeData(1, 10, 1, 2, 3, l1Cost - 1);

        vm.prank(ANCHOR);
        vault.importProposalFee(data);

        assertEq(vault.claimable(PROPOSER), expected, "claimable");
    }

    function test_claim_transfersAndUpdatesLiabilities() external {
        uint256 l1Cost = _l1Cost(10, 1, 2, 3);
        IL2FeeVault.ProposalFeeData memory data = _singleFeeData(1, 10, 1, 2, 3, l1Cost + 1);

        vm.prank(ANCHOR);
        vault.importProposalFee(data);

        vm.deal(address(vault), l1Cost);
        vm.startPrank(PROPOSER);
        uint256 balanceBefore = PROPOSER.balance;
        vault.claim(PROPOSER, 0);
        vm.stopPrank();

        assertEq(PROPOSER.balance, balanceBefore + l1Cost, "balance");
        assertEq(vault.claimable(PROPOSER), 0, "claimable");
        assertEq(vault.totalLiabilities(), 0, "liabilities");
    }

    // ---------------------------------------------------------------
    // ---------------------------------------------------------------
    // Fee-controller tests
    // ---------------------------------------------------------------
    // ---------------------------------------------------------------

    function test_feePerGas_staysAtMinAtTarget() external {
        vm.deal(address(vault), 100 ether);
        _importEmpty(vault, 1);

        assertEq(vault.feePerGasWei(), 100, "fee should stay at min");
    }

    function test_feePerGas_dropsToMinAtSurplus() external {
        _importEmpty(vault, 1); // full deficit at this point
        vm.deal(address(vault), 200 ether);
        _importEmpty(vault, 2); // Change to 100% surplus

        assertEq(vault.feePerGasWei(), 100, "surplus should clamp to min");
    }

    function test_feePerGas_updatesToMaxAtFullDeficit() external {
        _importEmpty(vault, 1);

        assertEq(vault.feePerGasWei(), 1_000_100, "full deficit should clamp to max");
    }

    function test_feePerGas_fivePercentDeficitProducesExpectedFee() external {
        vm.deal(address(vault), 95 ether); // 5% deficit
        _importEmpty(vault, 1);

        // feeRange = 1_000_000, deficit = 5%, Kp = 2 => computed fee = 100_000 (no clamp).
        assertEq(vault.feePerGasWei(), 100_000, "fee");
    }

    function test_feePerGas_usesEffectiveBalanceWithLiabilities() external {
        vm.deal(address(vault), 150 ether);

        // Create exactly 75 ether liability so effective balance is 75 ether (25% deficit).
        uint128 basefee = 5_000_000_000_000; // 5000 gwei
        IL2FeeVault.ProposalFeeData memory data =
            _singleFeeData(1, 15_000_000, 0, basefee, 0, 75 ether);

        vm.prank(ANCHOR);
        vault.importProposalFee(data);

        assertEq(vault.totalLiabilities(), 75 ether, "liabilities");
        assertEq(
            vault.feePerGasWei(),
            500_000,
            "liabilities should reduce effective balance and raise fee"
        );
    }

    function test_feePerGas_balanceEqualsLiabilitiesIsFullDeficit() external {
        vm.deal(address(vault), 50 ether);

        // Create exactly 50 ether liability so effective balance is 0.
        uint128 basefee = 5_000_000_000_000; // 5000 gwei
        IL2FeeVault.ProposalFeeData memory data =
            _singleFeeData(1, 10_000_000, 0, basefee, 0, 51 ether);

        vm.prank(ANCHOR);
        vault.importProposalFee(data);

        assertEq(vault.totalLiabilities(), 50 ether, "liabilities");
        assertEq(vault.feePerGasWei(), 1_000_100, "full deficit should clamp to max");
    }

    function test_feePerGas_smallDeficitProducesSmallIncrease() external {
        vm.deal(address(vault), 99 ether); // 1% deficit
        _importEmpty(vault, 1);

        // feeRange = 1_000_000, deficit = 1%, Kp = 2 => computed fee = 20_000 (no clamp).
        assertEq(vault.feePerGasWei(), 20_000, "fee");
    }

    function test_feePerGas_multipleSequentialImports_staysStableForSameDeficit() external {
        vm.deal(address(vault), 95 ether); // 5% deficit -> expected fee 100_000
        for (uint48 i = 1; i <= 5; i++) {
            _importEmpty(vault, i);
            assertEq(vault.feePerGasWei(), 100_000, "same deficit should keep same fee");
        }
    }

    function test_feePerGas_claimKeepsFeeWhenEffectiveBalanceUnchanged() external {
        vm.deal(address(vault), 100 ether);

        // After import: balance=100, liabilities=5 => effective=95 (5% deficit).
        uint128 basefee = 500_000_000_000; // 500 gwei
        IL2FeeVault.ProposalFeeData memory data1 =
            _singleFeeData(1, 10_000_000, 0, basefee, 0, 6 ether);

        vm.prank(ANCHOR);
        vault.importProposalFee(data1);

        uint256 feeBeforeClaim = vault.feePerGasWei();
        assertEq(feeBeforeClaim, 100_000, "fee before claim");

        // Claiming 2 ether reduces both balance and liabilities by 2, keeping effective at 95.
        vm.prank(PROPOSER);
        vault.claim(PROPOSER, 2 ether);

        _importEmpty(vault, 2);
        assertEq(vault.feePerGasWei(), feeBeforeClaim, "fee should be unchanged");
    }

    function test_feePerGas_respectsConfiguredMaxBound() external {
        L2FeeVault testVault = _deployVault(
            100 ether, // targetBalanceWei
            100, // minFeePerGasWei
            1000, // maxFeePerGasWei
            8000, // lossReimbursementBps
            KP_WAD // Kp (wad-scaled)
        );

        // testVault is already empty, so this import represents full-deficit state.
        _importEmpty(testVault, 1);
        assertEq(testVault.feePerGasWei(), 1000, "fee should respect max bound");
    }

    function test_feePerGas_respectsConfiguredMinBound() external {
        L2FeeVault testVault = _deployVault(
            100 ether, // targetBalanceWei
            50, // minFeePerGasWei
            1_000_000, // maxFeePerGasWei
            8000, // lossReimbursementBps
            KP_WAD // Kp (wad-scaled)
        );

        _importEmpty(testVault, 1); // full deficit -> max
        vm.deal(address(testVault), 200 ether); // surplus -> min
        _importEmpty(testVault, 2);

        assertEq(testVault.feePerGasWei(), 50, "fee should respect min bound");
    }

    function test_feePerGas_zeroTargetDoesNotChange() external {
        L2FeeVault testVault = _deployVault(
            0, // targetBalanceWei
            100, // minFeePerGasWei
            1_000_000, // maxFeePerGasWei
            8000, // lossReimbursementBps
            KP_WAD // Kp (wad-scaled)
        );

        uint256 initialFee = testVault.feePerGasWei();
        _importEmpty(testVault, 1);

        assertEq(testVault.feePerGasWei(), initialFee, "fee should not change when target is 0");
    }

    // ---------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------

    function _deployVault(
        uint256 _targetBalanceWei,
        uint256 _minFeePerGasWei,
        uint256 _maxFeePerGasWei,
        uint16 _lossReimbursementBps,
        uint256 _kpWad
    )
        private
        returns (L2FeeVault vault_)
    {
        L2FeeVault impl = new L2FeeVault(
            _targetBalanceWei, _minFeePerGasWei, _maxFeePerGasWei, _lossReimbursementBps, _kpWad
        );
        vault_ = L2FeeVault(
            payable(address(
                    new ERC1967Proxy(
                        address(impl), abi.encodeCall(L2FeeVault.init, (address(this), ANCHOR))
                    )
                ))
        );
    }

    // Triggers _updateFeePerGas() via import path without creating liabilities or claimable.
    function _importEmpty(L2FeeVault _vault, uint48 _proposalId) private {
        vm.prank(ANCHOR);
        _vault.importProposalFee(_singleFeeData(_proposalId, 0, 0, 0, 0, 0));
    }

    function _singleFeeData(
        uint48 _id,
        uint64 _gasUsed,
        uint32 _numBlobs,
        uint128 _basefee,
        uint128 _blobBasefee,
        uint256 _l2Revenue
    )
        private
        pure
        returns (IL2FeeVault.ProposalFeeData memory data_)
    {
        data_ = IL2FeeVault.ProposalFeeData({
            proposalId: _id,
            proposer: PROPOSER,
            l1GasUsed: _gasUsed,
            numBlobs: _numBlobs,
            l1Basefee: _basefee,
            l1BlobBasefee: _blobBasefee,
            l2BasefeeRevenue: _l2Revenue
        });
    }

    function _l1Cost(
        uint64 _gasUsed,
        uint32 _numBlobs,
        uint128 _basefee,
        uint128 _blobBasefee
    )
        private
        pure
        returns (uint256)
    {
        uint256 gasCost = uint256(_gasUsed) * uint256(_basefee);
        uint256 blobCost = uint256(_numBlobs) * BLOB_GAS_PER_BLOB * uint256(_blobBasefee);
        return gasCost + blobCost;
    }
}
