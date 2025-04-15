// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../../shared/CommonTest.sol";
import "../../../contracts/layer1/prover-market/ProverMarket.sol";

// To mock balances
contract MockInbox {
    mapping(address => uint256) public bondBalances;

    function setBondBalance(address _prover, uint256 _amount) external {
        bondBalances[_prover] = _amount;
    }

    function bondBalanceOf(address _prover) external view returns (uint256) {
        return bondBalances[_prover];
    }
}

contract ProverMarketTest is CommonTest {
    ProverMarket internal market;
    MockInbox internal mockInbox;

    address internal constant PROVER1 = address(0x1);
    address internal constant PROVER2 = address(0x2);

    uint256 internal constant BIDDING_THRESHOLD = 200 ether;
    uint256 internal constant OUTBID_THRESHOLD = 100 ether;
    uint256 internal constant PROVING_THRESHOLD = 50 ether;
    uint256 internal constant MIN_EXIT_DELAY = 1 days;

    function setUp() public override {
        mockInbox = new MockInbox();

        market = new ProverMarket(
            address(mockInbox),
            BIDDING_THRESHOLD,
            OUTBID_THRESHOLD,
            PROVING_THRESHOLD,
            MIN_EXIT_DELAY
        );
    }

    function testInvalidThresholdsReverts() public {
        vm.expectRevert(ProverMarket.InvalidThresholds.selector);
        new ProverMarket(address(mockInbox), 100 ether, 200 ether, 50 ether, MIN_EXIT_DELAY);
    }

    function testInitialBid() public {
        uint256 fee = 10 gwei;
        uint64 exitTimestamp = uint64(block.timestamp + MIN_EXIT_DELAY + 1);

        mockInbox.setBondBalance(PROVER1, BIDDING_THRESHOLD);

        vm.prank(PROVER1);
        market.bid(fee, exitTimestamp);

        (address currentProver, uint256 currentFee) = market.getCurrentProver();
        assertEq(currentProver, PROVER1);
        assertEq(currentFee, fee);
    }

    function testBidWithInsufficientBond() public {
        uint256 fee = 10 gwei;
        uint64 exitTimestamp = uint64(block.timestamp + MIN_EXIT_DELAY + 1);

        mockInbox.setBondBalance(PROVER1, BIDDING_THRESHOLD - 1);

        vm.prank(PROVER1);
        vm.expectRevert(ProverMarket.InsufficientBondBalance.selector);
        market.bid(fee, exitTimestamp);
    }

    function testOutbidWithLowerBond() public {
        uint256 fee1 = 10 gwei;
        uint64 exitTimestamp1 = uint64(block.timestamp + MIN_EXIT_DELAY + 1);

        mockInbox.setBondBalance(PROVER1, BIDDING_THRESHOLD);
        vm.prank(PROVER1);
        market.bid(fee1, exitTimestamp1);

        // lower bond for current prover
        mockInbox.setBondBalance(PROVER1, OUTBID_THRESHOLD - 1);

        uint256 fee2 = 9 gwei;
        uint64 exitTimestamp2 = uint64(block.timestamp + MIN_EXIT_DELAY + 2);
        mockInbox.setBondBalance(PROVER2, BIDDING_THRESHOLD);

        vm.prank(PROVER2);
        market.bid(fee2, exitTimestamp2);

        (address currentProver, uint256 currentFee) = market.getCurrentProver();
        assertEq(currentProver, PROVER2);
        assertEq(currentFee, fee2);
    }

    function testOutbidWithHigherBond() public {
        uint256 fee1 = 10 gwei;
        uint64 exitTimestamp1 = uint64(block.timestamp + MIN_EXIT_DELAY + 1);

        mockInbox.setBondBalance(PROVER1, BIDDING_THRESHOLD);
        vm.prank(PROVER1);
        market.bid(fee1, exitTimestamp1);

        // higher bond for current prover
        mockInbox.setBondBalance(PROVER1, OUTBID_THRESHOLD + 1);

        // must be <= 95% of current fee -> should revert
        uint256 fee2 = 10 gwei;
        uint64 exitTimestamp2 = uint64(block.timestamp + MIN_EXIT_DELAY + 2);
        mockInbox.setBondBalance(PROVER2, BIDDING_THRESHOLD);

        vm.prank(PROVER2);
        vm.expectRevert(ProverMarket.FeeLargerThanAllowed.selector);
        market.bid(fee2, exitTimestamp2);

        // try again with a <= 95% -> success
        fee2 = 9 gwei;
        vm.prank(PROVER2);
        market.bid(fee2, exitTimestamp2);

        (address currentProver, uint256 currentFee) = market.getCurrentProver();
        assertEq(currentProver, PROVER2);
        assertEq(currentFee, fee2);
    }

    function testOutbidWithSameBond() public {
        uint256 fee1 = 10 gwei;
        uint64 exitTimestamp1 = uint64(block.timestamp + MIN_EXIT_DELAY + 1);

        mockInbox.setBondBalance(PROVER1, BIDDING_THRESHOLD);
        vm.prank(PROVER1);
        market.bid(fee1, exitTimestamp1);

        // lower bond for current prover
        mockInbox.setBondBalance(PROVER1, OUTBID_THRESHOLD - 1);

        uint256 fee2 = 10 gwei;
        uint64 exitTimestamp2 = uint64(block.timestamp + MIN_EXIT_DELAY + 2);
        mockInbox.setBondBalance(PROVER2, BIDDING_THRESHOLD);

        vm.prank(PROVER2);
        market.bid(fee2, exitTimestamp2);

        (address currentProver, uint256 currentFee) = market.getCurrentProver();
        assertEq(currentProver, PROVER2);
        assertEq(currentFee, fee2);
    }

    function testRequestExit() public {
        uint256 fee = 10 gwei;
        uint64 exitTimestamp = uint64(block.timestamp + MIN_EXIT_DELAY + 1);

        mockInbox.setBondBalance(PROVER1, BIDDING_THRESHOLD);
        vm.prank(PROVER1);
        market.bid(fee, exitTimestamp);

        uint64 newExitTimestamp = uint64(block.timestamp + MIN_EXIT_DELAY + 2);
        vm.prank(PROVER1);
        market.requestExit(newExitTimestamp);

        // exit by non-current prover should fail
        vm.prank(PROVER2);
        vm.expectRevert(ProverMarket.NotCurrentProver.selector);
        market.requestExit(newExitTimestamp);
    }

    function testAverageFeeCalculation() public {
        uint256 fee = 10 gwei;
        uint64 exitTimestamp = uint64(block.timestamp + MIN_EXIT_DELAY + 1);

        mockInbox.setBondBalance(PROVER1, BIDDING_THRESHOLD);
        vm.prank(PROVER1);
        market.bid(fee, exitTimestamp);

        for (uint16 i = 0; i < 10; i++) {
            vm.prank(address(mockInbox));
            market.onProverAssigned(PROVER1, fee, i);
        }

        uint64 avgFee = market.avgFeeInGwei();
        assertEq(avgFee, 10);
    }

    function testGetMaxFee() public {
        uint256 fee = 10 gwei;
        uint64 exitTimestamp = uint64(block.timestamp + MIN_EXIT_DELAY + 1);

        mockInbox.setBondBalance(PROVER1, BIDDING_THRESHOLD);
        vm.prank(PROVER1);
        market.bid(fee, exitTimestamp);

        for (uint16 i = 0; i < 10; i++) {
            vm.prank(address(mockInbox));
            market.onProverAssigned(PROVER1, fee, i);
        }

        uint256 maxFee = market.getMaxFee();
        assertEq(maxFee, 20 gwei); // MAX_FEE_MULTIPLIER is 2
    }

    function testCannotFitToUint64() public {
        mockInbox.setBondBalance(PROVER1, BIDDING_THRESHOLD);

        uint256 tooLargeFee = (uint256(type(uint64).max) + 1) * 1 gwei;

        vm.prank(PROVER1);
        vm.expectRevert(ProverMarket.CannotFitToUint64.selector);
        market.bid(tooLargeFee, uint64(block.timestamp + MIN_EXIT_DELAY + 1));
    }

    function testFeeLargerThanCurrentReverts() public {
        mockInbox.setBondBalance(PROVER1, BIDDING_THRESHOLD);
        vm.prank(PROVER1);
        market.bid(10 gwei, uint64(block.timestamp + MIN_EXIT_DELAY + 1));

        mockInbox.setBondBalance(PROVER2, BIDDING_THRESHOLD);
        vm.prank(PROVER2);
        vm.expectRevert(ProverMarket.FeeLargerThanAllowed.selector);
        market.bid(11 gwei, uint64(block.timestamp + MIN_EXIT_DELAY + 2));
    }

    function testFeeLargerThanMaxReverts() public {
        mockInbox.setBondBalance(PROVER1, BIDDING_THRESHOLD);
        vm.prank(PROVER1);
        market.bid(10 gwei, uint64(block.timestamp + MIN_EXIT_DELAY + 1));

        for (uint16 i = 0; i < 10; i++) {
            vm.prank(address(mockInbox));
            market.onProverAssigned(PROVER1, 10 gwei, i);
        }

        mockInbox.setBondBalance(PROVER2, BIDDING_THRESHOLD);
        vm.prank(PROVER2);
        vm.expectRevert(ProverMarket.FeeLargerThanMax.selector);
        market.bid(25 gwei, uint64(block.timestamp + MIN_EXIT_DELAY + 2)); // 2x avg is 20 gwei
    }

    function testFeeNotDivisibleByUnitReverts() public {
        mockInbox.setBondBalance(PROVER1, BIDDING_THRESHOLD);
        vm.prank(PROVER1);
        vm.expectRevert(ProverMarket.FeeNotDivisibleByFeeUnit.selector);
        market.bid(1 wei, uint64(block.timestamp + MIN_EXIT_DELAY + 1));
    }
}
