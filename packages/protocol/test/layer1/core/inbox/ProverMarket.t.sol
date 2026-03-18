// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { InboxTestBase } from "./InboxTestBase.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Vm } from "forge-std/src/Vm.sol";
import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { Inbox } from "src/layer1/core/impl/Inbox.sol";
import { ProverMarket } from "src/layer1/core/impl/ProverMarket.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";

/// @title ProverMarketTestBase
/// @notice Shared setup for ProverMarket tests — deploys a real ProverMarket wired to Inbox.
abstract contract ProverMarketTestBase is InboxTestBase {
    struct RecordedProposal {
        ProposedEvent payload;
        uint48 timestamp;
    }

    ProverMarket internal market;

    uint64 internal constant MARKET_MIN_BOND_GWEI = 1_000_000_000; // 1 gwei in token
    uint48 internal constant MARKET_PROVING_WINDOW = 2 hours;
    uint64 internal constant MARKET_BOND_PER_PROPOSAL = 100_000_000; // 0.1 gwei-token per proposal
    uint64 internal constant MARKET_SLASH_PER_PROOF = 500_000_000; // 0.5 gwei-token per late proof

    function setUp() public virtual override {
        super.setUp();
    }

    function _buildConfig() internal virtual override returns (IInbox.Config memory) {
        // proverMarket is set in _deployInbox() via address prediction; use a placeholder here.
        return IInbox.Config({
            proofVerifier: address(verifier),
            proposerChecker: address(proposerChecker),
            proverMarket: address(1), // overridden in _deployInbox
            signalService: address(signalService),
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
    /// Uses vm.computeCreateAddress to predict the Inbox proxy address, breaking the circular
    /// dependency: ProverMarket needs the Inbox address, Inbox needs the ProverMarket address.
    /// Deployment order: market impl (+0), market proxy (+1), inbox impl (+2), inbox proxy (+3).
    function _deployInbox() internal virtual override returns (Inbox) {
        address predictedInboxProxy =
            vm.computeCreateAddress(address(this), vm.getNonce(address(this)) + 3);

        ProverMarket marketImpl = new ProverMarket(
            predictedInboxProxy,
            address(bondToken),
            MARKET_MIN_BOND_GWEI,
            MARKET_PROVING_WINDOW,
            500, // 5% minimum bid discount
            MARKET_BOND_PER_PROPOSAL,
            MARKET_SLASH_PER_PROOF,
            10 // max bid = 10x EWMA
        );
        market = ProverMarket(
            address(
                new ERC1967Proxy(
                    address(marketImpl), abi.encodeCall(ProverMarket.init, (address(this)))
                )
            )
        );

        config.proverMarket = address(market);
        Inbox inbox = super._deployInbox();
        assertEq(address(inbox), predictedInboxProxy, "inbox proxy address mismatch");
        return inbox;
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

    /// @dev Returns the bond balance for an account from the consolidated ProverAccount.
    function _bondBalance(address _account) internal view returns (uint64) {
        (uint64 bal,,) = market.proverAccounts(_account);
        return bal;
    }

    /// @dev Returns the reserved bond for an account from the consolidated ProverAccount.
    function _reservedBond(address _account) internal view returns (uint64) {
        (, uint64 res,) = market.proverAccounts(_account);
        return res;
    }

    /// @dev Returns the accrued fees for an account from the consolidated ProverAccount.
    function _feesAccrued(address _account) internal view returns (uint128) {
        (,, uint128 fees) = market.proverAccounts(_account);
        return fees;
    }

    /// @dev Sets up a prover with a bid in the market and proposes so the epoch activates.
    function _setupActiveBid(
        address _prover,
        uint64 _feeInGwei
    )
        internal
        returns (uint48 epochId_)
    {
        _depositMarketBond(_prover, MARKET_MIN_BOND_GWEI);
        vm.prank(_prover);
        market.bid(_feeInGwei);

        (, uint48 pendingEpochId,,,,,) = market.marketState();
        epochId_ = pendingEpochId;

        // Propose to activate the epoch
        _advanceBlock();
        _proposeOne();
    }

    /// @dev Override to send ETH with every propose (covers prover fee + refund).
    function _proposeAndDecodeWithGas(
        IInbox.ProposeInput memory _input,
        string memory _benchName
    )
        internal
        override
        returns (ProposedEvent memory payload_)
    {
        bytes memory encodedInput = codec.encodeProposeInput(_input);
        vm.recordLogs();
        vm.startPrank(proposer);

        if (bytes(_benchName).length > 0) vm.startSnapshotGas("shasta-propose", _benchName);
        inbox.propose{ value: 1 ether }(bytes(""), encodedInput);
        if (bytes(_benchName).length > 0) vm.stopSnapshotGas();

        vm.stopPrank();
        payload_ = _readProposedEvent();
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
                lastProposalHash: inbox.getProposalHash(
                    _proposals[_proposals.length - 1].payload.id
                ),
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
        assertEq(_bondBalance(Alice), amount);
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
        vm.expectRevert(EssentialContract.ZERO_VALUE.selector);
        market.depositBond(0);
    }

    function test_withdrawBond_transfersTokens() external {
        uint64 amount = 5_000_000_000;
        _depositMarketBond(Alice, amount);

        uint256 balBefore = bondToken.balanceOf(Alice);
        vm.prank(Alice);
        market.withdrawBond(amount);

        assertEq(bondToken.balanceOf(Alice) - balBefore, uint256(amount) * 1 gwei);
        assertEq(_bondBalance(Alice), 0);
    }

    function test_withdrawBond_RevertWhen_InsufficientBalance() external {
        _depositMarketBond(Alice, 100);
        vm.prank(Alice);
        vm.expectRevert(ProverMarket.InsufficientBond.selector);
        market.withdrawBond(200);
    }

    function test_withdrawBond_RevertWhen_BondReserved() external {
        // Deposit bond, bid, and propose so bond gets reserved
        _setupActiveBid(Alice, 100);

        // Alice has MARKET_MIN_BOND_GWEI in bondBalances, but some is reserved
        uint64 reserved = _reservedBond(Alice);
        assertGt(reserved, 0, "bond should be reserved after proposal");

        // Try to withdraw the full balance — should fail because reserved portion is locked
        vm.prank(Alice);
        vm.expectRevert(ProverMarket.InsufficientBond.selector);
        market.withdrawBond(MARKET_MIN_BOND_GWEI);
    }

    function test_withdrawBond_succeedsForUnreservedPortion() external {
        // Deposit extra bond beyond the minimum
        uint64 extraAmount = 2_000_000_000;
        _depositMarketBond(Alice, MARKET_MIN_BOND_GWEI + extraAmount);

        vm.prank(Alice);
        market.bid(100);

        // Propose to activate and reserve bond
        _advanceBlock();
        _proposeOne();

        uint64 reserved = _reservedBond(Alice);
        assertGt(reserved, 0, "bond should be reserved");

        // Withdraw the unreserved portion
        uint64 unreserved = _bondBalance(Alice) - reserved;
        assertGt(unreserved, 0, "should have unreserved bond");

        vm.prank(Alice);
        market.withdrawBond(unreserved);

        assertEq(_bondBalance(Alice), reserved, "only reserved bond should remain");
    }
}

// =======================================================================
// Fee Tests
// =======================================================================

contract ProverMarketFeeTest is ProverMarketTestBase {
    function test_propose_chargesProverFee() external {
        uint64 fee = 100; // 100 gwei per proposal
        _setupActiveBid(Alice, fee);

        uint128 feeBefore = _feesAccrued(Alice);
        _advanceBlock();
        _proposeOne();

        uint256 feeWei = uint256(fee) * 1 gwei;
        assertEq(_feesAccrued(Alice) - feeBefore, feeWei);
    }

    function test_propose_refundsExcessEth() external {
        uint64 fee = 100;
        _setupActiveBid(Alice, fee);

        uint256 balBefore = proposer.balance;
        _advanceBlock();
        _proposeOne(); // sends 1 ether, gets refund

        uint256 feeWei = uint256(fee) * 1 gwei;
        // Proposer paid exactly the fee (refund covers the rest)
        assertEq(balBefore - proposer.balance, feeWei);
    }

    function test_propose_RevertWhen_InsufficientFee() external {
        uint64 fee = 100;
        _setupActiveBid(Alice, fee);

        _advanceBlock();
        _setBlobHashes(3);
        bytes memory encodedInput = codec.encodeProposeInput(_defaultProposeInput());
        vm.prank(proposer);
        vm.expectRevert(ProverMarket.InsufficientFee.selector);
        inbox.propose{ value: 0 }(bytes(""), encodedInput);
    }

    function test_withdrawFees_sendsEth() external {
        uint64 fee = 100;
        _setupActiveBid(Alice, fee);

        _advanceBlock();
        _proposeOne();

        uint256 totalFees = _feesAccrued(Alice);
        assertGt(totalFees, 0);

        uint256 balBefore = Alice.balance;
        vm.prank(Alice);
        market.withdrawFees(totalFees);

        assertEq(Alice.balance - balBefore, totalFees);
        assertEq(_feesAccrued(Alice), 0);
    }

    function test_withdrawFees_RevertWhen_InsufficientBalance() external {
        vm.prank(Alice);
        vm.expectRevert(ProverMarket.InsufficientFees.selector);
        market.withdrawFees(1 ether);
    }

    function test_activeFeeInGwei_returnsActiveEpochFee() external {
        _setupActiveBid(Alice, 100);
        assertEq(market.activeFeeInGwei(), 100);
    }

    function test_activeFeeInGwei_returnsPendingFeeWhenActiveDisplaced() external {
        _setupActiveBid(Alice, 100);

        _depositMarketBond(Bob, MARKET_MIN_BOND_GWEI);
        vm.prank(Bob);
        market.bid(50);

        // Pending will activate on next proposal, so activeFeeInGwei returns pending's fee
        assertEq(market.activeFeeInGwei(), 50);
    }

    function test_activeFeeInGwei_returnsZeroInPermissionlessMode() external {
        _setupActiveBid(Alice, 100);
        market.forcePermissionlessMode(true);
        assertEq(market.activeFeeInGwei(), 0);
    }
}

// =======================================================================
// Bid Tests
// =======================================================================

contract ProverMarketBidTest is ProverMarketTestBase {
    function test_bid_createsPendingEpoch() external {
        _depositMarketBond(Alice, MARKET_MIN_BOND_GWEI);

        vm.prank(Alice);
        market.bid(100);

        (, uint48 pendingEpochId,,,,,) = market.marketState();
        assertEq(pendingEpochId, 1);

        (address prv, uint64 fee) = market.epochs(pendingEpochId);
        assertEq(prv, Alice);
        assertEq(fee, 100);

        // Bond is NOT locked after bid — it stays in bondBalances
        assertEq(_bondBalance(Alice), MARKET_MIN_BOND_GWEI);
    }

    function test_bid_activatesOnFirstProposal() external {
        _depositMarketBond(Alice, MARKET_MIN_BOND_GWEI);
        vm.prank(Alice);
        market.bid(100);

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
        market.bid(50);

        (, uint48 pendingEpochId,,,,,) = market.marketState();
        (address prv,) = market.epochs(pendingEpochId);
        assertEq(prv, Bob);
    }

    function test_bid_RevertWhen_FeeTooHigh() external {
        _setupActiveBid(Alice, 100);

        _depositMarketBond(Bob, MARKET_MIN_BOND_GWEI);
        vm.prank(Bob);
        vm.expectRevert(ProverMarket.BidFeeTooHigh.selector);
        market.bid(100); // must be strictly less
    }

    function test_bid_RevertWhen_InsufficientBond() external {
        vm.expectRevert(ProverMarket.InsufficientBond.selector);
        vm.prank(Alice);
        market.bid(100);
    }

    function test_bid_displacedPendingEpochIsReplaced() external {
        _depositMarketBond(Alice, MARKET_MIN_BOND_GWEI);
        vm.prank(Alice);
        market.bid(100);

        // Bond is NOT locked — stays in bondBalances
        assertEq(_bondBalance(Alice), MARKET_MIN_BOND_GWEI);

        // Bob outbids Alice (no active epoch yet, so just need to undercut pending)
        _depositMarketBond(Bob, MARKET_MIN_BOND_GWEI);
        vm.prank(Bob);
        market.bid(50);

        // Alice's bond stays unchanged — bond was never locked per-epoch
        assertEq(_bondBalance(Alice), MARKET_MIN_BOND_GWEI);

        // Bob is now the pending epoch operator
        (, uint48 pendingEpochId,,,,,) = market.marketState();
        (address prv,) = market.epochs(pendingEpochId);
        assertEq(prv, Bob);
    }
}

// =======================================================================
// Exit Tests
// =======================================================================

contract ProverMarketExitTest is ProverMarketTestBase {
    function test_exit_clearsPendingEpoch() external {
        _depositMarketBond(Alice, MARKET_MIN_BOND_GWEI);
        vm.prank(Alice);
        market.bid(100);

        // Bond is NOT locked
        assertEq(_bondBalance(Alice), MARKET_MIN_BOND_GWEI);

        vm.prank(Alice);
        market.exit();

        (, uint48 pendingEpochId,,,,,) = market.marketState();
        assertEq(pendingEpochId, 0);

        // Bond unchanged — was never locked
        assertEq(_bondBalance(Alice), MARKET_MIN_BOND_GWEI);
    }

    function test_exit_marksActiveAsExiting() external {
        _setupActiveBid(Alice, 100);

        vm.prank(Alice);
        market.exit();

        (,,,, bool exiting,,) = market.marketState();
        assertTrue(exiting);
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
        _proposeRecordedOne();

        (uint48 activeEpochId,,, bool permissionless, bool exiting,,) = market.marketState();
        assertEq(activeEpochId, 0);
        assertFalse(permissionless);
        assertFalse(exiting);
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

        (uint48 activeEpochId,,,,,,) = market.marketState();
        assertEq(market.proposalEpochs(payload.id), activeEpochId);
    }

    function test_onProposalAccepted_activatesPendingWhenExiting() external {
        // Alice is active
        _setupActiveBid(Alice, 100);

        // Bob bids lower, becomes pending
        _depositMarketBond(Bob, MARKET_MIN_BOND_GWEI);
        vm.prank(Bob);
        market.bid(50);

        // Alice exits
        vm.prank(Alice);
        market.exit();

        // Next proposal should activate Bob's epoch
        _advanceBlock();
        _proposeOne();

        (uint48 activeEpochId,,,,,,) = market.marketState();
        (address prv,) = market.epochs(activeEpochId);
        assertEq(prv, Bob);
    }

    function test_onProposalAccepted_accruesFeeForProver() external {
        uint64 fee = 100; // 100 gwei per proposal
        _setupActiveBid(Alice, fee);

        uint128 feeBefore = _feesAccrued(Alice);
        uint256 feeWei = uint256(fee) * 1 gwei;

        _advanceBlock();
        _proposeOne();

        // Fee should be accrued to the epoch prover.
        assertEq(_feesAccrued(Alice) - feeBefore, feeWei);
    }

    function test_onProposalAccepted_activatesPendingOnNewProposal() external {
        // Alice gets active with a high fee
        _setupActiveBid(Alice, 1000);

        // Bob outbids with lower fee, becomes pending
        _depositMarketBond(Bob, MARKET_MIN_BOND_GWEI);
        vm.prank(Bob);
        market.bid(500);

        // Next proposal should activate Bob's epoch (pending gets activated on proposal)
        _advanceBlock();
        _proposeOne();

        (uint48 activeEpochId,,,,,,) = market.marketState();
        (address prv,) = market.epochs(activeEpochId);
        assertEq(prv, Bob);
    }
}

// =======================================================================
// Proof Authorization Tests (via Inbox.prove)
// =======================================================================

contract ProverMarketProofAuthTest is ProverMarketTestBase {
    function test_canSubmitProof_allowsEpochOperator() external {
        // Set up prover (Carol) as the epoch operator — bid but don't propose yet
        _depositMarketBond(prover, MARKET_MIN_BOND_GWEI);
        vm.prank(prover);
        market.bid(100);

        // Build batch — _buildBatchInput proposes internally, which also activates the epoch
        _advanceBlock();
        IInbox.ProveInput memory input = _buildBatchInput(1);
        _prove(input); // _prove uses `prover` as caller (the epoch operator)
    }

    function test_canSubmitProof_RevertWhen_NotOperator() external {
        // Set up Alice as the epoch operator — bid but don't propose yet
        _depositMarketBond(Alice, MARKET_MIN_BOND_GWEI);
        vm.prank(Alice);
        market.bid(100);

        // Build batch — activates Alice's epoch
        _advanceBlock();
        IInbox.ProveInput memory input = _buildBatchInput(1);

        // Carol (prover) is not the operator, should revert via market check.
        bytes memory encodedInput = codec.encodeProveInput(input);
        vm.prank(prover);
        vm.expectRevert(ProverMarket.NotAuthorizedProver.selector);
        inbox.prove(encodedInput, bytes("proof"));
    }

    function test_canSubmitProof_allowsAnyoneAfterDelay() external {
        // Set up Alice as the epoch operator
        _depositMarketBond(Alice, MARKET_MIN_BOND_GWEI);
        vm.prank(Alice);
        market.bid(100);

        _advanceBlock();
        IInbox.ProveInput memory input = _buildBatchInput(1);

        // Warp past the permissionless proving delay
        vm.warp(block.timestamp + MARKET_PROVING_WINDOW);

        // Carol (prover) is not the operator but delay has passed
        _prove(input);
    }

    function test_canSubmitProof_allowsAnyoneInPermissionlessMode() external {
        // Set up Alice as the epoch operator
        _depositMarketBond(Alice, MARKET_MIN_BOND_GWEI);
        vm.prank(Alice);
        market.bid(100);

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
    function test_onProofAccepted_releasesReservedBond() external {
        _depositMarketBond(prover, MARKET_MIN_BOND_GWEI);
        vm.prank(prover);
        market.bid(100);

        _advanceBlock();
        RecordedProposal[] memory proposals = new RecordedProposal[](1);
        proposals[0] = _proposeRecordedOne();

        // Verify bond is reserved after proposal
        uint64 reservedBefore = _reservedBond(prover);
        assertEq(reservedBefore, MARKET_BOND_PER_PROPOSAL, "bond should be reserved for proposal");

        // Prove within window
        _proveRecordedRangeAs(proposals, prover, prover);

        // Reserved bond should be released
        uint64 reservedAfter = _reservedBond(prover);
        assertEq(reservedAfter, 0, "reserved bond should be released after proof");
    }

    function test_onProofAccepted_lateProofSlashesFixedAmount() external {
        _depositMarketBond(Alice, MARKET_MIN_BOND_GWEI);
        vm.prank(Alice);
        market.bid(100);

        _advanceBlock();
        RecordedProposal[] memory proposals = new RecordedProposal[](1);
        proposals[0] = _proposeRecordedOne();

        uint64 bondBefore = _bondBalance(Alice);

        // Warp past proving window for late proof
        vm.warp(block.timestamp + MARKET_PROVING_WINDOW);
        _proveRecordedRangeAs(proposals, Alice, Alice);

        uint64 bondAfter = _bondBalance(Alice);
        // Self-proof late: bondBalances[prv] -= slashAmount, caller == prv so no credit back
        assertEq(bondBefore - bondAfter, MARKET_SLASH_PER_PROOF, "self-proof slash amount");
    }

    function test_onProofAccepted_rescueProverGetsSlash() external {
        _depositMarketBond(Alice, MARKET_MIN_BOND_GWEI);
        vm.prank(Alice);
        market.bid(100);

        _advanceBlock();
        RecordedProposal[] memory proposals = new RecordedProposal[](1);
        proposals[0] = _proposeRecordedOne();

        uint64 aliceBondBefore = _bondBalance(Alice);

        // Warp past proving window
        vm.warp(block.timestamp + MARKET_PROVING_WINDOW);

        // Bob proves as rescue prover
        _proveRecordedRangeAs(proposals, Bob, Bob);

        // Alice's bond should be slashed
        uint64 aliceBondAfter = _bondBalance(Alice);
        assertEq(aliceBondBefore - aliceBondAfter, MARKET_SLASH_PER_PROOF, "Alice slashed");

        // Bob should receive the slash amount
        assertEq(_bondBalance(Bob), MARKET_SLASH_PER_PROOF, "rescue prover gets slash");
    }

    function test_onProofAccepted_partialSlashWhenBondLow() external {
        _depositMarketBond(Alice, MARKET_MIN_BOND_GWEI);
        vm.prank(Alice);
        market.bid(100);

        _advanceBlock();
        RecordedProposal[] memory proposals = new RecordedProposal[](1);
        proposals[0] = _proposeRecordedOne();

        // Withdraw most unreserved bond so Alice has less than MARKET_SLASH_PER_PROOF available
        uint64 reserved = _reservedBond(Alice);
        uint64 withdrawable = _bondBalance(Alice) - reserved;
        // Leave only a tiny amount (less than slash)
        uint64 leaveAmount = MARKET_SLASH_PER_PROOF / 10;
        if (withdrawable > leaveAmount) {
            vm.prank(Alice);
            market.withdrawBond(withdrawable - leaveAmount);
        }

        uint64 aliceBondBefore = _bondBalance(Alice);
        assertLt(aliceBondBefore, MARKET_SLASH_PER_PROOF + reserved, "bond should be low");

        // Warp past proving window
        vm.warp(block.timestamp + MARKET_PROVING_WINDOW);

        // Bob rescue-proves
        _proveRecordedRangeAs(proposals, Bob, Bob);

        // Slash should be capped at available bond
        uint64 aliceBondAfter = _bondBalance(Alice);
        uint64 actualSlash = aliceBondBefore - aliceBondAfter;
        assertLe(actualSlash, MARKET_SLASH_PER_PROOF, "slash capped at available");
        assertEq(_bondBalance(Bob), actualSlash, "rescue prover gets actual slash");
    }

    function test_onProofAccepted_retiresEpochWhenSlashDropsBondBelowReserved() external {
        // Deposit just enough for min bond
        _depositMarketBond(Alice, MARKET_MIN_BOND_GWEI);
        vm.prank(Alice);
        market.bid(100);

        // Propose twice to reserve more bond
        _advanceBlock();
        RecordedProposal[] memory firstProposal = new RecordedProposal[](1);
        firstProposal[0] = _proposeRecordedOne();

        _advanceBlock();
        RecordedProposal[] memory secondProposal = new RecordedProposal[](1);
        secondProposal[0] = _proposeRecordedOne();

        // Withdraw unreserved bond to make total bond tight
        uint64 reserved = _reservedBond(Alice);
        uint64 bal = _bondBalance(Alice);
        if (bal > reserved) {
            vm.prank(Alice);
            market.withdrawBond(bal - reserved);
        }

        // Now Alice's bond == reserved. A slash will drop bond below reserved.
        (uint48 activeEpochIdBefore,,,,,,) = market.marketState();
        assertGt(activeEpochIdBefore, 0, "epoch should be active before slash");

        // Warp past proving window and prove the first proposal (late)
        vm.warp(block.timestamp + MARKET_PROVING_WINDOW);
        _proveRecordedRangeAs(firstProposal, Bob, Bob);

        // After slash, bond < reserved, epoch should be retired
        (uint48 activeEpochIdAfter,,,,,,) = market.marketState();
        assertEq(
            activeEpochIdAfter, 0, "epoch should be retired after slash drops bond below reserved"
        );
    }
}

// =======================================================================
// Emergency Mode Tests
// =======================================================================

contract ProverMarketEmergencyTest is ProverMarketTestBase {
    function test_forcePermissionlessMode_toggles() external {
        market.forcePermissionlessMode(true);
        (,,, bool permissionless,,,) = market.marketState();
        assertTrue(permissionless);

        market.forcePermissionlessMode(false);
        (,,, permissionless,,,) = market.marketState();
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
        market.bid(50);

        // 2. Propose + Prove via _buildBatchInput (activates epoch, assigns, then prove)
        _advanceBlock();
        IInbox.ProveInput memory input = _buildBatchInput(1);

        // Verify epoch is active
        (uint48 activeEpochId,,,,,,) = market.marketState();
        assertGt(activeEpochId, 0);

        // 3. Prove (as the epoch operator)
        _prove(input);
    }

    function test_fullLifecycle_bidProposeProveFeeWithdraw() external {
        // 1. Prover deposits bond
        _depositMarketBond(prover, MARKET_MIN_BOND_GWEI);
        vm.prank(prover);
        market.bid(50);

        // 2. Propose (pays prover fee via msg.value)
        _advanceBlock();
        RecordedProposal[] memory proposals = new RecordedProposal[](1);
        proposals[0] = _proposeRecordedOne();

        // 3. Prove (as epoch operator, within window)
        _proveRecordedRangeAs(proposals, prover, prover);

        // 4. Verify fee accrued and withdraw
        uint256 fees = _feesAccrued(prover);
        assertGt(fees, 0);
        uint256 balBefore = prover.balance;
        vm.prank(prover);
        market.withdrawFees(fees);
        assertEq(prover.balance - balBefore, fees);

        // 5. Reserved bond should be released after proof
        assertEq(_reservedBond(prover), 0, "reserved bond released after proof");
    }

    function test_epochTransition_aliceToBob() external {
        // Alice becomes active (epoch 1 activated on proposal 1)
        _depositMarketBond(Alice, MARKET_MIN_BOND_GWEI);
        vm.prank(Alice);
        market.bid(1000);

        // Record Alice's activation proposal
        _advanceBlock();
        RecordedProposal[] memory allProposals = new RecordedProposal[](2);
        allProposals[0] = _proposeRecordedOne();

        // Verify proposalEpochs tracks correctly
        uint48 aliceEpochId = market.proposalEpochs(allProposals[0].payload.id);
        assertGt(aliceEpochId, 0, "proposal should be tracked to Alice's epoch");

        // Bob outbids — becomes pending
        _depositMarketBond(Bob, MARKET_MIN_BOND_GWEI);
        vm.prank(Bob);
        market.bid(500);

        // Propose again: retires Alice, activates Bob (epoch 2)
        _advanceBlock();
        allProposals[1] = _proposeRecordedOne();

        // Verify Bob's proposal is tracked to his epoch
        uint48 bobEpochId = market.proposalEpochs(allProposals[1].payload.id);
        assertGt(bobEpochId, 0, "proposal should be tracked to Bob's epoch");
        assertTrue(bobEpochId != aliceEpochId, "different epochs for different provers");

        // Wait for permissionless delay so anyone can prove the full range
        vm.warp(block.timestamp + MARKET_PROVING_WINDOW);

        // Prove both proposals
        _proveRecordedRangeAs(allProposals, prover, prover);
    }

    function test_autoRetire_whenBondRunsOut() external {
        // Deposit exact min bond
        _depositMarketBond(Alice, MARKET_MIN_BOND_GWEI);
        vm.prank(Alice);
        market.bid(100);

        // Propose until bond is fully reserved
        uint64 maxProposals = MARKET_MIN_BOND_GWEI / MARKET_BOND_PER_PROPOSAL;
        for (uint64 i = 0; i < maxProposals; ++i) {
            _advanceBlock();
            _proposeOne();
        }

        // Verify all bond is reserved
        assertEq(
            _reservedBond(Alice),
            maxProposals * MARKET_BOND_PER_PROPOSAL,
            "all bond should be reserved"
        );

        // Next proposal should auto-retire the epoch (bond insufficient for next proposal)
        _advanceBlock();
        _proposeOne();

        (uint48 activeEpochId,,,,,,) = market.marketState();
        assertEq(activeEpochId, 0, "epoch should be auto-retired when bond runs out");
    }

    function test_proposalEpochs_tracksCorrectly() external {
        _depositMarketBond(Alice, MARKET_MIN_BOND_GWEI);
        vm.prank(Alice);
        market.bid(100);

        _advanceBlock();
        ProposedEvent memory p1 = _proposeOne();

        _advanceBlock();
        ProposedEvent memory p2 = _proposeOne();

        (uint48 activeEpochId,,,,,,) = market.marketState();
        assertEq(market.proposalEpochs(p1.id), activeEpochId, "p1 mapped to active epoch");
        assertEq(market.proposalEpochs(p2.id), activeEpochId, "p2 mapped to active epoch");
    }

    function test_activatePendingEpoch_skipsWhenBondInsufficient() external {
        // Deposit, bid, then withdraw most bond before proposal activates pending
        _depositMarketBond(Alice, MARKET_MIN_BOND_GWEI);
        vm.prank(Alice);
        market.bid(100);

        // Withdraw nearly all bond — pending prover won't have enough to activate
        vm.prank(Alice);
        market.withdrawBond(MARKET_MIN_BOND_GWEI - 1);

        // Propose — pending should NOT activate because Alice lacks sufficient bond
        _advanceBlock();
        _proposeOne();

        (uint48 activeEpochId, uint48 pendingEpochId,,,,,) = market.marketState();
        assertEq(activeEpochId, 0, "epoch should not activate with insufficient bond");
        assertEq(pendingEpochId, 0, "pending cleared when activation skipped");
    }

    function test_zeroFeeEpoch_chargesNothing() external {
        // Prover bids with zero fee
        _setupActiveBid(Alice, 0);

        uint256 balBefore = proposer.balance;
        _advanceBlock();
        _proposeOne();

        // No fee charged, all ETH refunded
        assertEq(_feesAccrued(Alice), 0);
        // Proposer only lost gas, not fee (1 ether sent, 1 ether refunded)
        assertEq(balBefore - proposer.balance, 0);
    }

    function test_canSubmitProof_directViewCall() external {
        _depositMarketBond(Alice, MARKET_MIN_BOND_GWEI);
        vm.prank(Alice);
        market.bid(100);

        // Activate by proposing
        _advanceBlock();
        ProposedEvent memory payload = _proposeOne();

        // Alice is the epoch prover — should be authorized
        assertTrue(market.canSubmitProof(Alice, payload.id, 0));

        // Bob is not the epoch prover — should be denied within window
        assertFalse(market.canSubmitProof(Bob, payload.id, 0));

        // Anyone authorized after permissionless delay
        assertTrue(market.canSubmitProof(Bob, payload.id, MARKET_PROVING_WINDOW));
    }

    function test_viewFunctions_returnCorrectImmutables() external view {
        assertEq(market.minBond(), MARKET_MIN_BOND_GWEI);
        assertEq(market.provingWindow(), MARKET_PROVING_WINDOW);
        assertEq(market.bondToken(), address(bondToken));
        assertEq(market.bondPerProposal(), MARKET_BOND_PER_PROPOSAL);
        assertEq(market.slashPerProof(), MARKET_SLASH_PER_PROOF);
    }

    function test_feeEwma_initializedOnFirstEpochRetirement() external {
        // Alice bids at fee 1000 and gets activated
        _setupActiveBid(Alice, 1000);

        // Propose a few more to build up proposal count
        _advanceBlock();
        _proposeOne();
        _advanceBlock();
        _proposeOne();

        // Bob outbids — triggers Alice's epoch retirement on next proposal
        _depositMarketBond(Bob, MARKET_MIN_BOND_GWEI);
        vm.prank(Bob);
        market.bid(500);

        _advanceBlock();
        _proposeOne(); // retires Alice, activates Bob

        // First EWMA should be set to Alice's fee directly (ewma was 0)
        assertEq(market.feeEwma(), 1000, "EWMA should be initialized to first epoch's fee");
    }

    function test_feeEwma_blendsOnSubsequentRetirements() external {
        // Alice: fee=1000, serves 1 proposal (activation proposal)
        _setupActiveBid(Alice, 1000);

        // Bob outbids, next proposal retires Alice (1 proposal) and activates Bob
        _depositMarketBond(Bob, MARKET_MIN_BOND_GWEI);
        vm.prank(Bob);
        market.bid(500);

        _advanceBlock();
        _proposeOne(); // retires Alice (EWMA=1000), activates Bob

        assertEq(market.feeEwma(), 1000, "EWMA after first epoch");

        // Bob serves 1 proposal (the activation one above) then gets retired
        // Carol outbids to trigger Bob's retirement
        _depositMarketBond(Carol, MARKET_MIN_BOND_GWEI);
        vm.prank(Carol);
        market.bid(200);

        _advanceBlock();
        _proposeOne(); // retires Bob (1 proposal at fee 500)

        // EWMA = (1000 * 1024 + 500 * 1) / (1024 + 1) = (1024000 + 500) / 1025 = 999
        assertEq(market.feeEwma(), 999, "EWMA blends toward Bob's lower fee");
    }

    function test_feeEwma_proposalWeighted() external {
        // Alice: fee=1000, serves 1 proposal
        _setupActiveBid(Alice, 1000);

        // Bob outbids
        _depositMarketBond(Bob, MARKET_MIN_BOND_GWEI);
        vm.prank(Bob);
        market.bid(500);

        _advanceBlock();
        _proposeOne(); // retires Alice (1 proposal), activates Bob, EWMA=1000

        // Bob serves many proposals before retiring
        for (uint256 i = 0; i < 9; ++i) {
            _advanceBlock();
            _proposeOne();
        }
        // Bob has now served 10 proposals total (1 activation + 9 more)

        // Carol outbids
        _depositMarketBond(Carol, MARKET_MIN_BOND_GWEI);
        vm.prank(Carol);
        market.bid(200);

        _advanceBlock();
        _proposeOne(); // retires Bob (10 proposals at fee 500)

        // EWMA = (1000 * 1024 + 500 * 10) / (1024 + 10) = (1024000 + 5000) / 1034 = 995
        uint64 expectedEwma = uint64((uint256(1000) * 1024 + uint256(500) * 10) / (1024 + 10));
        assertEq(market.feeEwma(), expectedEwma, "more proposals should shift EWMA more");

        // 10 proposals shifts EWMA more than 1 proposal would have
        // 1 proposal: (1000*1024 + 500*1) / 1025 = 999
        // 10 proposals: (1000*1024 + 500*10) / 1034 = 995
        assertLt(market.feeEwma(), 999, "10 proposals should shift EWMA more than 1");
    }

    function test_feeEwma_bidCapEnforcedWhenNoActiveOrPending() external {
        // Build up an EWMA by running one full epoch cycle
        _setupActiveBid(Alice, 100);

        // Alice exits
        vm.prank(Alice);
        market.exit();

        _advanceBlock();
        _proposeOne(); // retires Alice, EWMA set to 100

        assertEq(market.feeEwma(), 100);

        // Now no active or pending epoch. Max bid should be 10 * 100 = 1000
        _depositMarketBond(Bob, MARKET_MIN_BOND_GWEI);

        // Bid at exactly 10x should succeed
        vm.prank(Bob);
        market.bid(1000);
    }

    function test_bid_RevertWhen_FeeExceedsEwmaCap() external {
        // Build up an EWMA by running one full epoch cycle
        _setupActiveBid(Alice, 100);

        vm.prank(Alice);
        market.exit();

        _advanceBlock();
        _proposeOne(); // retires Alice, EWMA set to 100

        // Now no active or pending epoch. Max bid should be 10 * 100 = 1000
        _depositMarketBond(Bob, MARKET_MIN_BOND_GWEI);

        // Bid above 10x should revert
        vm.prank(Bob);
        vm.expectRevert(ProverMarket.BidFeeTooHigh.selector);
        market.bid(1001);
    }

    function test_feeEwma_noBidCapWhenEwmaIsZero() external {
        // Fresh market — EWMA is 0
        assertEq(market.feeEwma(), 0);

        // Should allow any fee since no EWMA baseline exists
        _depositMarketBond(Alice, MARKET_MIN_BOND_GWEI);
        vm.prank(Alice);
        market.bid(type(uint64).max); // extreme fee should be allowed
    }

    function test_feeEwma_noBidCapWhenActiveEpochExists() external {
        // EWMA=100 from a prior cycle
        _setupActiveBid(Alice, 100);
        vm.prank(Alice);
        market.exit();
        _advanceBlock();
        _proposeOne(); // retires, EWMA=100

        // Start a new epoch
        _setupActiveBid(Bob, 50);

        // Now active epoch exists. EWMA cap should NOT apply — undercut rules govern instead
        _depositMarketBond(Carol, MARKET_MIN_BOND_GWEI);
        vm.prank(Carol);
        // Must undercut Bob's 50 by 5% = max 47
        market.bid(47);
    }

    function test_epochTransition_outbidAndProve() external {
        // Alice bids (pending), prover outbids (also pending, displaces Alice)
        _depositMarketBond(Alice, MARKET_MIN_BOND_GWEI);
        vm.prank(Alice);
        market.bid(1000);

        _depositMarketBond(prover, MARKET_MIN_BOND_GWEI);
        vm.prank(prover);
        market.bid(100);

        // Propose via _buildBatchInput — activates prover's epoch
        _advanceBlock();
        IInbox.ProveInput memory input = _buildBatchInput(1);

        (uint48 activeEpochId,,,,,,) = market.marketState();
        (address prv,) = market.epochs(activeEpochId);
        assertEq(prv, prover, "prover should be active operator");

        // Prove as prover
        _prove(input);
    }
}
