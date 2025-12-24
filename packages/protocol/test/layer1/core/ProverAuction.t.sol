// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { ProverAuction } from "src/layer1/core/impl/ProverAuction.sol";
import { IProverAuction } from "src/layer1/core/iface/IProverAuction.sol";
import { TestERC20 } from "test/mocks/TestERC20.sol";
import { CommonTest } from "test/shared/CommonTest.sol";

contract ProverAuctionTest is CommonTest {
    ProverAuction internal auction;
    TestERC20 internal bondToken;

    address internal inbox = address(0xBEEF);
    address internal prover1 = address(0x1001);
    address internal prover2 = address(0x1002);
    address internal prover3 = address(0x1003);

    // Default constructor parameters
    uint96 internal constant LIVENESS_BOND = 1 ether;
    uint16 internal constant MAX_PENDING_PROPOSALS = 10;
    uint16 internal constant MIN_FEE_REDUCTION_BPS = 500; // 5%
    uint48 internal constant BOND_WITHDRAWAL_DELAY = 48 hours;
    uint48 internal constant FEE_DOUBLING_PERIOD = 15 minutes;
    uint8 internal constant MAX_FEE_DOUBLINGS = 8;
    uint48 internal constant INITIAL_MAX_FEE = 1000 gwei;

    // Derived values
    uint128 internal REQUIRED_BOND;
    uint128 internal FORCE_EXIT_THRESHOLD;

    // Events from IProverAuction
    event Deposited(address indexed account, uint128 amount);
    event Withdrawn(address indexed account, uint128 amount);
    event BidPlaced(address indexed newProver, uint48 feeInGwei, address indexed oldProver);
    event ExitRequested(address indexed prover, uint48 withdrawableAt);
    event BondSlashed(address indexed prover, uint128 slashed, address indexed recipient, uint128 rewarded);
    event ProverForcedOut(address indexed prover);

    function setUp() public virtual override {
        super.setUp();

        // Deploy bond token
        bondToken = new TestERC20("Bond Token", "BOND");

        // Calculate derived values
        REQUIRED_BOND = uint128(LIVENESS_BOND) * MAX_PENDING_PROPOSALS * 2;
        FORCE_EXIT_THRESHOLD = uint128(LIVENESS_BOND) * MAX_PENDING_PROPOSALS / 2;

        // Deploy ProverAuction
        ProverAuction impl = new ProverAuction(
            inbox,
            address(bondToken),
            LIVENESS_BOND,
            MAX_PENDING_PROPOSALS,
            MIN_FEE_REDUCTION_BPS,
            BOND_WITHDRAWAL_DELAY,
            FEE_DOUBLING_PERIOD,
            MAX_FEE_DOUBLINGS,
            INITIAL_MAX_FEE
        );

        auction = ProverAuction(
            address(
                new ERC1967Proxy(address(impl), abi.encodeCall(ProverAuction.init, (address(this))))
            )
        );

        // Fund provers with bond tokens
        bondToken.mint(prover1, 1000 ether);
        bondToken.mint(prover2, 1000 ether);
        bondToken.mint(prover3, 1000 ether);

        // Approve auction contract
        vm.prank(prover1);
        bondToken.approve(address(auction), type(uint256).max);
        vm.prank(prover2);
        bondToken.approve(address(auction), type(uint256).max);
        vm.prank(prover3);
        bondToken.approve(address(auction), type(uint256).max);
    }

    // ---------------------------------------------------------------
    // Helper functions
    // ---------------------------------------------------------------

    function _depositAndBid(address prover, uint128 depositAmount, uint48 fee) internal {
        vm.startPrank(prover);
        auction.deposit(depositAmount);
        auction.bid(fee);
        vm.stopPrank();
    }

    function _depositBond(address prover, uint128 amount) internal {
        vm.prank(prover);
        auction.deposit(amount);
    }

    // ---------------------------------------------------------------
    // init tests
    // ---------------------------------------------------------------

    function test_init_setsOwner() public view {
        assertEq(auction.owner(), address(this));
    }

    function test_init_setsContractCreationTime() public view {
        // Contract creation time should be set to block.timestamp at init
        (address prover,) = auction.getCurrentProver();
        assertEq(prover, address(0));
    }

    function test_init_immutablesSetCorrectly() public view {
        assertEq(auction.inbox(), inbox);
        assertEq(address(auction.bondToken()), address(bondToken));
        assertEq(auction.livenessBond(), LIVENESS_BOND);
        assertEq(auction.maxPendingProposals(), MAX_PENDING_PROPOSALS);
        assertEq(auction.minFeeReductionBps(), MIN_FEE_REDUCTION_BPS);
        assertEq(auction.bondWithdrawalDelay(), BOND_WITHDRAWAL_DELAY);
        assertEq(auction.feeDoublingPeriod(), FEE_DOUBLING_PERIOD);
        assertEq(auction.maxFeeDoublings(), MAX_FEE_DOUBLINGS);
        assertEq(auction.initialMaxFee(), INITIAL_MAX_FEE);
    }

    // ---------------------------------------------------------------
    // deposit tests
    // ---------------------------------------------------------------

    function test_deposit_increasesBalance() public {
        uint128 amount = 10 ether;

        vm.prank(prover1);
        vm.expectEmit(true, false, false, true);
        emit Deposited(prover1, amount);
        auction.deposit(amount);

        IProverAuction.BondInfo memory info = auction.getBondInfo(prover1);
        assertEq(info.balance, amount);
    }

    function test_deposit_multipleDeposits() public {
        vm.startPrank(prover1);
        auction.deposit(10 ether);
        auction.deposit(5 ether);
        vm.stopPrank();

        IProverAuction.BondInfo memory info = auction.getBondInfo(prover1);
        assertEq(info.balance, 15 ether);
    }

    function test_deposit_transfersTokens() public {
        uint128 amount = 10 ether;
        uint256 balanceBefore = bondToken.balanceOf(prover1);

        vm.prank(prover1);
        auction.deposit(amount);

        assertEq(bondToken.balanceOf(prover1), balanceBefore - amount);
        assertEq(bondToken.balanceOf(address(auction)), amount);
    }

    // ---------------------------------------------------------------
    // withdraw tests
    // ---------------------------------------------------------------

    function test_withdraw_decreasesBalance() public {
        _depositBond(prover1, 10 ether);

        vm.prank(prover1);
        vm.expectEmit(true, false, false, true);
        emit Withdrawn(prover1, 5 ether);
        auction.withdraw(5 ether);

        IProverAuction.BondInfo memory info = auction.getBondInfo(prover1);
        assertEq(info.balance, 5 ether);
    }

    function test_withdraw_transfersTokens() public {
        _depositBond(prover1, 10 ether);
        uint256 balanceBefore = bondToken.balanceOf(prover1);

        vm.prank(prover1);
        auction.withdraw(5 ether);

        assertEq(bondToken.balanceOf(prover1), balanceBefore + 5 ether);
    }

    function test_withdraw_fullBalance() public {
        _depositBond(prover1, 10 ether);

        vm.prank(prover1);
        auction.withdraw(10 ether);

        IProverAuction.BondInfo memory info = auction.getBondInfo(prover1);
        assertEq(info.balance, 0);
    }

    function test_withdraw_RevertWhen_CurrentProver() public {
        _depositAndBid(prover1, REQUIRED_BOND, 500 gwei);

        vm.prank(prover1);
        vm.expectRevert(ProverAuction.CurrentProverCannotWithdraw.selector);
        auction.withdraw(1 ether);
    }

    function test_withdraw_RevertWhen_InsufficientBalance() public {
        _depositBond(prover1, 10 ether);

        vm.prank(prover1);
        vm.expectRevert(ProverAuction.InsufficientBond.selector);
        auction.withdraw(11 ether);
    }

    function test_withdraw_RevertWhen_WithdrawalDelayNotPassed() public {
        // Prover1 becomes prover, then gets outbid
        _depositAndBid(prover1, REQUIRED_BOND, 500 gwei);
        _depositAndBid(prover2, REQUIRED_BOND, 450 gwei); // Outbids prover1

        // prover1 should have withdrawableAt set
        IProverAuction.BondInfo memory info = auction.getBondInfo(prover1);
        assertGt(info.withdrawableAt, 0);

        // Try to withdraw before delay passes
        vm.prank(prover1);
        vm.expectRevert(ProverAuction.WithdrawalDelayNotPassed.selector);
        auction.withdraw(1 ether);
    }

    function test_withdraw_afterDelayPasses() public {
        _depositAndBid(prover1, REQUIRED_BOND, 500 gwei);
        _depositAndBid(prover2, REQUIRED_BOND, 450 gwei);

        // Warp past withdrawal delay
        vm.warp(block.timestamp + BOND_WITHDRAWAL_DELAY + 1);

        vm.prank(prover1);
        auction.withdraw(1 ether);

        IProverAuction.BondInfo memory info = auction.getBondInfo(prover1);
        assertEq(info.balance, REQUIRED_BOND - 1 ether);
    }

    function test_withdraw_noDelayWhenWithdrawableAtIsZero() public {
        // Just deposit without bidding
        _depositBond(prover1, 10 ether);

        // Should be able to withdraw immediately
        vm.prank(prover1);
        auction.withdraw(5 ether);

        IProverAuction.BondInfo memory info = auction.getBondInfo(prover1);
        assertEq(info.balance, 5 ether);
    }

    // ---------------------------------------------------------------
    // getCurrentProver tests
    // ---------------------------------------------------------------

    function test_getCurrentProver_returnsZeroWhenNoProver() public view {
        (address prover, uint48 fee) = auction.getCurrentProver();
        assertEq(prover, address(0));
        assertEq(fee, 0);
    }

    function test_getCurrentProver_returnsActiveProver() public {
        _depositAndBid(prover1, REQUIRED_BOND, 500 gwei);

        (address prover, uint48 fee) = auction.getCurrentProver();
        assertEq(prover, prover1);
        assertEq(fee, 500 gwei);
    }

    function test_getCurrentProver_returnsZeroWhenProverExited() public {
        _depositAndBid(prover1, REQUIRED_BOND, 500 gwei);

        vm.prank(prover1);
        auction.requestExit();

        (address prover, uint48 fee) = auction.getCurrentProver();
        assertEq(prover, address(0));
        assertEq(fee, 0);
    }

    // ---------------------------------------------------------------
    // getMaxBidFee tests
    // ---------------------------------------------------------------

    function test_getMaxBidFee_initialVacantSlot() public view {
        // At t=0, should be initialMaxFee
        uint48 maxFee = auction.getMaxBidFee();
        assertEq(maxFee, INITIAL_MAX_FEE);
    }

    function test_getMaxBidFee_vacantSlotDoublesOverTime() public {
        // Warp to 1 period
        vm.warp(block.timestamp + FEE_DOUBLING_PERIOD);
        assertEq(auction.getMaxBidFee(), INITIAL_MAX_FEE * 2);

        // Warp to 2 periods
        vm.warp(block.timestamp + FEE_DOUBLING_PERIOD);
        assertEq(auction.getMaxBidFee(), INITIAL_MAX_FEE * 4);

        // Warp to 3 periods
        vm.warp(block.timestamp + FEE_DOUBLING_PERIOD);
        assertEq(auction.getMaxBidFee(), INITIAL_MAX_FEE * 8);
    }

    function test_getMaxBidFee_capsAtMaxDoublings() public {
        // Warp past max doublings (8 doublings = 256x)
        vm.warp(block.timestamp + FEE_DOUBLING_PERIOD * (MAX_FEE_DOUBLINGS + 5));

        uint48 maxFee = auction.getMaxBidFee();
        assertEq(maxFee, INITIAL_MAX_FEE * (1 << MAX_FEE_DOUBLINGS)); // 256x
    }

    function test_getMaxBidFee_activeProverRequiresReduction() public {
        _depositAndBid(prover1, REQUIRED_BOND, 1000 gwei);

        uint48 maxFee = auction.getMaxBidFee();
        // 5% reduction: 1000 * 95% = 950
        assertEq(maxFee, 950 gwei);
    }

    function test_getMaxBidFee_afterProverExits() public {
        _depositAndBid(prover1, REQUIRED_BOND, 1000 gwei);

        vm.prank(prover1);
        auction.requestExit();

        // At exit time, max fee should be the prover's fee
        assertEq(auction.getMaxBidFee(), 1000 gwei);

        // After one period, should double
        vm.warp(block.timestamp + FEE_DOUBLING_PERIOD);
        assertEq(auction.getMaxBidFee(), 2000 gwei);
    }

    function test_getMaxBidFee_capsAtUint48Max() public {
        // Deploy with very high initial fee that will overflow uint48
        ProverAuction impl = new ProverAuction(
            inbox,
            address(bondToken),
            LIVENESS_BOND,
            MAX_PENDING_PROPOSALS,
            MIN_FEE_REDUCTION_BPS,
            BOND_WITHDRAWAL_DELAY,
            FEE_DOUBLING_PERIOD,
            MAX_FEE_DOUBLINGS,
            type(uint48).max / 2 // High initial fee
        );

        ProverAuction highFeeAuction = ProverAuction(
            address(
                new ERC1967Proxy(address(impl), abi.encodeCall(ProverAuction.init, (address(this))))
            )
        );

        // Warp to trigger doublings that would overflow
        vm.warp(block.timestamp + FEE_DOUBLING_PERIOD * 3);

        assertEq(highFeeAuction.getMaxBidFee(), type(uint48).max);
    }

    // ---------------------------------------------------------------
    // bid tests - vacant slot
    // ---------------------------------------------------------------

    function test_bid_vacantSlot_success() public {
        _depositBond(prover1, REQUIRED_BOND);

        vm.prank(prover1);
        vm.expectEmit(true, true, false, true);
        emit BidPlaced(prover1, 500 gwei, address(0));
        auction.bid(500 gwei);

        (address prover, uint48 fee) = auction.getCurrentProver();
        assertEq(prover, prover1);
        assertEq(fee, 500 gwei);
    }

    function test_bid_vacantSlot_RevertWhen_FeeTooHigh() public {
        _depositBond(prover1, REQUIRED_BOND);

        vm.prank(prover1);
        vm.expectRevert(ProverAuction.FeeTooHigh.selector);
        auction.bid(INITIAL_MAX_FEE + 1);
    }

    function test_bid_vacantSlot_RevertWhen_InsufficientBond() public {
        _depositBond(prover1, REQUIRED_BOND - 1);

        vm.prank(prover1);
        vm.expectRevert(ProverAuction.InsufficientBond.selector);
        auction.bid(500 gwei);
    }

    function test_bid_vacantSlot_updatesMovingAverage() public {
        _depositAndBid(prover1, REQUIRED_BOND, 500 gwei);

        assertEq(auction.getMovingAverageFee(), 500 gwei);
    }

    // ---------------------------------------------------------------
    // bid tests - outbidding another prover
    // ---------------------------------------------------------------

    function test_bid_outbid_success() public {
        _depositAndBid(prover1, REQUIRED_BOND, 1000 gwei);
        _depositBond(prover2, REQUIRED_BOND);

        vm.prank(prover2);
        vm.expectEmit(true, true, false, true);
        emit BidPlaced(prover2, 950 gwei, prover1);
        auction.bid(950 gwei); // 5% reduction

        (address prover, uint48 fee) = auction.getCurrentProver();
        assertEq(prover, prover2);
        assertEq(fee, 950 gwei);
    }

    function test_bid_outbid_setsWithdrawableAt() public {
        _depositAndBid(prover1, REQUIRED_BOND, 1000 gwei);
        _depositAndBid(prover2, REQUIRED_BOND, 950 gwei);

        IProverAuction.BondInfo memory info = auction.getBondInfo(prover1);
        assertEq(info.withdrawableAt, uint48(block.timestamp) + BOND_WITHDRAWAL_DELAY);
    }

    function test_bid_outbid_RevertWhen_InsufficientReduction() public {
        _depositAndBid(prover1, REQUIRED_BOND, 1000 gwei);
        _depositBond(prover2, REQUIRED_BOND);

        vm.prank(prover2);
        vm.expectRevert(ProverAuction.FeeTooHigh.selector);
        auction.bid(951 gwei); // Less than 5% reduction
    }

    function test_bid_outbid_exactMinReduction() public {
        _depositAndBid(prover1, REQUIRED_BOND, 1000 gwei);
        _depositBond(prover2, REQUIRED_BOND);

        vm.prank(prover2);
        auction.bid(950 gwei); // Exactly 5% reduction

        (address prover,) = auction.getCurrentProver();
        assertEq(prover, prover2);
    }

    // ---------------------------------------------------------------
    // bid tests - self bid (current prover lowering fee)
    // ---------------------------------------------------------------

    function test_bid_selfBid_lowersFee() public {
        _depositAndBid(prover1, REQUIRED_BOND, 1000 gwei);

        vm.prank(prover1);
        vm.expectEmit(true, true, false, true);
        emit BidPlaced(prover1, 900 gwei, prover1);
        auction.bid(900 gwei);

        (address prover, uint48 fee) = auction.getCurrentProver();
        assertEq(prover, prover1);
        assertEq(fee, 900 gwei);
    }

    function test_bid_selfBid_noMinReductionRequired() public {
        _depositAndBid(prover1, REQUIRED_BOND, 1000 gwei);

        // Can lower by just 1 gwei
        vm.prank(prover1);
        auction.bid(999 gwei);

        (, uint48 fee) = auction.getCurrentProver();
        assertEq(fee, 999 gwei);
    }

    function test_bid_selfBid_RevertWhen_FeeNotLower() public {
        _depositAndBid(prover1, REQUIRED_BOND, 1000 gwei);

        vm.prank(prover1);
        vm.expectRevert(ProverAuction.FeeMustBeLower.selector);
        auction.bid(1000 gwei);
    }

    function test_bid_selfBid_RevertWhen_FeeHigher() public {
        _depositAndBid(prover1, REQUIRED_BOND, 1000 gwei);

        vm.prank(prover1);
        vm.expectRevert(ProverAuction.FeeMustBeLower.selector);
        auction.bid(1001 gwei);
    }

    function test_bid_selfBid_updatesMovingAverage() public {
        _depositAndBid(prover1, REQUIRED_BOND, 1000 gwei);
        assertEq(auction.getMovingAverageFee(), 1000 gwei);

        vm.prank(prover1);
        auction.bid(100 gwei);

        // EMA: (1000 * 9 + 100) / 10 = 910
        assertEq(auction.getMovingAverageFee(), 910 gwei);
    }

    // ---------------------------------------------------------------
    // bid tests - re-entering after exit
    // ---------------------------------------------------------------

    function test_bid_reenterClearsWithdrawableAt() public {
        _depositAndBid(prover1, REQUIRED_BOND, 1000 gwei);

        vm.prank(prover1);
        auction.requestExit();

        IProverAuction.BondInfo memory infoBefore = auction.getBondInfo(prover1);
        assertGt(infoBefore.withdrawableAt, 0);

        // Re-enter by bidding again
        vm.prank(prover1);
        auction.bid(INITIAL_MAX_FEE); // Max fee since slot is vacant

        IProverAuction.BondInfo memory infoAfter = auction.getBondInfo(prover1);
        assertEq(infoAfter.withdrawableAt, 0);
    }

    // ---------------------------------------------------------------
    // requestExit tests
    // ---------------------------------------------------------------

    function test_requestExit_success() public {
        _depositAndBid(prover1, REQUIRED_BOND, 500 gwei);

        vm.prank(prover1);
        vm.expectEmit(true, false, false, true);
        emit ExitRequested(prover1, uint48(block.timestamp) + BOND_WITHDRAWAL_DELAY);
        auction.requestExit();

        (address prover,) = auction.getCurrentProver();
        assertEq(prover, address(0)); // No active prover
    }

    function test_requestExit_setsWithdrawableAt() public {
        _depositAndBid(prover1, REQUIRED_BOND, 500 gwei);

        vm.prank(prover1);
        auction.requestExit();

        IProverAuction.BondInfo memory info = auction.getBondInfo(prover1);
        assertEq(info.withdrawableAt, uint48(block.timestamp) + BOND_WITHDRAWAL_DELAY);
    }

    function test_requestExit_RevertWhen_NotCurrentProver() public {
        _depositAndBid(prover1, REQUIRED_BOND, 500 gwei);

        vm.prank(prover2);
        vm.expectRevert(ProverAuction.NotCurrentProver.selector);
        auction.requestExit();
    }

    function test_requestExit_RevertWhen_AlreadyExited() public {
        _depositAndBid(prover1, REQUIRED_BOND, 500 gwei);

        vm.prank(prover1);
        auction.requestExit();

        vm.prank(prover1);
        vm.expectRevert(ProverAuction.AlreadyExited.selector);
        auction.requestExit();
    }

    function test_requestExit_RevertWhen_NoProver() public {
        vm.prank(prover1);
        vm.expectRevert(ProverAuction.NotCurrentProver.selector);
        auction.requestExit();
    }

    // ---------------------------------------------------------------
    // slashBond tests
    // ---------------------------------------------------------------

    function test_slashBond_success() public {
        _depositAndBid(prover1, REQUIRED_BOND, 500 gwei);

        vm.prank(inbox);
        vm.expectEmit(true, true, false, true);
        emit BondSlashed(prover1, 1 ether, prover2, 0.5 ether);
        auction.slashBond(prover1, 1 ether, prover2, 0.5 ether);

        IProverAuction.BondInfo memory info = auction.getBondInfo(prover1);
        assertEq(info.balance, REQUIRED_BOND - 1 ether);

        // Reward sent to recipient
        assertEq(bondToken.balanceOf(prover2), 1000 ether + 0.5 ether);

        // Slash diff tracked
        assertEq(auction.getTotalSlashDiff(), 0.5 ether);
    }

    function test_slashBond_RevertWhen_NotInbox() public {
        _depositAndBid(prover1, REQUIRED_BOND, 500 gwei);

        vm.prank(prover2);
        vm.expectRevert(ProverAuction.OnlyInbox.selector);
        auction.slashBond(prover1, 1 ether, prover2, 0.5 ether);
    }

    function test_slashBond_bestEffortSlash() public {
        _depositBond(prover1, 1 ether);

        // Try to slash more than balance
        vm.prank(inbox);
        auction.slashBond(prover1, 10 ether, prover2, 5 ether);

        // Only slashes available balance
        IProverAuction.BondInfo memory info = auction.getBondInfo(prover1);
        assertEq(info.balance, 0);

        // Reward capped by actual slash
        assertEq(bondToken.balanceOf(prover2), 1000 ether + 1 ether);
    }

    function test_slashBond_rewardCappedBySlash() public {
        _depositBond(prover1, 1 ether);

        vm.prank(inbox);
        auction.slashBond(prover1, 0.5 ether, prover2, 1 ether);

        // Reward is capped at actualSlash (0.5 ether)
        assertEq(bondToken.balanceOf(prover2), 1000 ether + 0.5 ether);
    }

    function test_slashBond_noRewardWhenZero() public {
        _depositBond(prover1, 1 ether);

        uint256 recipientBalanceBefore = bondToken.balanceOf(prover2);

        vm.prank(inbox);
        auction.slashBond(prover1, 0.5 ether, prover2, 0);

        assertEq(bondToken.balanceOf(prover2), recipientBalanceBefore);
    }

    function test_slashBond_noRewardWhenRecipientZero() public {
        _depositBond(prover1, 1 ether);

        vm.prank(inbox);
        auction.slashBond(prover1, 0.5 ether, address(0), 0.5 ether);

        // No transfer to zero address
        IProverAuction.BondInfo memory info = auction.getBondInfo(prover1);
        assertEq(info.balance, 0.5 ether);
    }

    function test_slashBond_forceExitWhenBelowThreshold() public {
        _depositAndBid(prover1, REQUIRED_BOND, 500 gwei);

        // Slash enough to go below force exit threshold
        uint128 slashAmount = REQUIRED_BOND - FORCE_EXIT_THRESHOLD + 1;

        vm.prank(inbox);
        vm.expectEmit(true, false, false, false);
        emit ProverForcedOut(prover1);
        auction.slashBond(prover1, slashAmount, prover2, 0);

        (address prover,) = auction.getCurrentProver();
        assertEq(prover, address(0)); // Forced out
    }

    function test_slashBond_noForceExitWhenAboveThreshold() public {
        _depositAndBid(prover1, REQUIRED_BOND, 500 gwei);

        // Slash but stay above threshold
        uint128 slashAmount = REQUIRED_BOND - FORCE_EXIT_THRESHOLD - 1;

        vm.prank(inbox);
        auction.slashBond(prover1, slashAmount, prover2, 0);

        (address prover,) = auction.getCurrentProver();
        assertEq(prover, prover1); // Still active
    }

    function test_slashBond_noForceExitWhenNotCurrentProver() public {
        _depositAndBid(prover1, REQUIRED_BOND, 500 gwei);
        _depositBond(prover2, 1 ether);

        // Slash prover2 (not current prover) to zero
        vm.prank(inbox);
        auction.slashBond(prover2, 1 ether, prover3, 0);

        // prover1 still active (not affected)
        (address prover,) = auction.getCurrentProver();
        assertEq(prover, prover1);
    }

    function test_slashBond_forceExitSetsWithdrawableAt() public {
        _depositAndBid(prover1, REQUIRED_BOND, 500 gwei);

        uint128 slashAmount = REQUIRED_BOND - FORCE_EXIT_THRESHOLD + 1;

        vm.prank(inbox);
        auction.slashBond(prover1, slashAmount, prover2, 0);

        IProverAuction.BondInfo memory info = auction.getBondInfo(prover1);
        assertEq(info.withdrawableAt, uint48(block.timestamp) + BOND_WITHDRAWAL_DELAY);
    }

    // ---------------------------------------------------------------
    // View function tests
    // ---------------------------------------------------------------

    function test_getRequiredBond() public view {
        assertEq(auction.getRequiredBond(), uint128(LIVENESS_BOND) * MAX_PENDING_PROPOSALS * 2);
    }

    function test_getForceExitThreshold() public view {
        assertEq(auction.getForceExitThreshold(), uint128(LIVENESS_BOND) * MAX_PENDING_PROPOSALS / 2);
    }

    function test_getMovingAverageFee_initial() public view {
        assertEq(auction.getMovingAverageFee(), 0);
    }

    function test_getMovingAverageFee_afterBids() public {
        _depositAndBid(prover1, REQUIRED_BOND, 1000 gwei);
        assertEq(auction.getMovingAverageFee(), 1000 gwei);

        // Outbid with lower fee
        _depositAndBid(prover2, REQUIRED_BOND, 900 gwei);
        // EMA: (1000 * 9 + 900) / 10 = 990
        assertEq(auction.getMovingAverageFee(), 990 gwei);
    }

    function test_getTotalSlashDiff_initial() public view {
        assertEq(auction.getTotalSlashDiff(), 0);
    }

    function test_getTotalSlashDiff_afterSlash() public {
        _depositBond(prover1, 10 ether);

        vm.prank(inbox);
        auction.slashBond(prover1, 5 ether, prover2, 2 ether);

        assertEq(auction.getTotalSlashDiff(), 3 ether); // 5 - 2 = 3
    }

    function test_getBondInfo() public {
        _depositBond(prover1, 10 ether);

        IProverAuction.BondInfo memory info = auction.getBondInfo(prover1);
        assertEq(info.balance, 10 ether);
        assertEq(info.withdrawableAt, 0);
    }

    // ---------------------------------------------------------------
    // Moving average tests
    // ---------------------------------------------------------------

    function test_movingAverage_firstBidSetsBaseline() public {
        _depositAndBid(prover1, REQUIRED_BOND, 500 gwei);
        assertEq(auction.getMovingAverageFee(), 500 gwei);
    }

    function test_movingAverage_subsequentBidsUseEMA() public {
        _depositAndBid(prover1, REQUIRED_BOND, 1000 gwei);

        // Self-bid to lower fee multiple times
        vm.startPrank(prover1);

        auction.bid(100 gwei);
        // EMA: (1000 * 9 + 100) / 10 = 910
        assertEq(auction.getMovingAverageFee(), 910 gwei);

        auction.bid(99 gwei);
        // EMA: (910 * 9 + 99) / 10 = 828.9 -> truncated to 828
        assertEq(auction.getMovingAverageFee(), 828900000000); // 828.9 gwei

        vm.stopPrank();
    }

    // ---------------------------------------------------------------
    // Edge case tests
    // ---------------------------------------------------------------

    function test_bidWithZeroFee() public {
        _depositBond(prover1, REQUIRED_BOND);

        vm.prank(prover1);
        auction.bid(0);

        (, uint48 fee) = auction.getCurrentProver();
        assertEq(fee, 0);
    }

    function test_multipleProversCompeting() public {
        _depositAndBid(prover1, REQUIRED_BOND, 1000 gwei);
        _depositAndBid(prover2, REQUIRED_BOND, 950 gwei);
        _depositAndBid(prover3, REQUIRED_BOND, 902 gwei);

        (address prover, uint48 fee) = auction.getCurrentProver();
        assertEq(prover, prover3);
        assertEq(fee, 902 gwei);
    }

    function test_proverReentersAfterBeingOutbid() public {
        _depositAndBid(prover1, REQUIRED_BOND, 1000 gwei);
        _depositAndBid(prover2, REQUIRED_BOND, 950 gwei);

        // Wait for withdrawal delay
        vm.warp(block.timestamp + BOND_WITHDRAWAL_DELAY + 1);

        // Prover1 bids again
        vm.prank(prover1);
        auction.bid(900 gwei);

        (address prover,) = auction.getCurrentProver();
        assertEq(prover, prover1);
    }

    function test_proverReentersAfterExit() public {
        _depositAndBid(prover1, REQUIRED_BOND, 1000 gwei);

        vm.prank(prover1);
        auction.requestExit();

        // Re-enter immediately (within first doubling period)
        vm.prank(prover1);
        auction.bid(1000 gwei);

        (address prover,) = auction.getCurrentProver();
        assertEq(prover, prover1);
    }

    // ---------------------------------------------------------------
    // Bug verification tests (from REVIEW_ProverAuction.md)
    // ---------------------------------------------------------------

    /// @notice Issue 2.1/4.1: Test withdrawal delay bypass via re-entry
    /// When an outbid prover re-enters by bidding again, their withdrawableAt is cleared,
    /// but they cannot withdraw while being the current prover anyway.
    /// The potential bug is: if they re-enter and then get outbid AGAIN, do they get a NEW delay?
    function test_bug_withdrawalDelayBypassViaReentry() public {
        // Step 1: Prover1 becomes prover
        _depositAndBid(prover1, REQUIRED_BOND, 1000 gwei);

        // Step 2: Prover2 outbids prover1
        _depositAndBid(prover2, REQUIRED_BOND, 950 gwei);

        // Step 3: Prover1 should have withdrawableAt set
        IProverAuction.BondInfo memory info1 = auction.getBondInfo(prover1);
        uint48 originalWithdrawableAt = info1.withdrawableAt;
        assertGt(originalWithdrawableAt, 0, "prover1 should have withdrawableAt set after being outbid");

        // Step 4: Prover1 re-enters immediately (bypasses delay by bidding)
        vm.prank(prover1);
        auction.bid(900 gwei);

        // Step 5: withdrawableAt should be cleared
        IProverAuction.BondInfo memory info2 = auction.getBondInfo(prover1);
        assertEq(info2.withdrawableAt, 0, "withdrawableAt should be cleared after re-entry");

        // Step 6: Prover1 cannot withdraw while being current prover
        vm.prank(prover1);
        vm.expectRevert(ProverAuction.CurrentProverCannotWithdraw.selector);
        auction.withdraw(1 ether);

        // Step 7: Prover3 outbids prover1
        _depositAndBid(prover3, REQUIRED_BOND, 855 gwei);

        // Step 8: Prover1 should have a NEW withdrawableAt set
        IProverAuction.BondInfo memory info3 = auction.getBondInfo(prover1);
        assertGt(info3.withdrawableAt, 0, "prover1 should have new withdrawableAt after being outbid again");

        // Step 9: Prover1 cannot withdraw before delay passes
        vm.prank(prover1);
        vm.expectRevert(ProverAuction.WithdrawalDelayNotPassed.selector);
        auction.withdraw(1 ether);

        // Step 10: After delay passes, prover1 can withdraw
        vm.warp(block.timestamp + BOND_WITHDRAWAL_DELAY + 1);
        vm.prank(prover1);
        auction.withdraw(1 ether); // Should succeed

        // CONCLUSION: The withdrawal delay bypass is NOT a real bug because:
        // 1. Current prover cannot withdraw anyway
        // 2. If they get outbid after re-entering, a new delay is set
        // The "bypass" only clears the delay temporarily while they're the active prover
    }

    /// @notice Issue 2.1 variant: Test that outbid prover CAN withdraw immediately after re-entering
    /// and getting outbid again IF the delay from the second outbid has passed
    function test_bug_withdrawalDelayResetOnReentry() public {
        uint256 startTime = block.timestamp;

        // Prover1 becomes prover, then gets outbid
        _depositAndBid(prover1, REQUIRED_BOND, 1000 gwei);
        _depositAndBid(prover2, REQUIRED_BOND, 950 gwei);

        // Record the first withdrawableAt
        IProverAuction.BondInfo memory info1 = auction.getBondInfo(prover1);
        uint48 firstWithdrawableAt = info1.withdrawableAt;
        assertEq(firstWithdrawableAt, uint48(startTime) + BOND_WITHDRAWAL_DELAY);

        // Time passes but not enough for withdrawal
        vm.warp(startTime + BOND_WITHDRAWAL_DELAY / 2);

        // Prover1 re-enters
        vm.prank(prover1);
        auction.bid(900 gwei);

        // withdrawableAt is now 0
        IProverAuction.BondInfo memory info2 = auction.getBondInfo(prover1);
        assertEq(info2.withdrawableAt, 0);

        // Prover2 outbids again
        vm.prank(prover2);
        auction.bid(855 gwei);

        // NEW withdrawableAt is set based on current time
        IProverAuction.BondInfo memory info3 = auction.getBondInfo(prover1);
        uint48 secondWithdrawableAt = info3.withdrawableAt;
        assertEq(secondWithdrawableAt, uint48(block.timestamp) + BOND_WITHDRAWAL_DELAY);

        // The second withdrawableAt is LATER than the first would have been
        // This means re-entry actually EXTENDS the wait time, not bypasses it
        assertGt(secondWithdrawableAt, firstWithdrawableAt, "second delay should be later than first");
    }

    /// @notice Issue 2.6: Test getMaxBidFee when baseFee is zero
    function test_bug_getMaxBidFeeWithZeroBaseFee() public {
        // Deploy auction with initialMaxFee = 0
        ProverAuction impl = new ProverAuction(
            inbox,
            address(bondToken),
            LIVENESS_BOND,
            MAX_PENDING_PROPOSALS,
            MIN_FEE_REDUCTION_BPS,
            BOND_WITHDRAWAL_DELAY,
            FEE_DOUBLING_PERIOD,
            MAX_FEE_DOUBLINGS,
            0 // initialMaxFee = 0
        );

        ProverAuction zeroFeeAuction = ProverAuction(
            address(
                new ERC1967Proxy(address(impl), abi.encodeCall(ProverAuction.init, (address(this))))
            )
        );

        // Approve and deposit
        vm.prank(prover1);
        bondToken.approve(address(zeroFeeAuction), type(uint256).max);
        vm.prank(prover1);
        zeroFeeAuction.deposit(REQUIRED_BOND);

        // maxBidFee should be 0
        assertEq(zeroFeeAuction.getMaxBidFee(), 0);

        // Can only bid 0
        vm.prank(prover1);
        zeroFeeAuction.bid(0);

        (address prover, uint48 fee) = zeroFeeAuction.getCurrentProver();
        assertEq(prover, prover1);
        assertEq(fee, 0);

        // Even after time passes, 0 << N = 0
        vm.warp(block.timestamp + FEE_DOUBLING_PERIOD * 10);
        vm.prank(prover1);
        zeroFeeAuction.requestExit();

        assertEq(zeroFeeAuction.getMaxBidFee(), 0, "0 doubled any number of times is still 0");

        // CONFIRMED BUG: If initialMaxFee is 0 or a prover exits with fee 0,
        // the slot becomes stuck at 0 max fee forever (0 << N = 0)
    }

    /// @notice Issue 2.6 variant: Test what happens when a prover exits with fee 0
    function test_bug_proverExitsWithZeroFee() public {
        // First, bid with 0 fee (already tested this works)
        _depositBond(prover1, REQUIRED_BOND);
        vm.prank(prover1);
        auction.bid(0);

        // Exit
        vm.prank(prover1);
        auction.requestExit();

        // Max fee should be 0 (base fee from exited prover)
        assertEq(auction.getMaxBidFee(), 0);

        // Even after time passes
        vm.warp(block.timestamp + FEE_DOUBLING_PERIOD * MAX_FEE_DOUBLINGS);
        assertEq(auction.getMaxBidFee(), 0, "0 doubled is still 0");

        // CONFIRMED: If a prover exits with fee 0, no one can bid with fee > 0
        // This is either a bug or intentional design (free proving forever)
    }

    /// @notice Issue 2.7: Test that force exit is skipped for already-exited prover (FIXED)
    function test_bug_forceExitOnAlreadyExitedProver() public {
        _depositAndBid(prover1, REQUIRED_BOND, 500 gwei);

        // Prover exits voluntarily
        vm.prank(prover1);
        auction.requestExit();

        IProverAuction.BondInfo memory infoBefore = auction.getBondInfo(prover1);
        uint48 exitWithdrawableAt = infoBefore.withdrawableAt;

        // Advance time a bit
        vm.warp(block.timestamp + 1 hours);

        // Slash the already-exited prover below threshold
        uint128 slashAmount = REQUIRED_BOND - FORCE_EXIT_THRESHOLD + 1;
        vm.prank(inbox);
        auction.slashBond(prover1, slashAmount, prover2, 0);

        // After optimization: force-exit logic is skipped for already-exited provers
        // So withdrawableAt should remain unchanged (the original exit time)
        IProverAuction.BondInfo memory infoAfter = auction.getBondInfo(prover1);
        assertEq(infoAfter.withdrawableAt, exitWithdrawableAt, "withdrawableAt should not change for already-exited");
    }

    /// @notice Issue 4.3: Test slash when balance exactly equals threshold
    function test_bug_slashAtExactThreshold() public {
        _depositAndBid(prover1, REQUIRED_BOND, 500 gwei);

        // Slash to exactly the threshold (not below)
        uint128 slashAmount = REQUIRED_BOND - FORCE_EXIT_THRESHOLD;
        vm.prank(inbox);
        auction.slashBond(prover1, slashAmount, prover2, 0);

        // Should NOT be force-exited (balance == threshold, not < threshold)
        (address prover,) = auction.getCurrentProver();
        assertEq(prover, prover1, "prover should not be force-exited at exact threshold");

        IProverAuction.BondInfo memory info = auction.getBondInfo(prover1);
        assertEq(info.balance, FORCE_EXIT_THRESHOLD);
    }

    /// @notice Issue 4.3 variant: Test slash to just below threshold
    function test_bug_slashJustBelowThreshold() public {
        _depositAndBid(prover1, REQUIRED_BOND, 500 gwei);

        // Slash to 1 wei below threshold
        uint128 slashAmount = REQUIRED_BOND - FORCE_EXIT_THRESHOLD + 1;
        vm.prank(inbox);
        auction.slashBond(prover1, slashAmount, prover2, 0);

        // Should be force-exited
        (address prover,) = auction.getCurrentProver();
        assertEq(prover, address(0), "prover should be force-exited below threshold");
    }

    /// @notice Issue 2.3: Test minFeeReductionBps at boundary values
    function test_bug_minFeeReductionBpsAt10000() public {
        // Deploy with 100% reduction required (should make outbidding impossible except with 0)
        ProverAuction impl = new ProverAuction(
            inbox,
            address(bondToken),
            LIVENESS_BOND,
            MAX_PENDING_PROPOSALS,
            10_000, // 100% reduction required
            BOND_WITHDRAWAL_DELAY,
            FEE_DOUBLING_PERIOD,
            MAX_FEE_DOUBLINGS,
            INITIAL_MAX_FEE
        );

        ProverAuction maxReductionAuction = ProverAuction(
            address(
                new ERC1967Proxy(address(impl), abi.encodeCall(ProverAuction.init, (address(this))))
            )
        );

        // Approve and deposit for both provers
        vm.prank(prover1);
        bondToken.approve(address(maxReductionAuction), type(uint256).max);
        vm.prank(prover1);
        maxReductionAuction.deposit(REQUIRED_BOND);

        vm.prank(prover2);
        bondToken.approve(address(maxReductionAuction), type(uint256).max);
        vm.prank(prover2);
        maxReductionAuction.deposit(REQUIRED_BOND);

        // First prover bids
        vm.prank(prover1);
        maxReductionAuction.bid(1000 gwei);

        // getMaxBidFee should be 0 (1000 * (10000 - 10000) / 10000 = 0)
        assertEq(maxReductionAuction.getMaxBidFee(), 0);

        // Second prover can only bid 0
        vm.prank(prover2);
        maxReductionAuction.bid(0);

        (, uint48 fee) = maxReductionAuction.getCurrentProver();
        assertEq(fee, 0);
    }

    /// @notice Issue 2.3 variant: Test minFeeReductionBps at 0 (no reduction required)
    function test_bug_minFeeReductionBpsAtZero() public {
        // Deploy with 0% reduction required
        ProverAuction impl = new ProverAuction(
            inbox,
            address(bondToken),
            LIVENESS_BOND,
            MAX_PENDING_PROPOSALS,
            0, // 0% reduction required
            BOND_WITHDRAWAL_DELAY,
            FEE_DOUBLING_PERIOD,
            MAX_FEE_DOUBLINGS,
            INITIAL_MAX_FEE
        );

        ProverAuction noReductionAuction = ProverAuction(
            address(
                new ERC1967Proxy(address(impl), abi.encodeCall(ProverAuction.init, (address(this))))
            )
        );

        // Approve and deposit
        vm.prank(prover1);
        bondToken.approve(address(noReductionAuction), type(uint256).max);
        vm.prank(prover1);
        noReductionAuction.deposit(REQUIRED_BOND);

        vm.prank(prover2);
        bondToken.approve(address(noReductionAuction), type(uint256).max);
        vm.prank(prover2);
        noReductionAuction.deposit(REQUIRED_BOND);

        // First prover bids
        vm.prank(prover1);
        noReductionAuction.bid(1000 gwei);

        // getMaxBidFee should be 1000 (no reduction)
        assertEq(noReductionAuction.getMaxBidFee(), 1000 gwei);

        // Second prover can bid the same fee
        vm.prank(prover2);
        noReductionAuction.bid(1000 gwei);

        (address prover,) = noReductionAuction.getCurrentProver();
        assertEq(prover, prover2, "prover2 should be able to outbid with same fee");
    }
}
