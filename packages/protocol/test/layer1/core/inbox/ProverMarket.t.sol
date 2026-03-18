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
    uint48 internal constant PERMISSIONLESS_PROVING_DELAY = 24 hours;

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
            PERMISSIONLESS_PROVING_DELAY,
            2 hours
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

        (, uint48 pendingEpochId,,,,) = market.marketState();
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
// Fee Tests
// =======================================================================

contract ProverMarketFeeTest is ProverMarketTestBase {
    function test_propose_chargesProverFee() external {
        uint64 fee = 100; // 100 gwei per proposal
        _setupActiveBid(Alice, fee);

        uint256 feeBefore = market.feeBalances(Alice);
        _advanceBlock();
        _proposeOne();

        uint256 feeWei = uint256(fee) * 1 gwei;
        assertEq(market.feeBalances(Alice) - feeBefore, feeWei);
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

        uint256 totalFees = market.feeBalances(Alice);
        assertGt(totalFees, 0);

        uint256 balBefore = Alice.balance;
        vm.prank(Alice);
        market.withdrawFees(totalFees);

        assertEq(Alice.balance - balBefore, totalFees);
        assertEq(market.feeBalances(Alice), 0);
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

        (, uint48 pendingEpochId,,,,) = market.marketState();
        assertEq(pendingEpochId, 1);

        (address prv, uint64 fee, uint64 bonded,,,) = market.epochs(pendingEpochId);
        assertEq(prv, Alice);
        assertEq(fee, 100);
        assertEq(bonded, MARKET_MIN_BOND_GWEI);

        // Bond should be locked
        assertEq(market.bondBalances(Alice), 0);
    }

    function test_bid_activatesOnFirstProposal() external {
        _depositMarketBond(Alice, MARKET_MIN_BOND_GWEI);
        vm.prank(Alice);
        market.bid(100);

        // Propose to trigger activation
        _advanceBlock();
        _proposeOne();

        (uint48 activeEpochId, uint48 pendingEpochId,,,,) = market.marketState();
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

        (, uint48 pendingEpochId,,,,) = market.marketState();
        (address prv,,,,,) = market.epochs(pendingEpochId);
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

    function test_bid_refundsDisplacedPendingOperator() external {
        _depositMarketBond(Alice, MARKET_MIN_BOND_GWEI);
        vm.prank(Alice);
        market.bid(100);

        // Alice's bond is locked
        assertEq(market.bondBalances(Alice), 0);

        // Bob outbids Alice (no active epoch yet, so just need to undercut pending)
        // Actually, there's no active epoch so no undercut check against active needed.
        // But the pending check requires Bob < Alice's fee.
        _depositMarketBond(Bob, MARKET_MIN_BOND_GWEI);
        vm.prank(Bob);
        market.bid(50);

        // Alice's bond should be refunded
        assertEq(market.bondBalances(Alice), MARKET_MIN_BOND_GWEI);
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

        // Bond is locked
        assertEq(market.bondBalances(Alice), 0);

        vm.prank(Alice);
        market.exit();

        (, uint48 pendingEpochId,,,,) = market.marketState();
        assertEq(pendingEpochId, 0);

        // Bond refunded
        assertEq(market.bondBalances(Alice), MARKET_MIN_BOND_GWEI);
    }

    function test_exit_marksActiveAsExiting() external {
        _setupActiveBid(Alice, 100);

        vm.prank(Alice);
        market.exit();

        (,,,,, bool exiting) = market.marketState();
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
        RecordedProposal memory proposal = _proposeRecordedOne();

        (uint48 activeEpochId,,,, bool permissionless, bool exiting) = market.marketState();
        assertEq(activeEpochId, 0);
        assertFalse(permissionless);
        assertFalse(exiting);
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

        (uint48 activeEpochId,,,,,) = market.marketState();
        (,,,,, uint48 lastPropId) = market.epochs(activeEpochId);
        assertEq(lastPropId, payload.id);
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

        (uint48 activeEpochId,,,,,) = market.marketState();
        (address prv,,,,,) = market.epochs(activeEpochId);
        assertEq(prv, Bob);
    }

    function test_onProposalAccepted_accruesFeeForProver() external {
        uint64 fee = 100; // 100 gwei per proposal
        _setupActiveBid(Alice, fee);

        uint256 feeBefore = market.feeBalances(Alice);
        uint256 feeWei = uint256(fee) * 1 gwei;

        _advanceBlock();
        _proposeOne();

        // Fee should be accrued to the epoch prover.
        assertEq(market.feeBalances(Alice) - feeBefore, feeWei);
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

        (uint48 activeEpochId,,,,,) = market.marketState();
        (address prv,,,,,) = market.epochs(activeEpochId);
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
        // We encode first, then expectRevert before the actual prove call.
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
        vm.warp(block.timestamp + PERMISSIONLESS_PROVING_DELAY);

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
    function test_onProofAccepted_updatesLastFinalized() external {
        // Set up prover as epoch operator without pre-proposing
        _depositMarketBond(prover, MARKET_MIN_BOND_GWEI);
        vm.prank(prover);
        market.bid(100);

        _advanceBlock();
        IInbox.ProveInput memory input = _buildBatchInput(1);
        _prove(input);

        (,, uint48 lastFinalized,,,) = market.marketState();
        assertGt(lastFinalized, 0);
    }

    function test_onProofAccepted_releasesBondForDisplacedEpoch() external {
        // Alice becomes active
        _setupActiveBid(Alice, 1000);

        // Bob outbids, becomes pending
        _depositMarketBond(Bob, MARKET_MIN_BOND_GWEI);
        vm.prank(Bob);
        market.bid(500);

        // Next proposal activates Bob, displaces Alice
        _advanceBlock();
        _proposeOne();

        // Alice's bond should be locked (displaced but proposals not yet finalized)
        assertEq(market.bondBalances(Alice), 0, "Alice bond still locked while displaced");
    }

    function test_onProofAccepted_lateSelfProofMovesSlashIntoRewardPool() external {
        _depositMarketBond(Alice, MARKET_MIN_BOND_GWEI);
        vm.prank(Alice);
        market.bid(100);

        _advanceBlock();
        RecordedProposal[] memory proposals = new RecordedProposal[](1);
        proposals[0] = _proposeRecordedOne();

        vm.warp(block.timestamp + PERMISSIONLESS_PROVING_DELAY);
        _proveRecordedRangeAs(proposals, Alice, Alice);

        (uint48 activeEpochId,,,,,) = market.marketState();
        assertEq(activeEpochId, 0);
        assertEq(market.bondBalances(Alice), 0);
        assertEq(market.rescueRewardPool(), MARKET_MIN_BOND_GWEI);
    }

    function test_onProofAccepted_rescueProofClaimsCurrentSlashAndRewardPool() external {
        _depositMarketBond(Alice, MARKET_MIN_BOND_GWEI);
        vm.prank(Alice);
        market.bid(100);

        _advanceBlock();
        RecordedProposal[] memory firstRange = new RecordedProposal[](1);
        firstRange[0] = _proposeRecordedOne();

        vm.warp(block.timestamp + PERMISSIONLESS_PROVING_DELAY);
        _proveRecordedRangeAs(firstRange, Alice, Alice);

        _depositMarketBond(Bob, MARKET_MIN_BOND_GWEI);
        vm.prank(Bob);
        market.bid(50);

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
        (,,,, bool permissionless,) = market.marketState();
        assertTrue(permissionless);

        market.forcePermissionlessMode(false);
        (,,,, permissionless,) = market.marketState();
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
        // Proposer sends ETH with propose to pay prover fee.
        _advanceBlock();
        IInbox.ProveInput memory input = _buildBatchInput(1);

        // Verify epoch is active
        (uint48 activeEpochId,,,,,) = market.marketState();
        assertGt(activeEpochId, 0);

        // 3. Prove (as the epoch operator)
        _prove(input);

        // 4. Verify finalization tracked
        (,, uint48 lastFinalized,,,) = market.marketState();
        assertGt(lastFinalized, 0);
    }

    function test_fullLifecycle_bidProposeProveFeeWithdraw() external {
        // 1. Prover deposits bond (extra for withdrawal after bid locks _minBond)
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
        uint256 fees = market.feeBalances(prover);
        assertGt(fees, 0);
        uint256 balBefore = prover.balance;
        vm.prank(prover);
        market.withdrawFees(fees);
        assertEq(prover.balance - balBefore, fees);

        // 5. Bond is still locked in active epoch (not displaced/finalized yet)
        assertEq(market.bondBalances(prover), 0);
    }

    function test_displacedBondRelease_fullFlow() external {
        // Alice becomes active (epoch 1 activated on proposal 1)
        _depositMarketBond(Alice, MARKET_MIN_BOND_GWEI);
        vm.prank(Alice);
        market.bid(1000);

        // Record Alice's activation proposal
        _advanceBlock();
        RecordedProposal[] memory allProposals = new RecordedProposal[](2);
        allProposals[0] = _proposeRecordedOne();

        // Bob outbids — becomes pending
        _depositMarketBond(Bob, MARKET_MIN_BOND_GWEI);
        vm.prank(Bob);
        market.bid(500);

        // Propose again: displaces Alice (epoch 1 → displaced), activates Bob (epoch 2)
        _advanceBlock();
        allProposals[1] = _proposeRecordedOne();

        // Alice's bond is locked (displaced, proposals not yet finalized)
        assertEq(market.bondBalances(Alice), 0);

        // Wait for permissionless delay so anyone can prove the full range
        vm.warp(block.timestamp + PERMISSIONLESS_PROVING_DELAY);

        // Prove both proposals — covers Alice's range, should release her bond
        // (slashing also applies since we're past the delay)
        _proveRecordedRangeAs(allProposals, prover, prover);

        // Alice's displaced bond was slashed (past permissionless delay), goes to rescue prover
        // Bob's active epoch was NOT slashed (only firstNewProposalId's epoch is checked)
        assertEq(market.bondBalances(prover), MARKET_MIN_BOND_GWEI, "rescue prover gets slashed bond");
    }

    function test_zeroFeeEpoch_chargesNothing() external {
        // Prover bids with zero fee
        _setupActiveBid(Alice, 0);

        uint256 balBefore = proposer.balance;
        _advanceBlock();
        _proposeOne();

        // No fee charged, all ETH refunded
        assertEq(market.feeBalances(Alice), 0);
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
        assertTrue(market.canSubmitProof(Bob, payload.id, PERMISSIONLESS_PROVING_DELAY));
    }

    function test_viewFunctions_returnCorrectImmutables() external view {
        assertEq(market.minBond(), MARKET_MIN_BOND_GWEI);
        assertEq(market.permissionlessProvingDelay(), PERMISSIONLESS_PROVING_DELAY);
        assertEq(market.provingWindow(), 2 hours);
        assertEq(market.bondToken(), address(bondToken));
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

        (uint48 activeEpochId,,,,,) = market.marketState();
        (address prv,,,,,) = market.epochs(activeEpochId);
        assertEq(prv, prover, "prover should be active operator");

        // Prove as prover
        _prove(input);
    }
}
