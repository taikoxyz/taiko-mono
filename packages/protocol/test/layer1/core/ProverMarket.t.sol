// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Test } from "forge-std/src/Test.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { ProverMarket } from "src/layer1/core/impl/ProverMarket.sol";
import { TestERC20 } from "test/mocks/TestERC20.sol";

// ---------------------------------------------------------------
// Mock contracts
// ---------------------------------------------------------------

contract MockInbox {
    IInbox.CoreState private _state;
    IInbox.Config private _config;

    function setCoreState(IInbox.CoreState memory _s) external {
        _state = _s;
    }

    function setConfig(IInbox.Config memory _c) external {
        _config = _c;
    }

    function getCoreState() external view returns (IInbox.CoreState memory) {
        return _state;
    }

    function getConfig() external view returns (IInbox.Config memory) {
        return _config;
    }
}

// ---------------------------------------------------------------
// ProverMarketTest
// ---------------------------------------------------------------

contract ProverMarketTest is Test {
    ProverMarket internal market;
    MockInbox internal mockInbox;
    TestERC20 internal bondToken;

    address internal owner = address(this);
    address internal alice = vm.addr(0x1); // prover1
    address internal bob = vm.addr(0x2); // prover2
    address internal carol = vm.addr(0x3); // proposer
    address internal david = vm.addr(0x4); // ejector

    // Constructor parameters (small values for tests)
    uint64 internal constant BASE_BOND = 100; // gwei
    uint16 internal constant MIN_FEE_REDUCTION_BPS = 500; // 5%
    uint48 internal constant GLOBAL_COOLDOWN = 3600; // 1 hour
    uint48 internal constant ACTIVATION_DELAY = 14_400; // 4 hours
    uint16 internal constant SLASH_BOUNTY_BPS = 5000; // 50%
    uint8 internal constant MAX_ESCALATION = 3;
    uint48 internal constant ESCALATION_DECAY_PERIOD = 86_400; // 24 hours

    // Inbox config constants
    uint48 internal constant PROVING_WINDOW = 7200; // 2 hours

    // ---------------------------------------------------------------
    // Events (re-declared for vm.expectEmit)
    // ---------------------------------------------------------------

    event BidPlaced(address indexed newWinner, address indexed previousWinner, uint64 feeInGwei);
    event WinnerSlashedAndEjected(
        address indexed ejectedProver, uint64 bondSlashed, address indexed ejector
    );
    event WinnerExited(address indexed prover);
    event BondDeposited(address indexed prover, uint64 amount);
    event BondWithdrawn(address indexed prover, uint64 amount);
    event FeeDeposited(address indexed depositor, uint256 amount);
    event FeeWithdrawn(address indexed withdrawer, uint256 amount);
    event FeesClaimed(address indexed prover, uint48 upToProposalId, uint256 amount);
    event WinnerOverridden(address indexed newWinner, uint64 feeInGwei);

    // ---------------------------------------------------------------
    // setUp
    // ---------------------------------------------------------------

    function setUp() public virtual {
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.deal(carol, 100 ether);
        vm.deal(david, 100 ether);

        // Deploy mock inbox
        mockInbox = new MockInbox();
        _setDefaultInboxState();

        // Deploy bond token
        bondToken = new TestERC20("Bond Token", "BOND");

        // Deploy ProverMarket via proxy
        ProverMarket impl = new ProverMarket(
            address(mockInbox),
            address(bondToken),
            BASE_BOND,
            MIN_FEE_REDUCTION_BPS,
            GLOBAL_COOLDOWN,
            ACTIVATION_DELAY,
            SLASH_BOUNTY_BPS,
            MAX_ESCALATION,
            ESCALATION_DECAY_PERIOD
        );
        market = ProverMarket(
            payable(address(
                    new ERC1967Proxy(
                        address(impl), abi.encodeCall(ProverMarket.init, (address(this)))
                    )
                ))
        );

        // Mint bond tokens and approve for provers
        _mintAndApprove(alice, 1000 ether);
        _mintAndApprove(bob, 1000 ether);
    }

    // ---------------------------------------------------------------
    // bid tests
    // ---------------------------------------------------------------

    function test_bid_firstBidSucceeds() public {
        _depositBondAs(alice, BASE_BOND);

        vm.expectEmit();
        emit BidPlaced(alice, address(0), 1000);

        vm.prank(alice);
        market.bid(1000);

        (address winnerAddr, uint64 feeInGwei, uint48 activeAt) = market.winner();
        assertEq(winnerAddr, alice, "winner address");
        assertEq(feeInGwei, 1000, "winner fee");
        assertEq(activeAt, uint48(block.timestamp) + ACTIVATION_DELAY, "activation time");
    }

    function test_bid_RevertWhen_ZeroFee() public {
        _depositBondAs(alice, BASE_BOND);

        vm.prank(alice);
        vm.expectRevert(ProverMarket.ZeroFee.selector);
        market.bid(0);
    }

    function test_bid_RevertWhen_InsufficientBond() public {
        // Alice does not deposit any bond
        vm.prank(alice);
        vm.expectRevert(ProverMarket.InsufficientBond.selector);
        market.bid(1000);
    }

    function test_bid_RevertWhen_AlreadyWinner() public {
        _depositBondAs(alice, BASE_BOND);

        vm.prank(alice);
        market.bid(1000);

        // Alice tries to bid again
        vm.prank(alice);
        vm.expectRevert(ProverMarket.AlreadyWinner.selector);
        market.bid(900);
    }

    function test_bid_RevertWhen_MarketOnCooldown() public {
        // Set up a winner, then eject them to trigger cooldown
        _setupActiveWinner(alice, 1000);
        _triggerEjection(david);

        // After ejection, consecutiveEjections=1 so requiredBond=200. Deposit enough.
        _depositBondAs(bob, BASE_BOND * 2);
        vm.prank(bob);
        vm.expectRevert(ProverMarket.MarketOnCooldown.selector);
        market.bid(500);
    }

    function test_bid_outbidSucceeds() public {
        _depositBondAs(alice, BASE_BOND);
        _depositBondAs(bob, BASE_BOND);

        // Alice bids first
        vm.prank(alice);
        market.bid(1000);

        // Bob outbids with >= 5% lower fee (1000 * 95% = 950, so 950 or less)
        vm.expectEmit();
        emit BidPlaced(bob, alice, 950);

        vm.prank(bob);
        market.bid(950);

        (address winnerAddr, uint64 feeInGwei,) = market.winner();
        assertEq(winnerAddr, bob, "new winner");
        assertEq(feeInGwei, 950, "new fee");
    }

    function test_bid_RevertWhen_InsufficientFeeReduction() public {
        _depositBondAs(alice, BASE_BOND);
        _depositBondAs(bob, BASE_BOND);

        // Alice bids 1000
        vm.prank(alice);
        market.bid(1000);

        // Warp past activation delay so the fee reduction check kicks in
        vm.warp(block.timestamp + ACTIVATION_DELAY + 1);

        // Bob tries to outbid with only 4% reduction (960 > 950 threshold)
        vm.prank(bob);
        vm.expectRevert(ProverMarket.InsufficientFeeReduction.selector);
        market.bid(960);
    }

    function test_bid_vacantMarketAcceptsAnyFee() public {
        _depositBondAs(alice, BASE_BOND);

        // On a vacant market, any non-zero fee should work - even a very high one
        vm.prank(alice);
        market.bid(999_999);

        (address winnerAddr, uint64 feeInGwei,) = market.winner();
        assertEq(winnerAddr, alice, "winner");
        assertEq(feeInGwei, 999_999, "fee accepted");
    }

    // ---------------------------------------------------------------
    // isProverWhitelisted tests
    // ---------------------------------------------------------------

    function test_isProverWhitelisted_vacantReturnsZero() public view {
        (bool isWhitelisted, uint256 count) = market.isProverWhitelisted(alice);
        assertFalse(isWhitelisted, "no one whitelisted on vacant market");
        assertEq(count, 0, "prover count is zero");
    }

    function test_isProverWhitelisted_duringGracePeriodReturnsZero() public {
        _depositBondAs(alice, BASE_BOND);

        vm.prank(alice);
        market.bid(1000);

        // Still within activation delay
        vm.warp(block.timestamp + ACTIVATION_DELAY - 1);

        (bool isWhitelisted, uint256 count) = market.isProverWhitelisted(alice);
        assertFalse(isWhitelisted, "not active during grace period");
        assertEq(count, 0, "count zero during grace period");
    }

    function test_isProverWhitelisted_afterActivationReturnsOneForWinner() public {
        _depositBondAs(alice, BASE_BOND);

        vm.prank(alice);
        market.bid(1000);

        // Warp past activation delay
        vm.warp(block.timestamp + ACTIVATION_DELAY);

        (bool isWhitelisted, uint256 count) = market.isProverWhitelisted(alice);
        assertTrue(isWhitelisted, "winner is whitelisted after activation");
        assertEq(count, 1, "prover count is one");
    }

    function test_isProverWhitelisted_afterActivationReturnsZeroForNonWinner() public {
        _depositBondAs(alice, BASE_BOND);

        vm.prank(alice);
        market.bid(1000);

        // Warp past activation delay
        vm.warp(block.timestamp + ACTIVATION_DELAY);

        (bool isWhitelisted, uint256 count) = market.isProverWhitelisted(bob);
        assertFalse(isWhitelisted, "non-winner not whitelisted");
        assertEq(count, 1, "prover count is one");
    }

    function test_isProverWhitelisted_winnerIsWhitelisted() public {
        _setupActiveWinner(alice, 1000);

        (bool isWhitelisted, uint256 count) = market.isProverWhitelisted(alice);
        assertTrue(isWhitelisted, "active winner is whitelisted");
        assertEq(count, 1, "exactly one whitelisted prover");
    }

    // ---------------------------------------------------------------
    // slashAndEject tests
    // ---------------------------------------------------------------

    function test_slashAndEject_succeeds() public {
        _setupActiveWinner(alice, 1000);

        // Set inbox state: pending proposals and proving window expired
        _setInboxStateForEjection();

        uint64 aliceBondBefore = market.bonds(alice);

        vm.expectEmit();
        emit WinnerSlashedAndEjected(alice, aliceBondBefore, david);

        vm.prank(david);
        market.slashAndEject();

        (address winnerAddr,,) = market.winner();
        assertEq(winnerAddr, address(0), "winner cleared after ejection");
    }

    function test_slashAndEject_RevertWhen_NoActiveWinner() public {
        // No winner set
        vm.prank(david);
        vm.expectRevert(ProverMarket.NoActiveWinner.selector);
        market.slashAndEject();
    }

    function test_slashAndEject_RevertWhen_DuringGracePeriod() public {
        _depositBondAs(alice, BASE_BOND);

        vm.prank(alice);
        market.bid(1000);

        // Winner exists but not yet active (still in grace period)
        vm.warp(block.timestamp + ACTIVATION_DELAY - 1);

        _setInboxStateForEjection();

        vm.prank(david);
        vm.expectRevert(ProverMarket.WinnerNotYetActive.selector);
        market.slashAndEject();
    }

    function test_slashAndEject_RevertWhen_NoPendingProposals() public {
        _setupActiveWinner(alice, 1000);

        // Inbox state: nextProposalId == lastFinalizedProposalId + 1 (no pending)
        IInbox.CoreState memory state;
        state.nextProposalId = 2;
        state.lastFinalizedProposalId = 1;
        state.lastFinalizedTimestamp = uint48(block.timestamp);
        mockInbox.setCoreState(state);

        vm.prank(david);
        vm.expectRevert(ProverMarket.NoPendingProposals.selector);
        market.slashAndEject();
    }

    function test_slashAndEject_RevertWhen_ProvingWindowNotExpired() public {
        _setupActiveWinner(alice, 1000);

        // Inbox state: pending proposals but proving window not expired
        IInbox.CoreState memory state;
        state.nextProposalId = 5;
        state.lastFinalizedProposalId = 1;
        // Last finalized very recently, so proving window hasn't expired
        state.lastFinalizedTimestamp = uint48(block.timestamp);
        mockInbox.setCoreState(state);

        vm.prank(david);
        vm.expectRevert(ProverMarket.ProvingWindowNotExpired.selector);
        market.slashAndEject();
    }

    function test_slashAndEject_bondDistribution() public {
        _setupActiveWinner(alice, 1000);
        _setInboxStateForEjection();

        uint64 aliceBond = market.bonds(alice);
        uint256 ejectorBalanceBefore = bondToken.balanceOf(david);

        // 50% to ejector, 50% burned (sent to address(0) or stays in contract)
        uint64 bounty = uint64(uint256(aliceBond) * SLASH_BOUNTY_BPS / 10_000);

        vm.prank(david);
        market.slashAndEject();

        // Alice's bond should be zeroed out
        assertEq(market.bonds(alice), 0, "alice bond zeroed");

        // Ejector should receive the bounty portion in bond tokens
        uint256 ejectorBalanceAfter = bondToken.balanceOf(david);
        assertEq(
            ejectorBalanceAfter - ejectorBalanceBefore,
            uint256(bounty) * 1 gwei,
            "ejector received bounty"
        );
    }

    // ---------------------------------------------------------------
    // exit tests
    // ---------------------------------------------------------------

    function test_exit_succeeds() public {
        _setupActiveWinner(alice, 1000);

        vm.expectEmit();
        emit WinnerExited(alice);

        vm.prank(alice);
        market.exit();

        (address winnerAddr,,) = market.winner();
        assertEq(winnerAddr, address(0), "winner cleared after exit");
    }

    function test_exit_RevertWhen_NotWinner() public {
        _setupActiveWinner(alice, 1000);

        vm.prank(bob);
        vm.expectRevert(ProverMarket.NotWinner.selector);
        market.exit();
    }

    // ---------------------------------------------------------------
    // depositBond tests
    // ---------------------------------------------------------------

    function test_depositBond_succeeds() public {
        uint64 amount = 200;
        uint256 tokensBefore = bondToken.balanceOf(alice);

        vm.expectEmit();
        emit BondDeposited(alice, amount);

        vm.prank(alice);
        market.depositBond(amount);

        assertEq(market.bonds(alice), amount, "bond balance updated");
        assertEq(
            bondToken.balanceOf(alice),
            tokensBefore - uint256(amount) * 1 gwei,
            "tokens transferred"
        );
    }

    // ---------------------------------------------------------------
    // withdrawBond tests
    // ---------------------------------------------------------------

    function test_withdrawBond_succeeds() public {
        _depositBondAs(alice, 200);

        uint256 tokensBefore = bondToken.balanceOf(alice);

        vm.expectEmit();
        emit BondWithdrawn(alice, 100);

        vm.prank(alice);
        market.withdrawBond(100);

        assertEq(market.bonds(alice), 100, "bond balance reduced");
        assertEq(
            bondToken.balanceOf(alice), tokensBefore + uint256(100) * 1 gwei, "tokens returned"
        );
    }

    function test_withdrawBond_RevertWhen_isWinner() public {
        _setupActiveWinner(alice, 1000);

        vm.prank(alice);
        vm.expectRevert(ProverMarket.WinnerCannotWithdraw.selector);
        market.withdrawBond(50);
    }

    // ---------------------------------------------------------------
    // depositFee tests
    // ---------------------------------------------------------------

    function test_depositFee_succeeds() public {
        uint256 feeAmount = 1 ether;

        vm.expectEmit();
        emit FeeDeposited(carol, feeAmount);

        vm.prank(carol);
        market.depositFee{ value: feeAmount }();

        assertEq(market.feeBalances(carol), feeAmount, "fee balance recorded");
    }

    // ---------------------------------------------------------------
    // claimFees tests
    // ---------------------------------------------------------------

    function test_claimFees_succeeds() public {
        _setupActiveWinner(alice, 1000);

        // Simulate fee deposits by sending ETH to market
        vm.prank(carol);
        market.depositFee{ value: 5 ether }();

        // Set inbox state so there are proposals to claim fees for
        IInbox.CoreState memory state;
        state.nextProposalId = 10;
        state.lastFinalizedProposalId = 9;
        state.lastFinalizedTimestamp = uint48(block.timestamp);
        mockInbox.setCoreState(state);

        uint256 aliceEthBefore = alice.balance;

        vm.prank(alice);
        market.claimFees();

        // Alice should have received some fees
        uint256 aliceEthAfter = alice.balance;
        assertTrue(aliceEthAfter > aliceEthBefore, "alice received fees");
    }

    function test_claimFees_partialPayment() public {
        _setupActiveWinner(alice, 1000);

        // Deposit a small fee
        vm.prank(carol);
        market.depositFee{ value: 0.5 ether }();

        // Set inbox state with proposals finalized
        IInbox.CoreState memory state;
        state.nextProposalId = 5;
        state.lastFinalizedProposalId = 4;
        state.lastFinalizedTimestamp = uint48(block.timestamp);
        mockInbox.setCoreState(state);

        uint256 aliceEthBefore = alice.balance;

        vm.prank(alice);
        market.claimFees();

        uint256 claimed = alice.balance - aliceEthBefore;
        // With partial deposits, the payout should be capped by available balance
        assertTrue(claimed <= 0.5 ether, "claim capped by available balance");
    }

    // ---------------------------------------------------------------
    // setWinnerOverride tests
    // ---------------------------------------------------------------

    function test_setWinnerOverride_succeeds() public {
        _depositBondAs(bob, BASE_BOND);

        vm.expectEmit();
        emit WinnerOverridden(bob, 500);

        market.setWinnerOverride(bob, 500);

        (address winnerAddr, uint64 feeInGwei,) = market.winner();
        assertEq(winnerAddr, bob, "override winner set");
        assertEq(feeInGwei, 500, "override fee set");
    }

    function test_setWinnerOverride_RevertWhen_NotOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        market.setWinnerOverride(bob, 500);
    }

    // ---------------------------------------------------------------
    // getRequiredBond (anti-griefing) tests
    // ---------------------------------------------------------------

    function test_getRequiredBond_escalatesAfterEjection() public {
        uint64 baseBond = market.getRequiredBond();
        assertEq(baseBond, BASE_BOND, "starts at base bond");

        // Perform an ejection to trigger escalation
        _setupActiveWinner(alice, 1000);
        _setInboxStateForEjection();
        vm.prank(david);
        market.slashAndEject();

        uint64 escalatedBond = market.getRequiredBond();
        assertTrue(escalatedBond > BASE_BOND, "bond escalated after ejection");
    }

    function test_getRequiredBond_decaysOverTime() public {
        // Trigger an ejection to escalate the bond
        _setupActiveWinner(alice, 1000);
        _setInboxStateForEjection();
        vm.prank(david);
        market.slashAndEject();

        uint64 escalatedBond = market.getRequiredBond();
        assertTrue(escalatedBond > BASE_BOND, "bond is escalated");

        // Warp past the escalation decay period
        vm.warp(block.timestamp + GLOBAL_COOLDOWN + ESCALATION_DECAY_PERIOD + 1);

        uint64 decayedBond = market.getRequiredBond();
        assertTrue(decayedBond < escalatedBond, "bond decayed over time");
    }

    // ---------------------------------------------------------------
    // Helpers (private - state-changing)
    // ---------------------------------------------------------------

    function _mintAndApprove(address _account, uint256 _amount) private {
        bondToken.mint(_account, _amount);
        vm.prank(_account);
        bondToken.approve(address(market), type(uint256).max);
    }

    function _depositBondAs(address _account, uint64 _amount) private {
        vm.prank(_account);
        market.depositBond(_amount);
    }

    /// @dev Sets up a winner that is past the activation delay and ready to prove.
    function _setupActiveWinner(address _prover, uint64 _feeInGwei) private {
        _depositBondAs(_prover, market.getRequiredBond());
        vm.prank(_prover);
        market.bid(_feeInGwei);
        // Warp past activation delay
        vm.warp(block.timestamp + ACTIVATION_DELAY);
    }

    /// @dev Triggers an ejection by david, assumes winner is active and inbox state is set.
    function _triggerEjection(address _ejector) private {
        _setInboxStateForEjection();
        vm.prank(_ejector);
        market.slashAndEject();
    }

    /// @dev Sets the default inbox config with a 2-hour proving window.
    function _setDefaultInboxState() private {
        IInbox.Config memory cfg;
        cfg.provingWindow = PROVING_WINDOW;
        mockInbox.setConfig(cfg);

        IInbox.CoreState memory state;
        state.nextProposalId = 1;
        state.lastFinalizedProposalId = 0;
        state.lastFinalizedTimestamp = uint48(block.timestamp);
        mockInbox.setCoreState(state);
    }

    /// @dev Sets inbox state so that ejection conditions are met:
    ///      pending proposals exist and the proving window has expired.
    function _setInboxStateForEjection() private {
        IInbox.CoreState memory state;
        state.nextProposalId = 5;
        state.lastFinalizedProposalId = 1;
        // Set last finalized timestamp far enough in the past that proving window has expired
        state.lastFinalizedTimestamp = uint48(block.timestamp) - PROVING_WINDOW - 1;
        mockInbox.setCoreState(state);
    }
}
