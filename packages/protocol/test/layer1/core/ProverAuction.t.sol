// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { IProverAuction } from "src/layer1/core/iface/IProverAuction.sol";
import { ProverAuction } from "src/layer1/core/impl/ProverAuction.sol";
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
    uint16 internal constant BOND_MULTIPLIER = 10;
    uint16 internal constant MIN_FEE_REDUCTION_BPS = 500; // 5%
    uint16 internal constant REWARD_BPS = 6000; // 60%
    uint48 internal constant BOND_WITHDRAWAL_DELAY = 48 hours;
    uint48 internal constant FEE_DOUBLING_PERIOD = 15 minutes;
    uint48 internal constant MOVING_AVG_WINDOW = 30 minutes;
    uint8 internal constant MAX_FEE_DOUBLINGS = 8;
    uint32 internal constant INITIAL_MAX_FEE = 1000;
    uint8 internal constant MOVING_AVG_MULTIPLIER = 2;

    // Derived values
    uint128 internal REQUIRED_BOND;

    // Events from IProverAuction
    event Deposited(address indexed account, uint128 amount);
    event Withdrawn(address indexed account, uint128 amount);
    event BidPlaced(address indexed newProver, uint32 feeInGwei, address indexed oldProver);
    event ExitRequested(address indexed prover, uint48 withdrawableAt);
    event ProverSlashed(
        address indexed prover, uint128 slashed, address indexed recipient, uint128 rewarded
    );
    event ProverEjected(address indexed prover);

    function setUp() public virtual override {
        super.setUp();

        // Deploy bond token
        bondToken = new TestERC20("Bond Token", "BOND");

        // Calculate derived values
        REQUIRED_BOND = uint128(LIVENESS_BOND) * BOND_MULTIPLIER * 2;

        // Deploy ProverAuction
        ProverAuction impl = new ProverAuction(
            inbox,
            address(bondToken),
            LIVENESS_BOND,
            BOND_MULTIPLIER,
            MIN_FEE_REDUCTION_BPS,
            REWARD_BPS,
            BOND_WITHDRAWAL_DELAY,
            FEE_DOUBLING_PERIOD,
            MOVING_AVG_WINDOW,
            MAX_FEE_DOUBLINGS,
            INITIAL_MAX_FEE,
            MOVING_AVG_MULTIPLIER
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

    function test_minSelfBidInterval_isOneHour() public {
        assertEq(auction.MIN_SELF_BID_INTERVAL(), 1 hours);
    }

    // ---------------------------------------------------------------
    // Helper functions
    // ---------------------------------------------------------------

    function _depositAndBid(address prover, uint128 depositAmount, uint32 fee) internal {
        vm.startPrank(prover);
        auction.deposit(depositAmount);
        auction.bid(fee);
        vm.stopPrank();
    }

    function _depositBond(address prover, uint128 amount) internal {
        vm.prank(prover);
        auction.deposit(amount);
    }

    function _timeWeightedAvg(
        uint32 oldFee,
        uint32 newFee,
        uint48 elapsed
    )
        internal
        pure
        returns (uint32)
    {
        uint48 window = MOVING_AVG_WINDOW;
        uint256 weightNew = elapsed >= window ? window : elapsed;
        if (weightNew == 0) {
            weightNew = 1;
        }
        uint256 weightOld = window - weightNew;
        return uint32((uint256(oldFee) * weightOld + uint256(newFee) * weightNew) / window);
    }

    function _slashTimes(
        IProverAuction target,
        address prover,
        address recipient,
        uint256 times
    )
        internal
    {
        vm.startPrank(inbox);
        for (uint256 i = 0; i < times; i++) {
            target.slashProver(prover, recipient);
        }
        vm.stopPrank();
    }

    function _slashBelowThreshold(
        IProverAuction target,
        address prover,
        address recipient
    )
        internal
    {
        uint128 threshold = target.getEjectionThreshold();
        uint96 liveness = target.getLivenessBond();
        uint128 balance = target.getBondInfo(prover).balance;
        if (balance < threshold) return;

        uint256 slashesNeeded = (uint256(balance - threshold) / liveness) + 1;
        _slashTimes(target, prover, recipient, slashesNeeded);
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
        assertEq(auction.getLivenessBond(), LIVENESS_BOND);
        assertEq(auction.bondMultiplier(), BOND_MULTIPLIER);
        assertEq(auction.minFeeReductionBps(), MIN_FEE_REDUCTION_BPS);
        assertEq(auction.rewardBps(), REWARD_BPS);
        assertEq(auction.bondWithdrawalDelay(), BOND_WITHDRAWAL_DELAY);
        assertEq(auction.feeDoublingPeriod(), FEE_DOUBLING_PERIOD);
        assertEq(auction.maxFeeDoublings(), MAX_FEE_DOUBLINGS);
        assertEq(auction.initialMaxFee(), INITIAL_MAX_FEE);
        assertEq(auction.movingAverageMultiplier(), MOVING_AVG_MULTIPLIER);
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
        _depositAndBid(prover1, REQUIRED_BOND, 500);

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
        _depositAndBid(prover1, REQUIRED_BOND, 500);
        _depositAndBid(prover2, REQUIRED_BOND, 450); // Outbids prover1

        // prover1 should have withdrawableAt set
        IProverAuction.BondInfo memory info = auction.getBondInfo(prover1);
        assertGt(info.withdrawableAt, 0);

        // Try to withdraw before delay passes
        vm.prank(prover1);
        vm.expectRevert(ProverAuction.WithdrawalDelayNotPassed.selector);
        auction.withdraw(1 ether);
    }

    function test_withdraw_afterDelayPasses() public {
        _depositAndBid(prover1, REQUIRED_BOND, 500);
        _depositAndBid(prover2, REQUIRED_BOND, 450);

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

    function test_withdraw_exitedProverCanWithdrawAfterDelay() public {
        // Prover becomes active then exits
        _depositAndBid(prover1, REQUIRED_BOND, 500);

        vm.prank(prover1);
        auction.requestExit();

        // Verify prover is exited but still in _prover.addr
        (address currentProver,) = auction.getCurrentProver();
        assertEq(currentProver, address(0)); // getCurrentProver returns 0 for exited

        // Cannot withdraw immediately (delay not passed)
        vm.prank(prover1);
        vm.expectRevert(ProverAuction.WithdrawalDelayNotPassed.selector);
        auction.withdraw(1 ether);

        // Warp past withdrawal delay
        vm.warp(block.timestamp + BOND_WITHDRAWAL_DELAY + 1);

        // Now exited prover can withdraw
        vm.prank(prover1);
        auction.withdraw(REQUIRED_BOND);

        IProverAuction.BondInfo memory info = auction.getBondInfo(prover1);
        assertEq(info.balance, 0);
    }

    function test_withdraw_exitedProverWithdrawableAtNotExtendedByNewBid() public {
        _depositAndBid(prover1, REQUIRED_BOND, 1000);

        vm.prank(prover1);
        auction.requestExit();

        IProverAuction.BondInfo memory infoBefore = auction.getBondInfo(prover1);
        uint48 firstWithdrawableAt = infoBefore.withdrawableAt;
        assertGt(firstWithdrawableAt, 0);

        // Wait some time, then a new prover bids into the vacant slot
        vm.warp(block.timestamp + BOND_WITHDRAWAL_DELAY / 2);
        _depositAndBid(prover2, REQUIRED_BOND, 1000);

        // Exited prover's withdrawableAt should NOT be extended - they already exited
        IProverAuction.BondInfo memory infoAfter = auction.getBondInfo(prover1);
        assertEq(
            infoAfter.withdrawableAt, firstWithdrawableAt, "exited prover delay should not extend"
        );
    }

    function test_withdraw_ejectedProverCanWithdrawAfterDelay() public {
        _depositAndBid(prover1, REQUIRED_BOND, 500);

        // Eject prover by slashing below threshold
        _slashBelowThreshold(auction, prover1, address(0));

        // Verify prover was ejected
        (address currentProver,) = auction.getCurrentProver();
        assertEq(currentProver, address(0));

        // Warp past withdrawal delay
        vm.warp(block.timestamp + BOND_WITHDRAWAL_DELAY + 1);

        // Ejected prover can withdraw remaining balance
        IProverAuction.BondInfo memory infoBefore = auction.getBondInfo(prover1);
        uint128 remainingBalance = infoBefore.balance;
        assertGt(remainingBalance, 0);

        vm.prank(prover1);
        auction.withdraw(remainingBalance);

        IProverAuction.BondInfo memory infoAfter = auction.getBondInfo(prover1);
        assertEq(infoAfter.balance, 0);
    }

    // ---------------------------------------------------------------
    // getCurrentProver tests
    // ---------------------------------------------------------------

    function test_getCurrentProver_returnsZeroWhenNoProver() public view {
        (address prover, uint32 fee) = auction.getCurrentProver();
        assertEq(prover, address(0));
        assertEq(fee, 0);
    }

    function test_getCurrentProver_returnsActiveProver() public {
        _depositAndBid(prover1, REQUIRED_BOND, 500);

        (address prover, uint32 fee) = auction.getCurrentProver();
        assertEq(prover, prover1);
        assertEq(fee, 500);
    }

    function test_getCurrentProver_returnsZeroWhenProverExited() public {
        _depositAndBid(prover1, REQUIRED_BOND, 500);

        vm.prank(prover1);
        auction.requestExit();

        (address prover, uint32 fee) = auction.getCurrentProver();
        assertEq(prover, address(0));
        assertEq(fee, 0);
    }

    // ---------------------------------------------------------------
    // getMaxBidFee tests
    // ---------------------------------------------------------------

    function test_getMaxBidFee_initialVacantSlot() public view {
        // At t=0, should be initialMaxFee
        uint32 maxFee = auction.getMaxBidFee();
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

        uint32 maxFee = auction.getMaxBidFee();
        assertEq(maxFee, INITIAL_MAX_FEE * (2 ** MAX_FEE_DOUBLINGS)); // 256x
    }

    function test_getMaxBidFee_activeProverRequiresReduction() public {
        _depositAndBid(prover1, REQUIRED_BOND, 1000);

        uint32 maxFee = auction.getMaxBidFee();
        // 5% reduction: 1000 * 95% = 950
        assertEq(maxFee, 950);
    }

    function test_getMaxBidFee_afterProverExits() public {
        _depositAndBid(prover1, REQUIRED_BOND, 1000);

        vm.prank(prover1);
        auction.requestExit();

        // At exit time, max fee should be max of:
        // - exited fee (1000)
        // - fee floor = max(initialMaxFee=1000, movingAvg=1000 * multiplier=2) = 2000
        // So baseFee = max(1000, 2000) = 2000
        assertEq(auction.getMaxBidFee(), 2000);

        // After one period, should double
        vm.warp(block.timestamp + FEE_DOUBLING_PERIOD);
        assertEq(auction.getMaxBidFee(), 4000);
    }

    function test_getMaxBidFee_capsAtUint48Max() public {
        // Deploy with very high initial fee that will overflow uint48
        ProverAuction impl = new ProverAuction(
            inbox,
            address(bondToken),
            LIVENESS_BOND,
            BOND_MULTIPLIER,
            MIN_FEE_REDUCTION_BPS,
            REWARD_BPS,
            BOND_WITHDRAWAL_DELAY,
            FEE_DOUBLING_PERIOD,
            MOVING_AVG_WINDOW,
            MAX_FEE_DOUBLINGS,
            type(uint32).max / 2, // High initial fee
            MOVING_AVG_MULTIPLIER
        );

        ProverAuction highFeeAuction = ProverAuction(
            address(
                new ERC1967Proxy(address(impl), abi.encodeCall(ProverAuction.init, (address(this))))
            )
        );

        // Warp to trigger doublings that would overflow
        vm.warp(block.timestamp + FEE_DOUBLING_PERIOD * 3);

        assertEq(highFeeAuction.getMaxBidFee(), type(uint32).max);
    }

    // ---------------------------------------------------------------
    // bid tests - vacant slot
    // ---------------------------------------------------------------

    function test_bid_vacantSlot_success() public {
        _depositBond(prover1, REQUIRED_BOND);

        vm.prank(prover1);
        vm.expectEmit(true, true, false, true);
        emit BidPlaced(prover1, 500, address(0));
        auction.bid(500);

        (address prover, uint32 fee) = auction.getCurrentProver();
        assertEq(prover, prover1);
        assertEq(fee, 500);
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
        auction.bid(500);
    }

    function test_bid_vacantSlot_updatesMovingAverage() public {
        _depositAndBid(prover1, REQUIRED_BOND, 500);

        assertEq(auction.getMovingAverageFee(), 500);
    }

    // ---------------------------------------------------------------
    // bid tests - outbidding another prover
    // ---------------------------------------------------------------

    function test_bid_outbid_success() public {
        _depositAndBid(prover1, REQUIRED_BOND, 1000);
        _depositBond(prover2, REQUIRED_BOND);

        vm.prank(prover2);
        vm.expectEmit(true, true, false, true);
        emit BidPlaced(prover2, 950, prover1);
        auction.bid(950); // 5% reduction

        (address prover, uint32 fee) = auction.getCurrentProver();
        assertEq(prover, prover2);
        assertEq(fee, 950);
    }

    function test_bid_outbid_setsWithdrawableAt() public {
        _depositAndBid(prover1, REQUIRED_BOND, 1000);
        _depositAndBid(prover2, REQUIRED_BOND, 950);

        IProverAuction.BondInfo memory info = auction.getBondInfo(prover1);
        assertEq(info.withdrawableAt, uint48(block.timestamp) + BOND_WITHDRAWAL_DELAY);
    }

    function test_bid_outbid_RevertWhen_InsufficientReduction() public {
        _depositAndBid(prover1, REQUIRED_BOND, 1000);
        _depositBond(prover2, REQUIRED_BOND);

        vm.prank(prover2);
        vm.expectRevert(ProverAuction.FeeTooHigh.selector);
        auction.bid(951); // Less than 5% reduction
    }

    function test_bid_outbid_exactMinReduction() public {
        _depositAndBid(prover1, REQUIRED_BOND, 1000);
        _depositBond(prover2, REQUIRED_BOND);

        vm.prank(prover2);
        auction.bid(950); // Exactly 5% reduction

        (address prover,) = auction.getCurrentProver();
        assertEq(prover, prover2);
    }

    function test_bid_outbid_RevertWhen_CurrentFeeZero() public {
        _depositAndBid(prover1, REQUIRED_BOND, 0);
        _depositBond(prover2, REQUIRED_BOND);

        vm.prank(prover2);
        vm.expectRevert(ProverAuction.FeeMustBeLower.selector);
        auction.bid(0);
    }

    // ---------------------------------------------------------------
    // bid tests - self bid (current prover lowering fee)
    // ---------------------------------------------------------------

    function test_bid_selfBid_lowersFee() public {
        _depositAndBid(prover1, REQUIRED_BOND, 1000);

        // Wait for minimum self-bid interval
        vm.warp(block.timestamp + auction.MIN_SELF_BID_INTERVAL());

        vm.prank(prover1);
        vm.expectEmit(true, true, false, true);
        emit BidPlaced(prover1, 900, prover1);
        auction.bid(900);

        (address prover, uint32 fee) = auction.getCurrentProver();
        assertEq(prover, prover1);
        assertEq(fee, 900);
    }

    function test_bid_selfBid_noMinReductionRequired() public {
        _depositAndBid(prover1, REQUIRED_BOND, 1000);

        // Wait for minimum self-bid interval
        vm.warp(block.timestamp + auction.MIN_SELF_BID_INTERVAL());

        // Can lower by just 1 gwei
        vm.prank(prover1);
        auction.bid(999);

        (, uint32 fee) = auction.getCurrentProver();
        assertEq(fee, 999);
    }

    function test_bid_selfBid_RevertWhen_FeeNotLower() public {
        _depositAndBid(prover1, REQUIRED_BOND, 1000);

        // Wait for minimum self-bid interval
        vm.warp(block.timestamp + auction.MIN_SELF_BID_INTERVAL());

        vm.prank(prover1);
        vm.expectRevert(ProverAuction.FeeMustBeLower.selector);
        auction.bid(1000);
    }

    function test_bid_selfBid_RevertWhen_FeeHigher() public {
        _depositAndBid(prover1, REQUIRED_BOND, 1000);

        // Wait for minimum self-bid interval
        vm.warp(block.timestamp + auction.MIN_SELF_BID_INTERVAL());

        vm.prank(prover1);
        vm.expectRevert(ProverAuction.FeeMustBeLower.selector);
        auction.bid(1001);
    }

    function test_bid_selfBid_updatesMovingAverage() public {
        _depositAndBid(prover1, REQUIRED_BOND, 1000);
        assertEq(auction.getMovingAverageFee(), 1000);

        // Wait for minimum self-bid interval
        uint48 waitTime = auction.MIN_SELF_BID_INTERVAL();
        vm.warp(block.timestamp + waitTime);

        vm.prank(prover1);
        auction.bid(100);

        uint32 expected = _timeWeightedAvg(1000, 100, waitTime);
        assertEq(auction.getMovingAverageFee(), expected);
    }

    function test_bid_selfBid_RevertWhen_TooFrequent() public {
        _depositAndBid(prover1, REQUIRED_BOND, 1000);

        // Try to self-bid immediately without waiting
        vm.prank(prover1);
        vm.expectRevert(ProverAuction.SelfBidTooFrequent.selector);
        auction.bid(900);
    }

    // ---------------------------------------------------------------
    // bid tests - re-entering after exit
    // ---------------------------------------------------------------

    function test_bid_reenterClearsWithdrawableAt() public {
        _depositAndBid(prover1, REQUIRED_BOND, 1000);

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
        _depositAndBid(prover1, REQUIRED_BOND, 500);

        vm.prank(prover1);
        vm.expectEmit(true, false, false, true);
        emit ExitRequested(prover1, uint48(block.timestamp) + BOND_WITHDRAWAL_DELAY);
        auction.requestExit();

        (address prover,) = auction.getCurrentProver();
        assertEq(prover, address(0)); // No active prover
    }

    function test_requestExit_setsWithdrawableAt() public {
        _depositAndBid(prover1, REQUIRED_BOND, 500);

        vm.prank(prover1);
        auction.requestExit();

        IProverAuction.BondInfo memory info = auction.getBondInfo(prover1);
        assertEq(info.withdrawableAt, uint48(block.timestamp) + BOND_WITHDRAWAL_DELAY);
    }

    function test_requestExit_RevertWhen_NotCurrentProver() public {
        _depositAndBid(prover1, REQUIRED_BOND, 500);

        vm.prank(prover2);
        vm.expectRevert(ProverAuction.NotCurrentProver.selector);
        auction.requestExit();
    }

    function test_requestExit_RevertWhen_AlreadyExited() public {
        _depositAndBid(prover1, REQUIRED_BOND, 500);

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
    // slashProver tests
    // ---------------------------------------------------------------

    function test_slashProver_success() public {
        _depositAndBid(prover1, REQUIRED_BOND, 500);

        uint128 expectedSlash = uint128(LIVENESS_BOND);
        uint128 expectedReward = uint128(uint256(expectedSlash) * REWARD_BPS / 10_000);
        uint128 expectedSlashedTotal = expectedSlash - expectedReward;

        vm.prank(inbox);
        vm.expectEmit(true, true, false, true);
        emit ProverSlashed(prover1, expectedSlash, prover2, expectedReward);
        auction.slashProver(prover1, prover2);

        IProverAuction.BondInfo memory info = auction.getBondInfo(prover1);
        assertEq(info.balance, REQUIRED_BOND - expectedSlash);

        // Reward sent to recipient
        assertEq(bondToken.balanceOf(prover2), 1000 ether + expectedReward);

        // Slash diff tracked
        assertEq(auction.getTotalSlashedAmount(), expectedSlashedTotal);
    }

    function test_slashProver_RevertWhen_NotInbox() public {
        _depositAndBid(prover1, REQUIRED_BOND, 500);

        vm.prank(prover2);
        vm.expectRevert(ProverAuction.OnlyInbox.selector);
        auction.slashProver(prover1, prover2);
    }

    function test_slashProver_bestEffortSlash() public {
        uint128 depositAmount = 0.5 ether;
        _depositBond(prover1, depositAmount);

        vm.prank(inbox);
        auction.slashProver(prover1, prover2);

        // Only slashes available balance
        IProverAuction.BondInfo memory info = auction.getBondInfo(prover1);
        assertEq(info.balance, 0);

        // Reward uses actual slashed amount
        uint128 expectedReward = uint128(uint256(depositAmount) * REWARD_BPS / 10_000);
        assertEq(bondToken.balanceOf(prover2), 1000 ether + expectedReward);
    }

    function test_slashProver_rewardUsesPercent() public {
        _depositBond(prover1, 2 ether);

        uint128 expectedSlash = uint128(LIVENESS_BOND);
        uint128 expectedReward = uint128(uint256(expectedSlash) * REWARD_BPS / 10_000);

        vm.prank(inbox);
        auction.slashProver(prover1, prover2);

        assertEq(bondToken.balanceOf(prover2), 1000 ether + expectedReward);
    }

    function test_slashProver_noRewardWhenRecipientZero() public {
        _depositBond(prover1, 1 ether);

        uint256 recipientBalanceBefore = bondToken.balanceOf(prover2);

        vm.prank(inbox);
        auction.slashProver(prover1, address(0));

        // No transfer to zero address
        assertEq(bondToken.balanceOf(prover2), recipientBalanceBefore);

        IProverAuction.BondInfo memory info = auction.getBondInfo(prover1);
        assertEq(info.balance, 0);
        assertEq(auction.getTotalSlashedAmount(), uint128(LIVENESS_BOND));
    }

    function test_slashProver_ejectionWhenBelowThreshold() public {
        _depositAndBid(prover1, REQUIRED_BOND, 500);

        uint128 threshold = auction.getEjectionThreshold();
        uint128 balance = auction.getBondInfo(prover1).balance;
        uint96 liveness = auction.getLivenessBond();
        uint256 slashesToThreshold = uint256(balance - threshold) / liveness;
        _slashTimes(auction, prover1, prover2, slashesToThreshold);

        vm.prank(inbox);
        vm.expectEmit(true, false, false, false);
        emit ProverEjected(prover1);
        auction.slashProver(prover1, prover2);

        (address prover,) = auction.getCurrentProver();
        assertEq(prover, address(0)); // Ejected
    }

    function test_slashProver_noEjectionWhenAboveThreshold() public {
        _depositAndBid(prover1, REQUIRED_BOND, 500);

        vm.prank(inbox);
        auction.slashProver(prover1, prover2);

        (address prover,) = auction.getCurrentProver();
        assertEq(prover, prover1); // Still active
    }

    function test_slashProver_noEjectionWhenNotCurrentProver() public {
        _depositAndBid(prover1, REQUIRED_BOND, 500);
        _depositBond(prover2, 1 ether);

        vm.prank(inbox);
        auction.slashProver(prover2, prover3);

        // prover1 still active (not affected)
        (address prover,) = auction.getCurrentProver();
        assertEq(prover, prover1);
    }

    function test_slashProver_ejectionSetsWithdrawableAt() public {
        _depositAndBid(prover1, REQUIRED_BOND, 500);

        _slashBelowThreshold(auction, prover1, prover2);

        IProverAuction.BondInfo memory info = auction.getBondInfo(prover1);
        assertEq(info.withdrawableAt, uint48(block.timestamp) + BOND_WITHDRAWAL_DELAY);
    }

    // ---------------------------------------------------------------
    // checkBondDeferWithdrawal tests
    // ---------------------------------------------------------------

    function test_checkBondDeferWithdrawal_updatesWithdrawableAtWhenSet() public {
        _depositAndBid(prover1, REQUIRED_BOND, 500);
        _depositAndBid(prover2, REQUIRED_BOND, 450);

        IProverAuction.BondInfo memory infoBefore = auction.getBondInfo(prover1);
        uint48 withdrawableAtBefore = infoBefore.withdrawableAt;
        assertGt(withdrawableAtBefore, 0);

        vm.warp(block.timestamp + 1 hours);

        vm.prank(inbox);
        bool success = auction.checkBondDeferWithdrawal(prover1);
        assertTrue(success);

        IProverAuction.BondInfo memory infoAfter = auction.getBondInfo(prover1);
        assertEq(infoAfter.withdrawableAt, uint48(block.timestamp) + BOND_WITHDRAWAL_DELAY);
        assertGt(infoAfter.withdrawableAt, withdrawableAtBefore);
    }

    function test_checkBondDeferWithdrawal_updatesWithdrawableAtWhenNotCurrent() public {
        _depositBond(prover1, REQUIRED_BOND);

        vm.prank(inbox);
        bool success = auction.checkBondDeferWithdrawal(prover1);
        assertTrue(success);

        IProverAuction.BondInfo memory info = auction.getBondInfo(prover1);
        assertEq(info.withdrawableAt, uint48(block.timestamp) + BOND_WITHDRAWAL_DELAY);
    }

    function test_checkBondDeferWithdrawal_noopForCurrentWithZeroWithdrawableAt() public {
        _depositAndBid(prover1, REQUIRED_BOND, 500);

        IProverAuction.BondInfo memory infoBefore = auction.getBondInfo(prover1);
        assertEq(infoBefore.withdrawableAt, 0);

        vm.prank(inbox);
        bool success = auction.checkBondDeferWithdrawal(prover1);
        assertTrue(success);

        IProverAuction.BondInfo memory infoAfter = auction.getBondInfo(prover1);
        assertEq(infoAfter.withdrawableAt, 0);
    }

    function test_checkBondDeferWithdrawal_returnsFalseWhen_BelowThreshold() public {
        _depositBond(prover1, uint128(LIVENESS_BOND));

        vm.prank(inbox);
        bool success = auction.checkBondDeferWithdrawal(prover1);
        assertFalse(success);
    }

    function test_checkBondDeferWithdrawal_RevertWhen_NotInbox() public {
        _depositBond(prover1, REQUIRED_BOND);

        vm.prank(prover1);
        vm.expectRevert(ProverAuction.OnlyInbox.selector);
        auction.checkBondDeferWithdrawal(prover1);
    }

    // ---------------------------------------------------------------
    // View function tests
    // ---------------------------------------------------------------

    function test_getRequiredBond() public view {
        assertEq(auction.getRequiredBond(), uint128(LIVENESS_BOND) * BOND_MULTIPLIER * 2);
    }

    function test_getEjectionThreshold() public view {
        assertEq(auction.getEjectionThreshold(), uint128(LIVENESS_BOND) * BOND_MULTIPLIER);
    }

    function test_getMovingAverageFee_initial() public view {
        assertEq(auction.getMovingAverageFee(), 0);
    }

    function test_getMovingAverageFee_afterBids() public {
        _depositAndBid(prover1, REQUIRED_BOND, 1000);
        assertEq(auction.getMovingAverageFee(), 1000);

        // Outbid with lower fee
        vm.warp(block.timestamp + MOVING_AVG_WINDOW / 10);
        _depositAndBid(prover2, REQUIRED_BOND, 900);
        uint32 expected = _timeWeightedAvg(1000, 900, MOVING_AVG_WINDOW / 10);
        assertEq(auction.getMovingAverageFee(), expected);
    }

    function test_getTotalSlashedAmount_initial() public view {
        assertEq(auction.getTotalSlashedAmount(), 0);
    }

    function test_getTotalSlashedAmount_afterSlash() public {
        _depositBond(prover1, 10 ether);

        uint128 expectedSlash = uint128(LIVENESS_BOND);
        uint128 expectedReward = uint128(uint256(expectedSlash) * REWARD_BPS / 10_000);

        vm.prank(inbox);
        auction.slashProver(prover1, prover2);

        assertEq(auction.getTotalSlashedAmount(), expectedSlash - expectedReward);
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
        _depositAndBid(prover1, REQUIRED_BOND, 500);
        assertEq(auction.getMovingAverageFee(), 500);
    }

    function test_movingAverage_sameBlockSelfBidReverts() public {
        _depositAndBid(prover1, REQUIRED_BOND, 1000);

        // Same-block self-bids are disallowed to prevent MA manipulation
        vm.prank(prover1);
        vm.expectRevert(ProverAuction.SelfBidTooFrequent.selector);
        auction.bid(900);
    }

    function test_movingAverage_subsequentBidsUseTimeWeightedAverage() public {
        _depositAndBid(prover1, REQUIRED_BOND, 1000);

        // Self-bid to lower fee multiple times (must wait MIN_SELF_BID_INTERVAL between each)
        vm.startPrank(prover1);

        vm.warp(block.timestamp + auction.MIN_SELF_BID_INTERVAL());
        auction.bid(100);
        uint32 expectedFirst = _timeWeightedAvg(1000, 100, auction.MIN_SELF_BID_INTERVAL());
        assertEq(auction.getMovingAverageFee(), expectedFirst);

        vm.warp(block.timestamp + auction.MIN_SELF_BID_INTERVAL());
        auction.bid(99);
        uint32 expectedSecond = _timeWeightedAvg(expectedFirst, 99, auction.MIN_SELF_BID_INTERVAL());
        assertEq(auction.getMovingAverageFee(), expectedSecond);

        vm.stopPrank();
    }

    // ---------------------------------------------------------------
    // Edge case tests
    // ---------------------------------------------------------------

    function test_bidWithZeroFee() public {
        _depositBond(prover1, REQUIRED_BOND);

        vm.prank(prover1);
        auction.bid(0);

        (, uint32 fee) = auction.getCurrentProver();
        assertEq(fee, 0);
    }

    function test_multipleProversCompeting() public {
        _depositAndBid(prover1, REQUIRED_BOND, 1000);
        _depositAndBid(prover2, REQUIRED_BOND, 950);
        _depositAndBid(prover3, REQUIRED_BOND, 902);

        (address prover, uint32 fee) = auction.getCurrentProver();
        assertEq(prover, prover3);
        assertEq(fee, 902);
    }

    function test_proverReentersAfterBeingOutbid() public {
        _depositAndBid(prover1, REQUIRED_BOND, 1000);
        _depositAndBid(prover2, REQUIRED_BOND, 950);

        // Wait for withdrawal delay
        vm.warp(block.timestamp + BOND_WITHDRAWAL_DELAY + 1);

        // Prover1 bids again
        vm.prank(prover1);
        auction.bid(900);

        (address prover,) = auction.getCurrentProver();
        assertEq(prover, prover1);
    }

    function test_proverReentersAfterExit() public {
        _depositAndBid(prover1, REQUIRED_BOND, 1000);

        vm.prank(prover1);
        auction.requestExit();

        // Re-enter immediately (within first doubling period)
        vm.prank(prover1);
        auction.bid(1000);

        (address prover,) = auction.getCurrentProver();
        assertEq(prover, prover1);
    }

    // ---------------------------------------------------------------
    // Pause behavior tests
    // ---------------------------------------------------------------
    // NOTE: These tests document CURRENT behavior where entrypoints DO NOT have
    // whenNotPaused modifiers and can still be called when paused.

    function test_pause_deposit_worksWhenPaused() public {
        // Pause the contract
        auction.pause();
        assertTrue(auction.paused());

        // Deposit should still work (no whenNotPaused modifier)
        vm.prank(prover1);
        auction.deposit(10 ether);

        IProverAuction.BondInfo memory info = auction.getBondInfo(prover1);
        assertEq(info.balance, 10 ether, "deposit should work when paused");
    }

    function test_pause_withdraw_worksWhenPaused() public {
        // Setup: deposit first
        _depositBond(prover1, 10 ether);

        // Pause the contract
        auction.pause();
        assertTrue(auction.paused());

        // Withdraw should still work (no whenNotPaused modifier)
        vm.prank(prover1);
        auction.withdraw(5 ether);

        IProverAuction.BondInfo memory info = auction.getBondInfo(prover1);
        assertEq(info.balance, 5 ether, "withdraw should work when paused");
    }

    function test_pause_bid_worksWhenPaused() public {
        // Setup: deposit bond
        _depositBond(prover1, REQUIRED_BOND);

        // Pause the contract
        auction.pause();
        assertTrue(auction.paused());

        // Bid should still work (no whenNotPaused modifier)
        vm.prank(prover1);
        auction.bid(500);

        (address prover, uint32 fee) = auction.getCurrentProver();
        assertEq(prover, prover1, "bid should work when paused");
        assertEq(fee, 500);
    }

    function test_pause_requestExit_worksWhenPaused() public {
        // Setup: become active prover
        _depositAndBid(prover1, REQUIRED_BOND, 500);

        // Pause the contract
        auction.pause();
        assertTrue(auction.paused());

        // requestExit should still work (no whenNotPaused modifier)
        vm.prank(prover1);
        auction.requestExit();

        (address prover,) = auction.getCurrentProver();
        assertEq(prover, address(0), "requestExit should work when paused");
    }

    function test_pause_slashProver_worksWhenPaused() public {
        // Setup: become active prover
        _depositAndBid(prover1, REQUIRED_BOND, 500);

        // Pause the contract
        auction.pause();
        assertTrue(auction.paused());

        // slashProver should still work (no whenNotPaused modifier)
        vm.prank(inbox);
        auction.slashProver(prover1, prover2);

        IProverAuction.BondInfo memory info = auction.getBondInfo(prover1);
        assertEq(
            info.balance,
            REQUIRED_BOND - uint128(LIVENESS_BOND),
            "slashProver should work when paused"
        );
    }

    function test_pause_unpause_allowsOperations() public {
        // Pause
        auction.pause();
        assertTrue(auction.paused());

        // Unpause
        auction.unpause();
        assertFalse(auction.paused());

        // Verify operations work after unpause
        _depositAndBid(prover1, REQUIRED_BOND, 500);
        (address prover,) = auction.getCurrentProver();
        assertEq(prover, prover1, "operations should work after unpause");
    }

    // ---------------------------------------------------------------
    // bondWithdrawalDelay == 0 configuration tests
    // ---------------------------------------------------------------
    // NOTE: These tests document behavior when bondWithdrawalDelay is set to 0

    function test_zeroWithdrawalDelay_outbidProverWithdrawsImmediately() public {
        // Deploy auction with 0 withdrawal delay
        ProverAuction impl = new ProverAuction(
            inbox,
            address(bondToken),
            LIVENESS_BOND,
            BOND_MULTIPLIER,
            MIN_FEE_REDUCTION_BPS,
            REWARD_BPS,
            0, // bondWithdrawalDelay = 0
            FEE_DOUBLING_PERIOD,
            MOVING_AVG_WINDOW,
            MAX_FEE_DOUBLINGS,
            INITIAL_MAX_FEE,
            MOVING_AVG_MULTIPLIER
        );

        ProverAuction zeroDelayAuction = ProverAuction(
            address(
                new ERC1967Proxy(address(impl), abi.encodeCall(ProverAuction.init, (address(this))))
            )
        );

        // Setup approvals
        vm.prank(prover1);
        bondToken.approve(address(zeroDelayAuction), type(uint256).max);
        vm.prank(prover2);
        bondToken.approve(address(zeroDelayAuction), type(uint256).max);

        // Prover1 bids
        vm.startPrank(prover1);
        zeroDelayAuction.deposit(REQUIRED_BOND);
        zeroDelayAuction.bid(1000);
        vm.stopPrank();

        // Prover2 outbids prover1
        vm.startPrank(prover2);
        zeroDelayAuction.deposit(REQUIRED_BOND);
        zeroDelayAuction.bid(950);
        vm.stopPrank();

        // Check prover1's withdrawableAt is set to current timestamp (0 + 0)
        IProverAuction.BondInfo memory info = zeroDelayAuction.getBondInfo(prover1);
        assertEq(
            info.withdrawableAt, uint48(block.timestamp), "withdrawableAt should be block.timestamp"
        );

        // Prover1 can withdraw immediately (no need to warp time)
        vm.prank(prover1);
        zeroDelayAuction.withdraw(REQUIRED_BOND);

        IProverAuction.BondInfo memory infoAfter = zeroDelayAuction.getBondInfo(prover1);
        assertEq(infoAfter.balance, 0, "prover1 should be able to withdraw immediately");
    }

    function test_zeroWithdrawalDelay_exitedProverWithdrawsImmediately() public {
        // Deploy auction with 0 withdrawal delay
        ProverAuction impl = new ProverAuction(
            inbox,
            address(bondToken),
            LIVENESS_BOND,
            BOND_MULTIPLIER,
            MIN_FEE_REDUCTION_BPS,
            REWARD_BPS,
            0, // bondWithdrawalDelay = 0
            FEE_DOUBLING_PERIOD,
            MOVING_AVG_WINDOW,
            MAX_FEE_DOUBLINGS,
            INITIAL_MAX_FEE,
            MOVING_AVG_MULTIPLIER
        );

        ProverAuction zeroDelayAuction = ProverAuction(
            address(
                new ERC1967Proxy(address(impl), abi.encodeCall(ProverAuction.init, (address(this))))
            )
        );

        // Setup approvals and deposit
        vm.prank(prover1);
        bondToken.approve(address(zeroDelayAuction), type(uint256).max);
        vm.startPrank(prover1);
        zeroDelayAuction.deposit(REQUIRED_BOND);
        zeroDelayAuction.bid(1000);
        vm.stopPrank();

        // Request exit
        vm.prank(prover1);
        zeroDelayAuction.requestExit();

        // Check withdrawableAt is set to current timestamp
        IProverAuction.BondInfo memory info = zeroDelayAuction.getBondInfo(prover1);
        assertEq(
            info.withdrawableAt, uint48(block.timestamp), "withdrawableAt should be block.timestamp"
        );

        // Can withdraw immediately
        vm.prank(prover1);
        zeroDelayAuction.withdraw(REQUIRED_BOND);

        IProverAuction.BondInfo memory infoAfter = zeroDelayAuction.getBondInfo(prover1);
        assertEq(infoAfter.balance, 0, "exited prover should withdraw immediately with zero delay");
    }

    function test_zeroWithdrawalDelay_ejectedProverWithdrawsImmediately() public {
        // Deploy auction with 0 withdrawal delay
        ProverAuction impl = new ProverAuction(
            inbox,
            address(bondToken),
            LIVENESS_BOND,
            BOND_MULTIPLIER,
            MIN_FEE_REDUCTION_BPS,
            REWARD_BPS,
            0, // bondWithdrawalDelay = 0
            FEE_DOUBLING_PERIOD,
            MOVING_AVG_WINDOW,
            MAX_FEE_DOUBLINGS,
            INITIAL_MAX_FEE,
            MOVING_AVG_MULTIPLIER
        );

        ProverAuction zeroDelayAuction = ProverAuction(
            address(
                new ERC1967Proxy(address(impl), abi.encodeCall(ProverAuction.init, (address(this))))
            )
        );

        // Setup approvals and deposit
        vm.prank(prover1);
        bondToken.approve(address(zeroDelayAuction), type(uint256).max);
        vm.startPrank(prover1);
        zeroDelayAuction.deposit(REQUIRED_BOND);
        zeroDelayAuction.bid(1000);
        vm.stopPrank();

        // Eject by slashing below threshold
        _slashBelowThreshold(zeroDelayAuction, prover1, address(0));

        // Verify ejected
        (address prover,) = zeroDelayAuction.getCurrentProver();
        assertEq(prover, address(0), "prover should be ejected");

        // Check withdrawableAt is set to current timestamp
        IProverAuction.BondInfo memory info = zeroDelayAuction.getBondInfo(prover1);
        assertEq(
            info.withdrawableAt, uint48(block.timestamp), "withdrawableAt should be block.timestamp"
        );

        // Can withdraw immediately
        uint128 remainingBalance = info.balance;
        vm.prank(prover1);
        zeroDelayAuction.withdraw(remainingBalance);

        IProverAuction.BondInfo memory infoAfter = zeroDelayAuction.getBondInfo(prover1);
        assertEq(infoAfter.balance, 0, "ejected prover should withdraw immediately with zero delay");
    }

    function test_zeroWithdrawalDelay_getterReturnsZero() public view {
        // Using default auction which has BOND_WITHDRAWAL_DELAY set to 48 hours
        assertEq(auction.bondWithdrawalDelay(), BOND_WITHDRAWAL_DELAY);
    }

    function test_zeroWithdrawalDelay_immutableSetCorrectly() public {
        // Deploy with zero delay and verify it's set correctly
        ProverAuction impl = new ProverAuction(
            inbox,
            address(bondToken),
            LIVENESS_BOND,
            BOND_MULTIPLIER,
            MIN_FEE_REDUCTION_BPS,
            REWARD_BPS,
            0, // bondWithdrawalDelay = 0
            FEE_DOUBLING_PERIOD,
            MOVING_AVG_WINDOW,
            MAX_FEE_DOUBLINGS,
            INITIAL_MAX_FEE,
            MOVING_AVG_MULTIPLIER
        );

        assertEq(impl.bondWithdrawalDelay(), 0, "bondWithdrawalDelay should be 0");
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
        _depositAndBid(prover1, REQUIRED_BOND, 1000);

        // Step 2: Prover2 outbids prover1
        _depositAndBid(prover2, REQUIRED_BOND, 950);

        // Step 3: Prover1 should have withdrawableAt set
        IProverAuction.BondInfo memory info1 = auction.getBondInfo(prover1);
        uint48 originalWithdrawableAt = info1.withdrawableAt;
        assertGt(
            originalWithdrawableAt, 0, "prover1 should have withdrawableAt set after being outbid"
        );

        // Step 4: Prover1 re-enters immediately (bypasses delay by bidding)
        vm.prank(prover1);
        auction.bid(900);

        // Step 5: withdrawableAt should be cleared
        IProverAuction.BondInfo memory info2 = auction.getBondInfo(prover1);
        assertEq(info2.withdrawableAt, 0, "withdrawableAt should be cleared after re-entry");

        // Step 6: Prover1 cannot withdraw while being current prover
        vm.prank(prover1);
        vm.expectRevert(ProverAuction.CurrentProverCannotWithdraw.selector);
        auction.withdraw(1 ether);

        // Step 7: Prover3 outbids prover1
        _depositAndBid(prover3, REQUIRED_BOND, 855);

        // Step 8: Prover1 should have a NEW withdrawableAt set
        IProverAuction.BondInfo memory info3 = auction.getBondInfo(prover1);
        assertGt(
            info3.withdrawableAt,
            0,
            "prover1 should have new withdrawableAt after being outbid again"
        );

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
        _depositAndBid(prover1, REQUIRED_BOND, 1000);
        _depositAndBid(prover2, REQUIRED_BOND, 950);

        // Record the first withdrawableAt
        IProverAuction.BondInfo memory info1 = auction.getBondInfo(prover1);
        uint48 firstWithdrawableAt = info1.withdrawableAt;
        assertEq(firstWithdrawableAt, uint48(startTime) + BOND_WITHDRAWAL_DELAY);

        // Time passes but not enough for withdrawal
        vm.warp(startTime + BOND_WITHDRAWAL_DELAY / 2);

        // Prover1 re-enters
        vm.prank(prover1);
        auction.bid(900);

        // withdrawableAt is now 0
        IProverAuction.BondInfo memory info2 = auction.getBondInfo(prover1);
        assertEq(info2.withdrawableAt, 0);

        // Prover2 outbids again
        vm.prank(prover2);
        auction.bid(855);

        // NEW withdrawableAt is set based on current time
        IProverAuction.BondInfo memory info3 = auction.getBondInfo(prover1);
        uint48 secondWithdrawableAt = info3.withdrawableAt;
        assertEq(secondWithdrawableAt, uint48(block.timestamp) + BOND_WITHDRAWAL_DELAY);

        // The second withdrawableAt is LATER than the first would have been
        // This means re-entry actually EXTENDS the wait time, not bypasses it
        assertGt(
            secondWithdrawableAt, firstWithdrawableAt, "second delay should be later than first"
        );
    }

    /// @notice Issue 2.6: Test that initialMaxFee = 0 is now rejected (FIXED)
    function test_bug_getMaxBidFeeWithZeroBaseFee() public {
        // Deploy auction with initialMaxFee = 0 should now revert
        vm.expectRevert(ProverAuction.ZeroValue.selector);
        new ProverAuction(
            inbox,
            address(bondToken),
            LIVENESS_BOND,
            BOND_MULTIPLIER,
            MIN_FEE_REDUCTION_BPS,
            REWARD_BPS,
            BOND_WITHDRAWAL_DELAY,
            FEE_DOUBLING_PERIOD,
            MOVING_AVG_WINDOW,
            MAX_FEE_DOUBLINGS,
            0, // initialMaxFee = 0 - now rejected
            MOVING_AVG_MULTIPLIER
        );

        // FIXED: Constructor now validates that initialMaxFee > 0
        // This prevents the slot from being permanently stuck at 0 fee
    }

    /// @notice Issue 2.6 variant: Test what happens when a prover exits with fee 0 (FIXED)
    function test_bug_proverExitsWithZeroFee() public {
        // First, bid with 0 fee (already tested this works)
        _depositBond(prover1, REQUIRED_BOND);
        vm.prank(prover1);
        auction.bid(0);

        // Exit
        vm.prank(prover1);
        auction.requestExit();

        // After fix: Max fee should fall back to initialMaxFee when exited prover had fee 0
        assertEq(auction.getMaxBidFee(), INITIAL_MAX_FEE, "should fall back to initialMaxFee");

        // After time passes, it should double from initialMaxFee
        vm.warp(block.timestamp + FEE_DOUBLING_PERIOD);
        assertEq(auction.getMaxBidFee(), INITIAL_MAX_FEE * 2, "should double from initialMaxFee");

        // FIXED: If a prover exits with fee 0, the slot falls back to initialMaxFee
        // instead of being permanently stuck at 0
    }

    /// @notice Issue 2.7: Test that ejection is skipped for already-exited prover (FIXED)
    function test_bug_ejectionOnAlreadyExitedProver() public {
        _depositAndBid(prover1, REQUIRED_BOND, 500);

        // Prover exits voluntarily
        vm.prank(prover1);
        auction.requestExit();

        IProverAuction.BondInfo memory infoBefore = auction.getBondInfo(prover1);
        uint48 exitWithdrawableAt = infoBefore.withdrawableAt;

        // Advance time a bit
        vm.warp(block.timestamp + 1 hours);

        // Slash the already-exited prover below threshold
        _slashBelowThreshold(auction, prover1, prover2);

        // After optimization: ejection logic is skipped for already-exited provers
        // So withdrawableAt should remain unchanged (the original exit time)
        IProverAuction.BondInfo memory infoAfter = auction.getBondInfo(prover1);
        assertEq(
            infoAfter.withdrawableAt,
            exitWithdrawableAt,
            "withdrawableAt should not change for already-exited"
        );
    }

    /// @notice Issue 4.3: Test slash when balance exactly equals threshold
    function test_bug_slashAtExactThreshold() public {
        _depositAndBid(prover1, REQUIRED_BOND, 500);

        uint128 threshold = auction.getEjectionThreshold();
        uint128 balance = auction.getBondInfo(prover1).balance;
        uint96 liveness = auction.getLivenessBond();
        uint256 slashesToThreshold = uint256(balance - threshold) / liveness;
        _slashTimes(auction, prover1, prover2, slashesToThreshold);

        // Should NOT be ejected (balance == threshold, not < threshold)
        (address prover,) = auction.getCurrentProver();
        assertEq(prover, prover1, "prover should not be ejected at exact threshold");

        IProverAuction.BondInfo memory info = auction.getBondInfo(prover1);
        assertEq(info.balance, threshold);
    }

    /// @notice Issue 4.3 variant: Test slash to just below threshold
    function test_bug_slashJustBelowThreshold() public {
        _depositAndBid(prover1, REQUIRED_BOND, 500);

        uint128 threshold = auction.getEjectionThreshold();
        uint128 balance = auction.getBondInfo(prover1).balance;
        uint96 liveness = auction.getLivenessBond();
        uint256 slashesToBelow = uint256(balance - threshold) / liveness + 1;
        _slashTimes(auction, prover1, prover2, slashesToBelow);

        // Should be ejected
        (address prover,) = auction.getCurrentProver();
        assertEq(prover, address(0), "prover should be ejected below threshold");
    }

    /// @notice Issue 2.3: Test minFeeReductionBps at boundary values
    function test_bug_minFeeReductionBpsAt10000() public {
        // Deploy with 100% reduction required (should make outbidding impossible except with 0)
        ProverAuction impl = new ProverAuction(
            inbox,
            address(bondToken),
            LIVENESS_BOND,
            BOND_MULTIPLIER,
            10_000, // 100% reduction required
            REWARD_BPS,
            BOND_WITHDRAWAL_DELAY,
            FEE_DOUBLING_PERIOD,
            MOVING_AVG_WINDOW,
            MAX_FEE_DOUBLINGS,
            INITIAL_MAX_FEE,
            MOVING_AVG_MULTIPLIER
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
        maxReductionAuction.bid(1000);

        // getMaxBidFee should be 0 (1000 * (10000 - 10000) / 10000 = 0)
        assertEq(maxReductionAuction.getMaxBidFee(), 0);

        // Second prover can only bid 0
        vm.prank(prover2);
        maxReductionAuction.bid(0);

        (, uint32 fee) = maxReductionAuction.getCurrentProver();
        assertEq(fee, 0);
    }

    /// @notice Issue 2.3 variant: Test minFeeReductionBps at 0 (no reduction required)
    function test_bug_minFeeReductionBpsAtZero() public {
        // Deploy with 0% reduction required
        ProverAuction impl = new ProverAuction(
            inbox,
            address(bondToken),
            LIVENESS_BOND,
            BOND_MULTIPLIER,
            0, // 0% reduction required
            REWARD_BPS,
            BOND_WITHDRAWAL_DELAY,
            FEE_DOUBLING_PERIOD,
            MOVING_AVG_WINDOW,
            MAX_FEE_DOUBLINGS,
            INITIAL_MAX_FEE,
            MOVING_AVG_MULTIPLIER
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
        noReductionAuction.bid(1000);

        // getMaxBidFee should be 1000 (no reduction)
        assertEq(noReductionAuction.getMaxBidFee(), 1000);

        // Second prover cannot bid the same fee (must be strictly lower)
        vm.prank(prover2);
        vm.expectRevert(ProverAuction.FeeMustBeLower.selector);
        noReductionAuction.bid(1000);

        // Second prover can bid a lower fee
        vm.prank(prover2);
        noReductionAuction.bid(999);

        (address prover,) = noReductionAuction.getCurrentProver();
        assertEq(prover, prover2, "prover2 should be able to outbid with lower fee");
    }

    /// @notice Test that movingAverageMultiplier = 0 is rejected
    function test_constructor_RevertWhen_MovingAverageMultiplierZero() public {
        vm.expectRevert(ProverAuction.ZeroValue.selector);
        new ProverAuction(
            inbox,
            address(bondToken),
            LIVENESS_BOND,
            BOND_MULTIPLIER,
            MIN_FEE_REDUCTION_BPS,
            REWARD_BPS,
            BOND_WITHDRAWAL_DELAY,
            FEE_DOUBLING_PERIOD,
            MOVING_AVG_WINDOW,
            MAX_FEE_DOUBLINGS,
            INITIAL_MAX_FEE,
            0 // movingAverageMultiplier = 0 - should be rejected
        );
    }

    function test_constructor_RevertWhen_MaxFeeDoublingsTooHigh() public {
        vm.expectRevert(ProverAuction.InvalidMaxFeeDoublings.selector);
        new ProverAuction(
            inbox,
            address(bondToken),
            LIVENESS_BOND,
            BOND_MULTIPLIER,
            MIN_FEE_REDUCTION_BPS,
            REWARD_BPS,
            BOND_WITHDRAWAL_DELAY,
            FEE_DOUBLING_PERIOD,
            MOVING_AVG_WINDOW,
            65, // maxFeeDoublings too high
            INITIAL_MAX_FEE,
            MOVING_AVG_MULTIPLIER
        );
    }

    /// @notice Test that max bid fee uses moving average floor when it's higher than initial
    function test_getMaxBidFee_usesMovingAverageFloor() public {
        // First bid at the max allowed fee (initialMaxFee = 1000)
        _depositAndBid(prover1, REQUIRED_BOND, 1000);
        assertEq(auction.getMovingAverageFee(), 1000);

        // Exit prover
        vm.prank(prover1);
        auction.requestExit();

        // Max bid fee should be max of:
        // - exited fee (1000)
        // - fee floor = max(initialMaxFee=1000, movingAvg=1000 * multiplier=2) = 2000
        // So baseFee = max(1000, 2000) = 2000
        assertEq(auction.getMaxBidFee(), 2000, "should use moving average floor");
    }

    /// @notice Test that max bid fee uses initial max fee when moving average is low
    function test_getMaxBidFee_usesInitialMaxFeeWhenMovingAverageLow() public {
        // Bid with a very low fee (100 Gwei)
        _depositAndBid(prover1, REQUIRED_BOND, 100);

        // Moving average should be 100
        assertEq(auction.getMovingAverageFee(), 100);

        // Exit prover
        vm.prank(prover1);
        auction.requestExit();

        // Max bid fee should be max of:
        // - exited fee (100)
        // - fee floor = max(initialMaxFee=1000, movingAvg=100 * multiplier=2) = max(1000, 200) = 1000
        // So baseFee = max(100, 1000) = 1000
        assertEq(auction.getMaxBidFee(), 1000, "should use initialMaxFee");
    }

    /// @notice Test moving average floor prevents manipulation with zero fee exit
    function test_getMaxBidFee_movingAverageFloorPreventsManipulation() public {
        // First, bid at max allowed fee (initialMaxFee = 1000)
        _depositAndBid(prover1, REQUIRED_BOND, 1000);
        assertEq(auction.getMovingAverageFee(), 1000);

        // Exit and wait for new prover
        vm.prank(prover1);
        auction.requestExit();
        vm.warp(block.timestamp + BOND_WITHDRAWAL_DELAY + 1);

        // Bid with zero fee to lower moving average (need to bid within max allowed)
        // Max bid after exit = max(exitedFee=1000, feeFloor=max(1000, 1000*2)) = 2000
        _depositAndBid(prover2, REQUIRED_BOND, 0);
        // Moving average decays to the new fee after a long delay
        assertEq(auction.getMovingAverageFee(), 0);

        // Exit with zero fee
        vm.prank(prover2);
        auction.requestExit();

        // Despite exiting with zero fee, max bid should be based on moving average floor
        // feeFloor = max(initialMaxFee=1000, movingAvg=0 * multiplier=2) = 1000
        // baseFee = max(exitedFee=0, feeFloor=1000) = 1000
        assertEq(auction.getMaxBidFee(), 1000, "moving average floor should prevent manipulation");
    }

    function test_pause_doesNotBlockEntryPoints() public {
        auction.pause();

        _depositBond(prover1, REQUIRED_BOND);

        vm.prank(prover1);
        auction.bid(500);

        vm.prank(prover1);
        auction.requestExit();

        vm.warp(block.timestamp + BOND_WITHDRAWAL_DELAY + 1);

        vm.prank(prover1);
        auction.withdraw(1 ether);
    }

    function test_bondWithdrawalDelayZero_allowsImmediateWithdrawAfterOutbid() public {
        ProverAuction impl = new ProverAuction(
            inbox,
            address(bondToken),
            LIVENESS_BOND,
            BOND_MULTIPLIER,
            MIN_FEE_REDUCTION_BPS,
            REWARD_BPS,
            0, // bondWithdrawalDelay
            FEE_DOUBLING_PERIOD,
            MOVING_AVG_WINDOW,
            MAX_FEE_DOUBLINGS,
            INITIAL_MAX_FEE,
            MOVING_AVG_MULTIPLIER
        );

        ProverAuction zeroDelayAuction = ProverAuction(
            address(
                new ERC1967Proxy(address(impl), abi.encodeCall(ProverAuction.init, (address(this))))
            )
        );

        vm.prank(prover1);
        bondToken.approve(address(zeroDelayAuction), type(uint256).max);
        vm.prank(prover2);
        bondToken.approve(address(zeroDelayAuction), type(uint256).max);

        vm.prank(prover1);
        zeroDelayAuction.deposit(REQUIRED_BOND);
        vm.prank(prover1);
        zeroDelayAuction.bid(1000);

        vm.prank(prover2);
        zeroDelayAuction.deposit(REQUIRED_BOND);
        vm.prank(prover2);
        zeroDelayAuction.bid(950);

        IProverAuction.BondInfo memory info = zeroDelayAuction.getBondInfo(prover1);
        assertEq(info.withdrawableAt, uint48(block.timestamp));

        vm.prank(prover1);
        zeroDelayAuction.withdraw(1 ether);
    }
}
