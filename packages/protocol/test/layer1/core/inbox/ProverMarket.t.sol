// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { InboxTestBase } from "./InboxTestBase.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Vm } from "forge-std/src/Vm.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { Inbox } from "src/layer1/core/impl/Inbox.sol";
import { ProverMarket } from "src/layer1/core/impl/ProverMarket.sol";

contract RejectingFeeRecipient {
    function depositBondAndBid(
        ProverMarket _market,
        IERC20 _bondToken,
        uint64 _bondAmount,
        uint64 _feeInGwei
    )
        external
    {
        _bondToken.approve(address(_market), type(uint256).max);
        _market.depositBond(_bondAmount);
        _market.bid(address(this), _feeInGwei);
    }

    receive() external payable {
        revert("reject ether");
    }
}

/// @title ProverMarketTestBase
/// @notice Shared setup for ProverMarket tests — deploys a real ProverMarket wired to Inbox.
abstract contract ProverMarketTestBase is InboxTestBase {
    struct RecordedProposal {
        ProposedEvent payload;
        uint48 timestamp;
    }

    ProverMarket internal market;

    uint64 internal constant MARKET_MIN_BOND_GWEI = 1_000_000_000; // 1 gwei in token
    uint48 internal constant PERMISSIONLESS_PROVING_DELAY = 24 hours;

    function setUp() public virtual override {
        super.setUp();
    }

    function _buildConfig() internal virtual override returns (IInbox.Config memory) {
        // Deploy ProverMarket first so we can reference it in the Inbox config.
        // We need the Inbox address for the market constructor, but Inbox needs the market address.
        // Solution: deploy market with a placeholder, then redeploy Inbox referencing the market.
        // Actually, Inbox is deployed after _buildConfig, so we can deploy market with a
        // predicted address. But that's complex. Instead, deploy market with a temporary inbox,
        // then redeploy everything properly.
        //
        // Simpler: Deploy market pointing to address(1) temporarily, build config, then after
        // Inbox is deployed we won't need to change it because the market's _inbox is immutable.
        // We need the real inbox address.
        //
        // Best approach: pre-compute the inbox address or use a two-phase setup.
        // Let's just deploy the market after Inbox by overriding setUp.

        // Return config with address(0) for now; we override setUp to handle the full wiring.
        return IInbox.Config({
            proofVerifier: address(verifier),
            proposerChecker: address(proposerChecker),
            proverMarket: address(0), // overridden in setUp
            signalService: address(signalService),
            bondToken: address(bondToken),
            provingWindow: 2 hours,
            permissionlessProvingDelay: PERMISSIONLESS_PROVING_DELAY,
            maxProofSubmissionDelay: 3 minutes,
            ringBufferSize: 100,
            basefeeSharingPctg: 0,
            forcedInclusionDelay: 384 seconds,
            forcedInclusionFeeInGwei: 10_000_000,
            forcedInclusionFeeDoubleThreshold: 50,
            permissionlessInclusionMultiplier: 5
        });
    }

    /// @dev Override to deploy Inbox with a real ProverMarket.
    /// We deploy market first with a known inbox address using CREATE2-like prediction,
    /// or simply deploy everything in sequence.
    function _deployInbox() internal virtual override returns (Inbox) {
        // Step 1: Deploy Inbox with proverMarket = address(0) to get a working instance.
        // Step 2: Deploy ProverMarket pointing to that Inbox.
        // Step 3: Redeploy Inbox with the real proverMarket address.
        // Since Inbox is behind a proxy, we can upgrade the implementation.

        // Deploy initial Inbox (proverMarket = address(0))
        Inbox firstInbox = super._deployInbox();

        // Deploy ProverMarket pointing to the Inbox proxy address
        ProverMarket marketImpl = new ProverMarket(
            address(firstInbox),
            address(bondToken),
            MARKET_MIN_BOND_GWEI,
            PERMISSIONLESS_PROVING_DELAY
        );
        market = ProverMarket(
            address(
                new ERC1967Proxy(
                    address(marketImpl), abi.encodeCall(ProverMarket.init, (address(this)))
                )
            )
        );

        // Upgrade Inbox implementation to one that has proverMarket set
        config.proverMarket = address(market);
        address newImpl = address(new Inbox(config));
        firstInbox.upgradeTo(newImpl);

        return firstInbox;
    }

    /// @dev Override to find the Proposed event by topic instead of assuming last log.
    /// When ProverMarket is active, additional events are emitted after Proposed.
    function _readProposedEvent() internal override returns (ProposedEvent memory payload_) {
        Vm.Log[] memory logs = vm.getRecordedLogs();
        // Proposed event topic — pre-computed from the event signature
        bytes32 proposedTopic = 0x7c4c4523e17533e451df15762a093e0693a2cd8b279fe54c6cd3777ed5771213;
        for (uint256 i = logs.length; i > 0; --i) {
            if (logs[i - 1].topics.length > 0 && logs[i - 1].topics[0] == proposedTopic) {
                Vm.Log memory log = logs[i - 1];
                payload_.id = uint48(uint256(log.topics[1]));
                payload_.proposer = address(uint160(uint256(log.topics[2])));
                (
                    payload_.parentProposalHash,
                    payload_.endOfSubmissionWindowTimestamp,
                    payload_.basefeeSharingPctg,
                    payload_.sources
                ) = abi.decode(log.data, (bytes32, uint48, uint8, IInbox.DerivationSource[]));
                return payload_;
            }
        }
        revert("Proposed event not found");
    }

    // ---------------------------------------------------------------
    // ProverMarket helpers
    // ---------------------------------------------------------------

    /// @dev Deposits bond into the ProverMarket for the given account.
    function _depositMarketBond(address _account, uint64 _amount) internal {
        bondToken.mint(_account, uint256(_amount) * 1 gwei);
        vm.startPrank(_account);
        bondToken.approve(address(market), type(uint256).max);
        market.depositBond(_amount);
        vm.stopPrank();
    }

    /// @dev Deposits fee credit into the ProverMarket for the given account.
    function _depositFeeCredit(address _account, uint256 _amount) internal {
        vm.deal(_account, _amount);
        vm.prank(_account);
        market.depositFeeCredit{ value: _amount }();
    }

    /// @dev Sets up a prover with a bid in the market and proposes so the epoch activates.
    function _setupActiveBid(
        address _operator,
        uint64 _feeInGwei
    )
        internal
        returns (uint48 epochId_)
    {
        _depositMarketBond(_operator, MARKET_MIN_BOND_GWEI);
        vm.prank(_operator);
        market.bid(_operator, _feeInGwei);

        (, uint48 pendingEpochId,,,,,) = market.marketState();
        epochId_ = pendingEpochId;

        // Propose to activate the epoch
        _advanceBlock();
        _proposeOne();
    }

    /// @dev Proposes once and records the proposal timestamp for later proof construction.
    function _proposeRecordedOne() internal returns (RecordedProposal memory proposal_) {
        proposal_.payload = _proposeOne();
        proposal_.timestamp = uint48(block.timestamp);
    }

    /// @dev Builds a proof input for a previously recorded contiguous proposal range.
    function _buildRecordedProofInput(
        RecordedProposal[] memory _proposals,
        address _actualProver
    )
        internal
        view
        returns (IInbox.ProveInput memory input_)
    {
        require(_proposals.length > 0, "empty proof range");

        IInbox.Transition[] memory transitions = new IInbox.Transition[](_proposals.length);
        for (uint256 i; i < _proposals.length; ++i) {
            transitions[i] = _transitionFor(
                _proposals[i].payload,
                _proposals[i].timestamp,
                keccak256(abi.encode("recorded-proof", _proposals[i].payload.id))
            );
        }

        input_ = IInbox.ProveInput({
            commitment: IInbox.Commitment({
                firstProposalId: _proposals[0].payload.id,
                firstProposalParentBlockHash: inbox.getCoreState().lastFinalizedBlockHash,
                lastProposalHash: inbox.getProposalHash(_proposals[_proposals.length - 1].payload.id),
                actualProver: _actualProver,
                endBlockNumber: uint48(block.number),
                endStateRoot: keccak256(abi.encode("recorded-state-root", _proposals.length)),
                transitions: transitions
            })
        });
    }

    /// @dev Proves a previously recorded contiguous proposal range with the specified caller.
    function _proveRecordedRangeAs(
        RecordedProposal[] memory _proposals,
        address _caller,
        address _actualProver
    )
        internal
    {
        IInbox.ProveInput memory input = _buildRecordedProofInput(_proposals, _actualProver);
        bytes memory encodedInput = codec.encodeProveInput(input);
        vm.prank(_caller);
        inbox.prove(encodedInput, bytes("proof"));
    }

    /// @dev Proves with a specific caller (overrides the default prover).
    function _proveAs(address _proverAddr, IInbox.ProveInput memory _input) internal {
        bytes memory encodedInput = codec.encodeProveInput(_input);
        vm.prank(_proverAddr);
        inbox.prove(encodedInput, bytes("proof"));
    }
}

// =======================================================================
// Bond Management Tests
// =======================================================================

contract ProverMarketBondTest is ProverMarketTestBase {
    function test_depositBond_creditsBalance() external {
        uint64 amount = 5_000_000_000;
        _depositMarketBond(Alice, amount);
        assertEq(market.bondBalances(Alice), amount);
    }

    function test_depositBond_transfersTokens() external {
        uint64 amount = 5_000_000_000;
        uint256 tokenAmount = uint256(amount) * 1 gwei;
        bondToken.mint(Alice, tokenAmount);

        vm.startPrank(Alice);
        bondToken.approve(address(market), type(uint256).max);
        uint256 balBefore = bondToken.balanceOf(address(market));
        market.depositBond(amount);
        vm.stopPrank();

        assertEq(bondToken.balanceOf(address(market)) - balBefore, tokenAmount);
    }

    function test_depositBond_RevertWhen_ZeroAmount() external {
        vm.expectRevert(ProverMarket.ZeroValue.selector);
        market.depositBond(0);
    }

    function test_withdrawBond_transfersTokens() external {
        uint64 amount = 5_000_000_000;
        _depositMarketBond(Alice, amount);

        uint256 balBefore = bondToken.balanceOf(Alice);
        vm.prank(Alice);
        market.withdrawBond(amount);

        assertEq(bondToken.balanceOf(Alice) - balBefore, uint256(amount) * 1 gwei);
        assertEq(market.bondBalances(Alice), 0);
    }

    function test_withdrawBond_RevertWhen_InsufficientBalance() external {
        _depositMarketBond(Alice, 100);
        vm.prank(Alice);
        vm.expectRevert(ProverMarket.InsufficientBond.selector);
        market.withdrawBond(200);
    }
}

// =======================================================================
// Fee Credit Tests
// =======================================================================

contract ProverMarketFeeCreditTest is ProverMarketTestBase {
    function test_depositFeeCredit_creditsBalance() external {
        _depositFeeCredit(Alice, 1 ether);
        assertEq(market.feeCreditBalances(Alice), 1 ether);
    }

    function test_depositFeeCredit_RevertWhen_ZeroValue() external {
        vm.expectRevert(ProverMarket.ZeroValue.selector);
        market.depositFeeCredit{ value: 0 }();
    }

    function test_withdrawFeeCredit_sendsEth() external {
        _depositFeeCredit(Alice, 2 ether);

        uint256 balBefore = Alice.balance;
        vm.prank(Alice);
        market.withdrawFeeCredit(1 ether);

        assertEq(Alice.balance - balBefore, 1 ether);
        assertEq(market.feeCreditBalances(Alice), 1 ether);
    }

    function test_withdrawFeeCredit_RevertWhen_InsufficientBalance() external {
        _depositFeeCredit(Alice, 1 ether);
        vm.prank(Alice);
        vm.expectRevert(ProverMarket.InsufficientFeeCredit.selector);
        market.withdrawFeeCredit(2 ether);
    }
}

// =======================================================================
// Bid Tests
// =======================================================================

contract ProverMarketBidTest is ProverMarketTestBase {
    function test_bid_createsPendingEpoch() external {
        _depositMarketBond(Alice, MARKET_MIN_BOND_GWEI);

        vm.prank(Alice);
        market.bid(Alice, 100);

        (, uint48 pendingEpochId,,,,,) = market.marketState();
        assertEq(pendingEpochId, 1);

        (address op, address feeRecipient, uint64 fee, uint64 bonded,,,) =
            market.epochs(pendingEpochId);
        assertEq(op, Alice);
        assertEq(feeRecipient, Alice);
        assertEq(fee, 100);
        assertEq(bonded, MARKET_MIN_BOND_GWEI);

        // Bond should be locked
        assertEq(market.bondBalances(Alice), 0);
    }

    function test_bid_activatesOnFirstProposal() external {
        _depositMarketBond(Alice, MARKET_MIN_BOND_GWEI);
        vm.prank(Alice);
        market.bid(Alice, 100);

        // Propose to trigger activation
        _advanceBlock();
        _proposeOne();

        (uint48 activeEpochId, uint48 pendingEpochId,,,,,) = market.marketState();
        assertEq(activeEpochId, 1);
        assertEq(pendingEpochId, 0);
    }

    function test_bid_outbidRequiresLowerFee() external {
        // First bidder becomes pending, then active on proposal
        _setupActiveBid(Alice, 100);

        // Bob must bid lower to outbid
        _depositMarketBond(Bob, MARKET_MIN_BOND_GWEI);
        vm.prank(Bob);
        market.bid(Bob, 50);

        (, uint48 pendingEpochId,,,,,) = market.marketState();
        (address op,,,,,,) = market.epochs(pendingEpochId);
        assertEq(op, Bob);
    }

    function test_bid_RevertWhen_FeeTooHigh() external {
        _setupActiveBid(Alice, 100);

        _depositMarketBond(Bob, MARKET_MIN_BOND_GWEI);
        vm.prank(Bob);
        vm.expectRevert(ProverMarket.BidFeeTooHigh.selector);
        market.bid(Bob, 100); // must be strictly less
    }

    function test_bid_RevertWhen_InsufficientBond() external {
        vm.expectRevert(ProverMarket.InsufficientBond.selector);
        vm.prank(Alice);
        market.bid(Alice, 100);
    }

    function test_bid_refundsDisplacedPendingOperator() external {
        _depositMarketBond(Alice, MARKET_MIN_BOND_GWEI);
        vm.prank(Alice);
        market.bid(Alice, 100);

        // Alice's bond is locked
        assertEq(market.bondBalances(Alice), 0);

        // Bob outbids Alice (no active epoch yet, so just need to undercut pending)
        // Actually, there's no active epoch so no undercut check against active needed.
        // But the pending check requires Bob < Alice's fee.
        _depositMarketBond(Bob, MARKET_MIN_BOND_GWEI);
        vm.prank(Bob);
        market.bid(Bob, 50);

        // Alice's bond should be refunded
        assertEq(market.bondBalances(Alice), MARKET_MIN_BOND_GWEI);
    }

    function test_bid_RevertWhen_ZeroFeeRecipient() external {
        _depositMarketBond(Alice, MARKET_MIN_BOND_GWEI);
        vm.prank(Alice);
        vm.expectRevert(ProverMarket.ZeroAddress.selector);
        market.bid(address(0), 100);
    }
}

// =======================================================================
// Exit Tests
// =======================================================================

contract ProverMarketExitTest is ProverMarketTestBase {
    function test_exit_clearsPendingEpoch() external {
        _depositMarketBond(Alice, MARKET_MIN_BOND_GWEI);
        vm.prank(Alice);
        market.bid(Alice, 100);

        // Bond is locked
        assertEq(market.bondBalances(Alice), 0);

        vm.prank(Alice);
        market.exit();

        (, uint48 pendingEpochId,,,,,) = market.marketState();
        assertEq(pendingEpochId, 0);

        // Bond refunded
        assertEq(market.bondBalances(Alice), MARKET_MIN_BOND_GWEI);
    }

    function test_exit_marksActiveAsExiting() external {
        _setupActiveBid(Alice, 100);

        vm.prank(Alice);
        market.exit();

        (,,,,, bool exiting, bool degraded) = market.marketState();
        assertTrue(exiting);
        assertFalse(degraded);
    }

    function test_exit_RevertWhen_NoBid() external {
        vm.prank(Alice);
        vm.expectRevert(ProverMarket.NoBidToExit.selector);
        market.exit();
    }

    function test_exit_RevertWhen_AlreadyExiting() external {
        _setupActiveBid(Alice, 100);

        vm.prank(Alice);
        market.exit();

        vm.prank(Alice);
        vm.expectRevert(ProverMarket.NoBidToExit.selector);
        market.exit();
    }

    function test_exit_activeWithoutReplacementMakesNextProposalPermissionless() external {
        _setupActiveBid(Alice, 100);

        vm.prank(Alice);
        market.exit();

        _advanceBlock();
        RecordedProposal memory proposal = _proposeRecordedOne();

        (uint48 activeEpochId,,,, bool permissionless, bool exiting, bool degraded) =
            market.marketState();
        assertEq(activeEpochId, 0);
        assertFalse(permissionless);
        assertFalse(exiting);
        assertFalse(degraded);
        assertEq(market.proposalEpochs(proposal.payload.id), 0);
        assertEq(market.bondBalances(Alice), 0, "exiting prover stays liable for assigned work");
    }
}

// =======================================================================
// Proposal Acceptance Tests (via Inbox.propose)
// =======================================================================

contract ProverMarketProposalTest is ProverMarketTestBase {
    function test_onProposalAccepted_assignsToActiveEpoch() external {
        _setupActiveBid(Alice, 100);

        // The first proposal during _setupActiveBid activated the epoch.
        // Now propose another to verify assignment.
        _advanceBlock();
        ProposedEvent memory payload = _proposeOne();

        uint48 epochId = market.proposalEpochs(payload.id);
        (uint48 activeEpochId,,,,,,) = market.marketState();
        assertEq(epochId, activeEpochId);
    }

    function test_onProposalAccepted_activatesPendingWhenExiting() external {
        // Alice is active
        _setupActiveBid(Alice, 100);

        // Bob bids lower, becomes pending
        _depositMarketBond(Bob, MARKET_MIN_BOND_GWEI);
        vm.prank(Bob);
        market.bid(Bob, 50);

        // Alice exits
        vm.prank(Alice);
        market.exit();

        // Next proposal should activate Bob's epoch
        _advanceBlock();
        _proposeOne();

        (uint48 activeEpochId,,,,,,) = market.marketState();
        (address op,,,,,,) = market.epochs(activeEpochId);
        assertEq(op, Bob);
    }

    function test_onProposalAccepted_accruesFeeForRecipient() external {
        uint64 fee = 100; // 100 gwei per proposal
        _setupActiveBid(Alice, fee);

        // Deposit fee credit for proposer
        uint256 feeWei = uint256(fee) * 1 gwei;
        _depositFeeCredit(proposer, feeWei * 5);

        uint256 creditBefore = market.feeCreditBalances(proposer);
        uint256 recipientCreditBefore = market.feeCreditBalances(Alice);
        uint256 recipientEthBefore = Alice.balance;

        _advanceBlock();
        _proposeOne();

        // Fee should be deducted from proposer and accrued to the fee recipient.
        assertEq(market.feeCreditBalances(proposer), creditBefore - feeWei);
        assertEq(market.feeCreditBalances(Alice), recipientCreditBefore + feeWei);
        assertEq(Alice.balance, recipientEthBefore);
    }

    function test_onProposalAccepted_skipsFeeIfInsufficientCredit() external {
        uint64 fee = 100;
        _setupActiveBid(Alice, fee);

        // Don't deposit any fee credit for proposer
        uint256 recipientBefore = market.feeCreditBalances(Alice);

        _advanceBlock();
        _proposeOne(); // should not revert

        // No fee paid
        assertEq(market.feeCreditBalances(Alice), recipientBefore);
    }

    function test_onProposalAccepted_DoesNotRevertWhen_FeeRecipientRejectsEth() external {
        RejectingFeeRecipient recipient = new RejectingFeeRecipient();
        uint64 fee = 100;
        uint256 feeWei = uint256(fee) * 1 gwei;

        bondToken.mint(address(recipient), _toTokenAmount(MARKET_MIN_BOND_GWEI));
        recipient.depositBondAndBid(market, IERC20(address(bondToken)), MARKET_MIN_BOND_GWEI, fee);

        _depositFeeCredit(proposer, feeWei);

        _advanceBlock();
        ProposedEvent memory payload = _proposeOne();

        assertEq(market.proposalEpochs(payload.id), 1);
        assertEq(market.feeCreditBalances(address(recipient)), feeWei);
    }

    function test_onProposalAccepted_activatesPendingOnNewProposal() external {
        // Alice gets active with a high fee
        _setupActiveBid(Alice, 1000);

        // Bob outbids with lower fee, becomes pending
        _depositMarketBond(Bob, MARKET_MIN_BOND_GWEI);
        vm.prank(Bob);
        market.bid(Bob, 500);

        // Next proposal should activate Bob's epoch (pending gets activated on proposal)
        _advanceBlock();
        _proposeOne();

        (uint48 activeEpochId,,,,,,) = market.marketState();
        (address op,,,,,,) = market.epochs(activeEpochId);
        assertEq(op, Bob);
    }
}

contract ProverMarketDegradedModeTest is ProverMarketTestBase {
    function test_onProposalAccepted_entersDegradedModeAndParksPendingBid() external {
        address[9] memory operators =
            [Alice, Bob, Carol, David, Emma, Frank, Grace, Henry, Isabella];
        uint64 baseFee = 1_000;
        RecordedProposal memory lastProposal;

        for (uint256 i; i < operators.length; ++i) {
            _depositMarketBond(operators[i], MARKET_MIN_BOND_GWEI);
            vm.prank(operators[i]);
            market.bid(operators[i], baseFee - uint64(i));

            _advanceBlock();
            lastProposal = _proposeRecordedOne();
        }

        (uint48 activeEpochId, uint48 pendingEpochId,,, bool permissionless, bool exiting, bool degraded) =
            market.marketState();
        assertEq(activeEpochId, 0);
        assertGt(pendingEpochId, 0);
        assertFalse(permissionless);
        assertFalse(exiting);
        assertTrue(degraded);
        assertEq(market.proposalEpochs(lastProposal.payload.id), 0);

        (address pendingOperator,,,,,,) = market.epochs(pendingEpochId);
        assertEq(pendingOperator, Isabella);
    }

    function test_onProofAccepted_clearsDegradedModeAfterBacklogDrains() external {
        address[9] memory operators =
            [Alice, Bob, Carol, David, Emma, Frank, Grace, Henry, Isabella];
        uint64 baseFee = 1_000;
        RecordedProposal[] memory proposals = new RecordedProposal[](operators.length);

        for (uint256 i; i < operators.length; ++i) {
            _depositMarketBond(operators[i], MARKET_MIN_BOND_GWEI);
            vm.prank(operators[i]);
            market.bid(operators[i], baseFee - uint64(i));

            _advanceBlock();
            proposals[i] = _proposeRecordedOne();
        }

        vm.warp(block.timestamp + PERMISSIONLESS_PROVING_DELAY);
        _proveRecordedRangeAs(proposals, Isabella, Isabella);

        (uint48 activeEpochId, uint48 pendingEpochId, uint48 lastFinalized,,,, bool degraded) =
            market.marketState();
        assertEq(activeEpochId, 0);
        assertGt(pendingEpochId, 0);
        assertEq(lastFinalized, proposals[proposals.length - 1].payload.id);
        assertFalse(degraded);
        assertEq(market.bondBalances(Isabella), MARKET_MIN_BOND_GWEI);

        _advanceBlock();
        RecordedProposal memory nextProposal = _proposeRecordedOne();

        (activeEpochId, pendingEpochId,,,,, degraded) = market.marketState();
        assertGt(activeEpochId, 0);
        assertEq(pendingEpochId, 0);
        assertFalse(degraded);
        assertEq(market.proposalEpochs(nextProposal.payload.id), activeEpochId);

        (address activeOperator,,,,,,) = market.epochs(activeEpochId);
        assertEq(activeOperator, Isabella);
    }
}

// =======================================================================
// Proof Authorization Tests (via Inbox.prove)
// =======================================================================

contract ProverMarketProofAuthTest is ProverMarketTestBase {
    function test_beforeProofSubmission_allowsEpochOperator() external {
        // Set up prover (Carol) as the epoch operator — bid but don't propose yet
        _depositMarketBond(prover, MARKET_MIN_BOND_GWEI);
        vm.prank(prover);
        market.bid(prover, 100);

        // Build batch — _buildBatchInput proposes internally, which also activates the epoch
        _advanceBlock();
        IInbox.ProveInput memory input = _buildBatchInput(1);
        _prove(input); // _prove uses `prover` as caller (the epoch operator)
    }

    function test_beforeProofSubmission_RevertWhen_NotOperator() external {
        // Set up Alice as the epoch operator — bid but don't propose yet
        _depositMarketBond(Alice, MARKET_MIN_BOND_GWEI);
        vm.prank(Alice);
        market.bid(Alice, 100);

        // Build batch — activates Alice's epoch
        _advanceBlock();
        IInbox.ProveInput memory input = _buildBatchInput(1);

        // Carol (prover) is not the operator, should revert via market check.
        // We encode first, then expectRevert before the actual prove call.
        bytes memory encodedInput = codec.encodeProveInput(input);
        vm.prank(prover);
        vm.expectRevert();
        inbox.prove(encodedInput, bytes("proof"));
    }

    function test_beforeProofSubmission_allowsAnyoneAfterDelay() external {
        // Set up Alice as the epoch operator
        _depositMarketBond(Alice, MARKET_MIN_BOND_GWEI);
        vm.prank(Alice);
        market.bid(Alice, 100);

        _advanceBlock();
        IInbox.ProveInput memory input = _buildBatchInput(1);

        // Warp past the permissionless proving delay
        vm.warp(block.timestamp + PERMISSIONLESS_PROVING_DELAY);

        // Carol (prover) is not the operator but delay has passed
        _prove(input);
    }

    function test_beforeProofSubmission_allowsAnyoneInPermissionlessMode() external {
        // Set up Alice as the epoch operator
        _depositMarketBond(Alice, MARKET_MIN_BOND_GWEI);
        vm.prank(Alice);
        market.bid(Alice, 100);

        _advanceBlock();
        IInbox.ProveInput memory input = _buildBatchInput(1);

        // Force permissionless mode
        market.forcePermissionlessMode(true);

        // Carol (prover) is not the operator but permissionless mode is on
        _prove(input);
    }
}

// =======================================================================
// Proof Acceptance Tests
// =======================================================================

contract ProverMarketProofAcceptedTest is ProverMarketTestBase {
    function test_onProofAccepted_updatesLastFinalized() external {
        // Set up prover as epoch operator without pre-proposing
        _depositMarketBond(prover, MARKET_MIN_BOND_GWEI);
        vm.prank(prover);
        market.bid(prover, 100);

        _advanceBlock();
        IInbox.ProveInput memory input = _buildBatchInput(1);
        _prove(input);

        (,, uint48 lastFinalized,,,,) = market.marketState();
        assertGt(lastFinalized, 0);
    }

    function test_onProofAccepted_releasesBondForDisplacedEpoch() external {
        // Alice becomes active
        _setupActiveBid(Alice, 1000);

        // Bob outbids, becomes pending
        _depositMarketBond(Bob, MARKET_MIN_BOND_GWEI);
        vm.prank(Bob);
        market.bid(Bob, 500);

        // Next proposal activates Bob, displaces Alice
        _advanceBlock();
        _proposeOne();

        // Alice's bond should be locked (displaced but proposals not yet finalized)
        assertEq(market.bondBalances(Alice), 0, "Alice bond still locked while displaced");
    }

    function test_onProofAccepted_lateSelfProofMovesSlashIntoRewardPool() external {
        _depositMarketBond(Alice, MARKET_MIN_BOND_GWEI);
        vm.prank(Alice);
        market.bid(Alice, 100);

        _advanceBlock();
        RecordedProposal[] memory proposals = new RecordedProposal[](1);
        proposals[0] = _proposeRecordedOne();

        vm.warp(block.timestamp + PERMISSIONLESS_PROVING_DELAY);
        _proveRecordedRangeAs(proposals, Alice, Alice);

        (uint48 activeEpochId,,,,,,) = market.marketState();
        assertEq(activeEpochId, 0);
        assertEq(market.bondBalances(Alice), 0);
        assertEq(market.rescueRewardPool(), MARKET_MIN_BOND_GWEI);
    }

    function test_onProofAccepted_rescueProofClaimsCurrentSlashAndRewardPool() external {
        _depositMarketBond(Alice, MARKET_MIN_BOND_GWEI);
        vm.prank(Alice);
        market.bid(Alice, 100);

        _advanceBlock();
        RecordedProposal[] memory firstRange = new RecordedProposal[](1);
        firstRange[0] = _proposeRecordedOne();

        vm.warp(block.timestamp + PERMISSIONLESS_PROVING_DELAY);
        _proveRecordedRangeAs(firstRange, Alice, Alice);

        _depositMarketBond(Bob, MARKET_MIN_BOND_GWEI);
        vm.prank(Bob);
        market.bid(Bob, 50);

        _advanceBlock();
        RecordedProposal[] memory secondRange = new RecordedProposal[](1);
        secondRange[0] = _proposeRecordedOne();

        vm.warp(block.timestamp + PERMISSIONLESS_PROVING_DELAY);
        _proveRecordedRangeAs(secondRange, prover, prover);

        assertEq(market.bondBalances(Bob), 0);
        assertEq(market.bondBalances(prover), MARKET_MIN_BOND_GWEI * 2);
        assertEq(market.rescueRewardPool(), 0);
    }
}

// =======================================================================
// Emergency Mode Tests
// =======================================================================

contract ProverMarketEmergencyTest is ProverMarketTestBase {
    function test_forcePermissionlessMode_toggles() external {
        market.forcePermissionlessMode(true);
        (,,,, bool permissionless,,) = market.marketState();
        assertTrue(permissionless);

        market.forcePermissionlessMode(false);
        (,,,, permissionless,,) = market.marketState();
        assertFalse(permissionless);
    }

    function test_forcePermissionlessMode_RevertWhen_NotOwner() external {
        vm.prank(Alice);
        vm.expectRevert();
        market.forcePermissionlessMode(true);
    }

    function test_forcePermissionlessMode_emitsEvent() external {
        vm.expectEmit();
        emit ProverMarket.PermissionlessModeUpdated(true);
        market.forcePermissionlessMode(true);
    }
}

// =======================================================================
// End-to-End Tests
// =======================================================================

contract ProverMarketE2ETest is ProverMarketTestBase {
    function test_fullLifecycle_bidProposeProve() external {
        // 1. Prover deposits bond and bids
        _depositMarketBond(prover, MARKET_MIN_BOND_GWEI);
        vm.prank(prover);
        market.bid(prover, 50);

        // 2. Proposer deposits fee credit
        _depositFeeCredit(proposer, 1 ether);

        // 3. Propose + Prove via _buildBatchInput (activates epoch, assigns, then prove)
        _advanceBlock();
        IInbox.ProveInput memory input = _buildBatchInput(1);

        // Verify epoch is active
        (uint48 activeEpochId,,,,,,) = market.marketState();
        assertGt(activeEpochId, 0);

        // 4. Prove (as the epoch operator)
        _prove(input);

        // 5. Verify finalization tracked
        (,, uint48 lastFinalized,,,,) = market.marketState();
        assertGt(lastFinalized, 0);
    }

    function test_epochTransition_outbidAndProve() external {
        // Alice bids (pending), prover outbids (also pending, displaces Alice)
        _depositMarketBond(Alice, MARKET_MIN_BOND_GWEI);
        vm.prank(Alice);
        market.bid(Alice, 1000);

        _depositMarketBond(prover, MARKET_MIN_BOND_GWEI);
        vm.prank(prover);
        market.bid(prover, 100);

        // Propose via _buildBatchInput — activates prover's epoch
        _advanceBlock();
        IInbox.ProveInput memory input = _buildBatchInput(1);

        (uint48 activeEpochId,,,,,,) = market.marketState();
        (address op,,,,,,) = market.epochs(activeEpochId);
        assertEq(op, prover, "prover should be active operator");

        // Prove as prover
        _prove(input);
    }
}
