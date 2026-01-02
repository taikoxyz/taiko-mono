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
    address internal prover3 = address(0x1003);

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

    uint128 internal REQUIRED_BOND;

    function setUp() public virtual override {
        super.setUp();

        bondToken = new TestERC20("Bond Token", "BOND");

        REQUIRED_BOND = uint128(LIVENESS_BOND) * BOND_MULTIPLIER * 2;

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

        bondToken.mint(prover1, 1_000_000 ether);
        bondToken.mint(prover2, 1_000_000 ether);
        bondToken.mint(prover3, 1_000_000 ether);
    }

    function test_getProver_returnsZeroWhenNoPool() public view {
        (address prover, uint32 fee) = auction.getProver();
        assertEq(prover, address(0));
        assertEq(fee, 0);
    }

    function test_joinSameFee_addsToPool() public {
        _depositAndBid(prover1, REQUIRED_BOND, 100);
        _depositAndBid(prover2, REQUIRED_BOND, 100);

        bool sawProver1;
        bool sawProver2;
        // Use prevrandao instead of block number since getProver() uses prevrandao for selection
        for (uint256 i = 0; i < 256; i++) {
            vm.prevrandao(i);
            (address prover,) = auction.getProver();
            if (prover == prover1) sawProver1 = true;
            if (prover == prover2) sawProver2 = true;
        }

        assertTrue(sawProver1);
        assertTrue(sawProver2);
    }

    function test_weightedDistribution_matchesWeights() public {
        _depositAndBid(prover1, REQUIRED_BOND, 100);
        _depositAndBid(prover2, REQUIRED_BOND, 100);
        _depositAndBid(prover3, REQUIRED_BOND, 100);

        uint256 samples = 4096;
        uint256 count1;
        uint256 count2;
        uint256 count3;

        // getProver() uses block.prevrandao for selection; vm.roll does not change it.
        for (uint256 i = 0; i < samples; i++) {
            vm.roll(1000 + i);
            vm.prevrandao(i);
            (address prover,) = auction.getProver();
            if (prover == prover1) {
                count1++;
            } else if (prover == prover2) {
                count2++;
            } else if (prover == prover3) {
                count3++;
            } else {
                fail();
            }
        }

        assertEq(count1 + count2 + count3, samples);

        uint256 totalWeight = 10_000 + 9000 + 8000;
        uint256 expected1 = samples * 10_000 / totalWeight;
        uint256 expected2 = samples * 9000 / totalWeight;
        uint256 expected3 = samples * 8000 / totalWeight;
        uint256 tolerance1 = expected1 / 10;
        uint256 tolerance2 = expected2 / 10;
        uint256 tolerance3 = expected3 / 10;

        assertApproxEqAbs(count1, expected1, tolerance1);
        assertApproxEqAbs(count2, expected2, tolerance2);
        assertApproxEqAbs(count3, expected3, tolerance3);
    }

    function test_joinUsesSameRequiredBond() public {
        _depositAndBid(prover1, REQUIRED_BOND, 100);

        _deposit(prover2, REQUIRED_BOND - 1);
        vm.prank(prover2);
        vm.expectRevert(ProverAuction.InsufficientBond.selector);
        auction.bid(100);

        _deposit(prover2, 1);
        vm.prank(prover2);
        auction.bid(100);
    }

    function test_outbidResetsPool() public {
        _depositAndBid(prover1, REQUIRED_BOND, 100);
        _depositAndBid(prover2, REQUIRED_BOND, 100);

        _depositAndBid(prover3, REQUIRED_BOND, 95);

        vm.prevrandao(uint256(0));
        (address prover, uint32 fee) = auction.getProver();
        assertTrue(prover == prover1 || prover == prover2 || prover == prover3);
        assertEq(fee, 95);
    }

    function test_outbid_doesNotForceWithdrawable() public {
        _depositAndBid(prover1, REQUIRED_BOND, 100);
        _depositAndBid(prover2, REQUIRED_BOND, 100);

        _deposit(prover3, REQUIRED_BOND);
        vm.prank(prover3);
        auction.bid(95);

        ProverAuction.BondInfo memory bond1 = auction.getBondInfo(prover1);
        ProverAuction.BondInfo memory bond2 = auction.getBondInfo(prover2);
        assertEq(bond1.withdrawableAt, 0);
        assertEq(bond2.withdrawableAt, 0);

        bool sawProver1;
        bool sawProver2;
        bool sawProver3;
        for (uint256 i = 0; i < 256; i++) {
            vm.prevrandao(i);
            (address prover,) = auction.getProver();
            if (prover == prover1) sawProver1 = true;
            if (prover == prover2) sawProver2 = true;
            if (prover == prover3) sawProver3 = true;
        }

        assertTrue(sawProver1);
        assertTrue(sawProver2);
        assertTrue(sawProver3);
    }

    function test_requestExitRemovesFromPool() public {
        _depositAndBid(prover1, REQUIRED_BOND, 100);
        _depositAndBid(prover2, REQUIRED_BOND, 100);

        vm.prank(prover2);
        auction.requestExit();

        for (uint256 i = 0; i < 32; i++) {
            vm.roll(200 + i);
            (address prover,) = auction.getProver();
            assertEq(prover, prover1);
        }
    }

    function test_poolFullReverts() public {
        _depositAndBid(prover1, REQUIRED_BOND, 100);

        for (uint8 i = 1; i < auction.MAX_POOL_SIZE(); i++) {
            address prover = address(uint160(0x2000 + i));
            bondToken.mint(prover, 1_000_000 ether);
            _depositAndBid(prover, REQUIRED_BOND * 10, 100);
        }

        address extra = address(0x3001);
        bondToken.mint(extra, 1_000_000 ether);
        _deposit(extra, REQUIRED_BOND * 10);
        vm.prank(extra);
        vm.expectRevert(ProverAuction.PoolFull.selector);
        auction.bid(100);
    }

    function test_selfBid_requiresRequiredBond() public {
        _depositAndBid(prover1, REQUIRED_BOND, 100);

        vm.prank(inbox);
        auction.slashProver(prover1, address(0));

        vm.warp(block.timestamp + auction.MIN_SELF_BID_INTERVAL());
        vm.prank(prover1);
        vm.expectRevert(ProverAuction.InsufficientBond.selector);
        auction.bid(99);
    }

    function test_movingAverage_globalCooldown_skipsRapidUpdates() public {
        _depositAndBid(prover1, REQUIRED_BOND, 100);
        assertEq(auction.getMovingAverageFee(), 100);

        _deposit(prover2, REQUIRED_BOND);
        vm.warp(block.timestamp + auction.MIN_AVG_UPDATE_INTERVAL() - 1);
        vm.prank(prover2);
        auction.bid(95);

        assertEq(auction.getMovingAverageFee(), 100);

        _deposit(prover3, REQUIRED_BOND);
        vm.warp(block.timestamp + 1);
        vm.prank(prover3);
        auction.bid(90);

        uint256 window = MOVING_AVG_WINDOW;
        uint256 elapsed = auction.MIN_AVG_UPDATE_INTERVAL();
        uint256 weightNew = elapsed >= window ? window : elapsed;
        uint256 weightOld = window - weightNew;
        uint256 expected = (uint256(100) * weightOld + uint256(90) * weightNew) / window;
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
