// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { IProverAuction2 } from "src/layer1/core/iface/IProverAuction2.sol";
import { ProverAuction2 } from "src/layer1/core/impl/ProverAuction2.sol";
import { TestERC20 } from "test/mocks/TestERC20.sol";
import { CommonTest } from "test/shared/CommonTest.sol";

contract ProverAuction2Test is CommonTest {
    ProverAuction2 internal auction;
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
    uint16 internal constant MAX_ACTIVE_PROVERS = 2;

    // Events from IProverAuction
    event BidPlaced(address indexed newProver, uint32 feeInGwei, address indexed oldProver);
    event ExitRequested(address indexed prover, uint48 withdrawableAt);

    function setUp() public virtual override {
        super.setUp();

        bondToken = new TestERC20("Bond Token", "BOND");

        ProverAuction2 impl = new ProverAuction2(
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
            MOVING_AVG_MULTIPLIER,
            MAX_ACTIVE_PROVERS
        );

        auction = ProverAuction2(
            address(
                new ERC1967Proxy(address(impl), abi.encodeCall(ProverAuction2.init, (address(this))))
            )
        );

        bondToken.mint(prover1, 1000 ether);
        bondToken.mint(prover2, 1000 ether);
        bondToken.mint(prover3, 1000 ether);

        vm.prank(prover1);
        bondToken.approve(address(auction), type(uint256).max);
        vm.prank(prover2);
        bondToken.approve(address(auction), type(uint256).max);
        vm.prank(prover3);
        bondToken.approve(address(auction), type(uint256).max);
    }

    function _depositAndBid(address prover, uint128 depositAmount, uint32 fee) internal {
        vm.startPrank(prover);
        auction.deposit(depositAmount);
        auction.bid(fee);
        vm.stopPrank();
    }

    function test_bid_poolFull_replacesWorst() public {
        _depositAndBid(prover1, auction.getRequiredBond(), 100);
        _depositAndBid(prover2, auction.getRequiredBond(), 80);

        vm.startPrank(prover3);
        auction.deposit(auction.getRequiredBond());
        vm.expectEmit(true, false, false, true);
        emit BidPlaced(prover3, 70, prover1);
        auction.bid(70);
        vm.stopPrank();

        address[] memory active = auction.getActiveProvers();
        assertEq(active.length, 2);
        assertTrue(active[0] == prover2 || active[1] == prover2);
        assertTrue(active[0] == prover3 || active[1] == prover3);

        (uint32 fee1, bool active1) = auction.getProverStatus(prover1);
        assertFalse(active1);
        assertEq(fee1, 0);
        assertGt(auction.getBondInfo(prover1).withdrawableAt, 0);
    }

    function test_requestExit_removesActiveProver() public {
        _depositAndBid(prover1, auction.getRequiredBond(), 100);

        vm.prank(prover1);
        vm.expectEmit(true, false, false, true);
        emit ExitRequested(prover1, uint48(block.timestamp + BOND_WITHDRAWAL_DELAY));
        auction.requestExit();

        (address current,) = auction.getCurrentProver();
        assertEq(current, address(0));
        assertGt(auction.getBondInfo(prover1).withdrawableAt, 0);
    }

    function test_weightedSelection_isDeterministic() public {
        _depositAndBid(prover1, auction.getRequiredBond(), 100);
        _depositAndBid(prover2, auction.getRequiredBond(), 50);

        (address selected, uint32 fee) = auction.getCurrentProver();

        address[] memory active = auction.getActiveProvers();
        uint32 maxFee = 0;
        for (uint256 i = 0; i < active.length; i++) {
            (uint32 feeInGwei, bool isActive) = auction.getProverStatus(active[i]);
            assertTrue(isActive);
            if (feeInGwei > maxFee) maxFee = feeInGwei;
        }

        uint256 totalWeight = 0;
        for (uint256 i = 0; i < active.length; i++) {
            (uint32 feeInGwei,) = auction.getProverStatus(active[i]);
            totalWeight += uint256(maxFee - feeInGwei) + 1;
        }

        uint256 rand = uint256(
            keccak256(abi.encodePacked(block.prevrandao, block.number, address(auction)))
        );
        uint256 target = rand % totalWeight;

        address expected = address(0);
        uint32 expectedFee = 0;
        for (uint256 i = 0; i < active.length; i++) {
            (uint32 feeInGwei,) = auction.getProverStatus(active[i]);
            uint256 weight = uint256(maxFee - feeInGwei) + 1;
            if (target < weight) {
                expected = active[i];
                expectedFee = feeInGwei;
                break;
            }
            target -= weight;
        }

        assertEq(selected, expected);
        assertEq(fee, expectedFee);
    }

    function test_slash_ejectsBelowThreshold() public {
        _depositAndBid(prover1, auction.getRequiredBond(), 100);

        uint128 threshold = auction.getEjectionThreshold();
        uint96 liveness = auction.getLivenessBond();
        uint128 balance = auction.getBondInfo(prover1).balance;

        uint256 slashesNeeded = (uint256(balance - threshold) / liveness) + 1;

        vm.startPrank(inbox);
        for (uint256 i = 0; i < slashesNeeded; i++) {
            auction.slashProver(prover1, address(0));
        }
        vm.stopPrank();

        (, bool active) = auction.getProverStatus(prover1);
        assertFalse(active);
        assertGt(auction.getBondInfo(prover1).withdrawableAt, 0);
    }

    function test_minSelfBidInterval_isOneHour() public view {
        assertEq(auction.MIN_SELF_BID_INTERVAL(), 1 hours);
    }
}
