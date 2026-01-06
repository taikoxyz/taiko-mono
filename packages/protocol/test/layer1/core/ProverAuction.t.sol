// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { ProverAuction } from "src/layer1/core/impl/ProverAuction.sol";
import { TestERC20 } from "test/mocks/TestERC20.sol";
import { CommonTest } from "test/shared/CommonTest.sol";

contract ProverAuctionTest is CommonTest {
    ProverAuction internal auction;
    TestERC20 internal bondToken;

    address internal inbox = address(0xBEEF);
    address internal prover1 = address(0x1001);
    address internal prover2 = address(0x1002);

    uint96 internal constant LIVENESS_BOND = 1 ether;
    uint128 internal constant EJECTION_THRESHOLD = 10 ether;
    uint16 internal constant MIN_FEE_REDUCTION_BPS = 500; // 5%
    uint16 internal constant REWARD_BPS = 6000; // 60%
    uint48 internal constant BOND_WITHDRAWAL_DELAY = 48 hours;
    uint48 internal constant FEE_DOUBLING_PERIOD = 15 minutes;
    uint48 internal constant MOVING_AVG_WINDOW = 30 minutes;
    uint8 internal constant MAX_FEE_DOUBLINGS = 8;
    uint32 internal constant INITIAL_MAX_FEE = 1000;
    uint8 internal constant MOVING_AVG_MULTIPLIER = 2;

    uint128 internal REQUIRED_BOND;

    function setUp() public virtual override {
        super.setUp();

        bondToken = new TestERC20("Bond Token", "BOND");
        REQUIRED_BOND = EJECTION_THRESHOLD * 2;

        ProverAuction impl = new ProverAuction(
            inbox,
            address(bondToken),
            LIVENESS_BOND,
            EJECTION_THRESHOLD,
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

        bondToken.mint(prover1, 1_000_000 ether);
        bondToken.mint(prover2, 1_000_000 ether);
    }

    function test_getProver_returnsZeroWhenNoProver() public view {
        (address prover, uint32 fee) = auction.getProver();
        assertEq(prover, address(0));
        assertEq(fee, 0);
    }

    function test_firstBid_setsProver() public {
        _depositAndBid(prover1, REQUIRED_BOND, 100);

        (address prover, uint32 fee) = auction.getProver();
        assertEq(prover, prover1);
        assertEq(fee, 100);
    }

    function test_outbid_setsWithdrawable() public {
        _depositAndBid(prover1, REQUIRED_BOND, 100);

        uint48 expected = uint48(block.timestamp) + BOND_WITHDRAWAL_DELAY;
        _depositAndBid(prover2, REQUIRED_BOND, 95);

        (address prover, uint32 fee) = auction.getProver();
        assertEq(prover, prover2);
        assertEq(fee, 95);

        ProverAuction.BondInfo memory bond1 = auction.getBondInfo(prover1);
        assertEq(bond1.withdrawableAt, expected);
    }

    function test_requestExit_vacatesProver() public {
        _depositAndBid(prover1, REQUIRED_BOND, 100);

        uint48 expected = uint48(block.timestamp) + BOND_WITHDRAWAL_DELAY;
        vm.prank(prover1);
        auction.requestExit();

        (address prover, uint32 fee) = auction.getProver();
        assertEq(prover, address(0));
        assertEq(fee, 0);

        ProverAuction.BondInfo memory bond1 = auction.getBondInfo(prover1);
        assertEq(bond1.withdrawableAt, expected);
    }

    function test_selfBid_requiresRequiredBond() public {
        _depositAndBid(prover1, REQUIRED_BOND, 100);

        vm.prank(inbox);
        auction.slashProver(prover1, address(0));

        vm.prank(prover1);
        vm.expectRevert(ProverAuction.InsufficientBond.selector);
        auction.bid(99);
    }

    function test_movingAverage_skipsRapidUpdatesOnSelfBid() public {
        _depositAndBid(prover1, REQUIRED_BOND, 100);
        assertEq(auction.getMovingAverageFee(), 100);

        uint256 interval = auction.MIN_AVG_UPDATE_INTERVAL();
        vm.warp(block.timestamp + interval - 1);
        vm.prank(prover1);
        auction.bid(90);

        assertEq(auction.getMovingAverageFee(), 100);

        vm.warp(block.timestamp + 1);
        vm.prank(prover1);
        auction.bid(80);

        uint256 window = MOVING_AVG_WINDOW;
        uint256 weightNew = interval >= window ? window : interval;
        uint256 weightOld = window - weightNew;
        uint256 expected = (uint256(100) * weightOld + uint256(80) * weightNew) / window;
        assertEq(auction.getMovingAverageFee(), expected);
    }

    function _deposit(address prover, uint128 amount) internal {
        vm.prank(prover);
        bondToken.approve(address(auction), amount);
        vm.prank(prover);
        auction.deposit(amount);
    }

    function _depositAndBid(address prover, uint128 amount, uint32 fee) internal {
        _deposit(prover, amount);
        vm.prank(prover);
        auction.bid(fee);
    }
}
