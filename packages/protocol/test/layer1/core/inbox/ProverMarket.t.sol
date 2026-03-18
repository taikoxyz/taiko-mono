// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {InboxTestBase} from "./InboxTestBase.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Vm} from "forge-std/src/Vm.sol";
import {IInbox} from "src/layer1/core/iface/IInbox.sol";
import {Inbox} from "src/layer1/core/impl/Inbox.sol";
import {ProverMarket} from "src/layer1/core/impl/ProverMarket.sol";
import {EssentialContract} from "src/shared/common/EssentialContract.sol";

contract RejectEtherBidder {
    ProverMarket internal immutable _market;
    IERC20 internal immutable _bondToken;

    constructor(ProverMarket market_, IERC20 bondToken_) {
        _market = market_;
        _bondToken = bondToken_;
    }

    receive() external payable {
        revert();
    }

    function depositAndBid(uint64 bondAmount_, uint64 feeInGwei_) external {
        _bondToken.approve(address(_market), type(uint256).max);
        _market.depositBond(bondAmount_);
        _market.bid(feeInGwei_);
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

    uint64 internal constant MARKET_MIN_BOND_GWEI = 1_000_000_000;
    uint48 internal constant MARKET_PROVING_WINDOW = 2 hours;
    uint48 internal constant MARKET_PROVING_GRACE = 5 minutes;
    uint64 internal constant MARKET_BOND_PER_PROPOSAL = 100_000_000;
    uint64 internal constant MARKET_SLASH_PER_PROOF = 500_000_000;

    function setUp() public virtual override {
        super.setUp();
    }

    function _buildConfig() internal virtual override returns (IInbox.Config memory) {
        return IInbox.Config({
            proofVerifier: address(verifier),
            proposerChecker: address(proposerChecker),
            proverMarket: address(1),
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

    function _deployInbox() internal virtual override returns (Inbox) {
        address predictedInboxProxy = vm.computeCreateAddress(address(this), vm.getNonce(address(this)) + 3);

        ProverMarket marketImpl = new ProverMarket(
            ProverMarket.Params({
                inboxAddr: predictedInboxProxy,
                bondTokenAddr: address(bondToken),
                minBond: MARKET_MIN_BOND_GWEI,
                provingWindowSeconds: MARKET_PROVING_WINDOW,
                bidDiscountBasisPoints: 500,
                bondPerProposal: MARKET_BOND_PER_PROPOSAL,
                slashPerProof: MARKET_SLASH_PER_PROOF,
                maxBidMultiplier: 10,
                maxFee: 10_000_000_000,
                bidCooldownSeconds: 1 hours,
                provingGracePeriodSeconds: 5 minutes
            })
        );
        market = ProverMarket(
            address(new ERC1967Proxy(address(marketImpl), abi.encodeCall(ProverMarket.init, (address(this)))))
        );

        config.proverMarket = address(market);
        Inbox inbox_ = super._deployInbox();
        assertEq(address(inbox_), predictedInboxProxy, "inbox proxy address mismatch");
        return inbox_;
    }

    function _readProposedEvent() internal override returns (ProposedEvent memory payload_) {
        Vm.Log[] memory logs = vm.getRecordedLogs();
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

    function _depositMarketBond(address _account, uint64 _amount) internal {
        bondToken.mint(_account, uint256(_amount) * 1 gwei);
        vm.startPrank(_account);
        bondToken.approve(address(market), type(uint256).max);
        market.depositBond(_amount);
        vm.stopPrank();
    }

    function _bondBalance(address _account) internal view returns (uint64) {
        (uint64 bal,) = market.proverAccounts(_account);
        return bal;
    }

    function _reservedBond(address _account) internal view returns (uint64) {
        (, uint64 res) = market.proverAccounts(_account);
        return res;
    }

    function _feeCredit(address _account) internal view returns (uint256) {
        return market.feeCredits(_account);
    }

    function _claimableFees(address _account) internal view returns (uint256) {
        return market.claimableFees(_account);
    }

    function _liabilityForFee(uint64 _feeInGwei) internal pure returns (uint64 liability_) {
        uint256 liability = uint256(_feeInGwei) * 2;
        if (liability < MARKET_BOND_PER_PROPOSAL) liability = MARKET_BOND_PER_PROPOSAL;
        if (liability < MARKET_SLASH_PER_PROOF) liability = MARKET_SLASH_PER_PROOF;
        if (liability > type(uint64).max) liability = type(uint64).max;
        liability_ = uint64(liability);
    }

    function _bondForOneAssignment(uint64 _feeInGwei) internal pure returns (uint64 bond_) {
        bond_ = MARKET_MIN_BOND_GWEI + _liabilityForFee(_feeInGwei);
    }

    function _bondForAssignments(uint64 _feeInGwei, uint64 _assignmentCount) internal pure returns (uint64 bond_) {
        bond_ = MARKET_MIN_BOND_GWEI + _liabilityForFee(_feeInGwei) * _assignmentCount;
    }

    function _placePendingBid(address _prover, uint64 _feeInGwei, uint64 _bondAmount) internal {
        _depositMarketBond(_prover, _bondAmount);
        vm.prank(_prover);
        market.bid(_feeInGwei);
    }

    function _setupActiveBidWithValue(address _prover, uint64 _feeInGwei, uint256 _proposalValue)
        internal
        returns (uint48 termId_)
    {
        _placePendingBid(_prover, _feeInGwei, _bondForOneAssignment(_feeInGwei));
        (, uint48 pendingTermId,,,,,) = market.marketState();
        termId_ = pendingTermId;
        _advanceBlock();
        _proposeOneWithValue(_proposalValue);
    }

    function _setupActiveBid(address _prover, uint64 _feeInGwei) internal returns (uint48 termId_) {
        termId_ = _setupActiveBidWithValue(_prover, _feeInGwei, uint256(_feeInGwei) * 1 gwei);
    }

    function _proposeAndDecodeWithGas(IInbox.ProposeInput memory _input, string memory _benchName)
        internal
        override
        returns (ProposedEvent memory payload_)
    {
        bytes memory encodedInput = codec.encodeProposeInput(_input);
        vm.recordLogs();
        vm.startPrank(proposer);

        if (bytes(_benchName).length > 0) vm.startSnapshotGas("shasta-propose", _benchName);
        inbox.propose{value: 1 ether}(bytes(""), encodedInput);
        if (bytes(_benchName).length > 0) vm.stopSnapshotGas();

        vm.stopPrank();
        payload_ = _readProposedEvent();
    }

    function _proposeOneWithValue(uint256 _value) internal returns (ProposedEvent memory payload_) {
        _setBlobHashes(3);
        bytes memory encodedInput = codec.encodeProposeInput(_defaultProposeInput());
        vm.recordLogs();
        vm.prank(proposer);
        inbox.propose{value: _value}(bytes(""), encodedInput);
        payload_ = _readProposedEvent();
    }

    function _proposeRecordedOneWithValue(uint256 _value) internal returns (RecordedProposal memory proposal_) {
        proposal_.payload = _proposeOneWithValue(_value);
        proposal_.timestamp = uint48(block.timestamp);
    }

    function _buildRecordedProofInput(RecordedProposal[] memory _proposals, address _actualProver)
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

    function _proveRecordedRangeAs(RecordedProposal[] memory _proposals, address _caller, address _actualProver)
        internal
    {
        IInbox.ProveInput memory input = _buildRecordedProofInput(_proposals, _actualProver);
        bytes memory encodedInput = codec.encodeProveInput(input);
        vm.prank(_caller);
        inbox.prove(encodedInput, bytes("proof"));
    }
}

contract ProverMarketBondAndCreditTest is ProverMarketTestBase {
    function test_depositBond_creditsBalance() external {
        _depositMarketBond(Alice, 5_000_000_000);
        assertEq(_bondBalance(Alice), 5_000_000_000);
    }

    function test_withdrawBond_RevertWhen_BondReserved() external {
        _setupActiveBid(Alice, 100);

        vm.prank(Alice);
        vm.expectRevert(ProverMarket.InsufficientBond.selector);
        market.withdrawBond(1);
    }

    function test_depositFeeCredit_creditsBalance() external {
        vm.deal(Alice, 2 ether);
        vm.prank(Alice);
        market.depositFeeCredit{value: 2 ether}();
        assertEq(_feeCredit(Alice), 2 ether);
    }

    function test_withdrawFeeCredit_withdrawsEth() external {
        uint256 amount = 0.4 ether;

        vm.deal(Alice, 1 ether);
        vm.prank(Alice);
        market.depositFeeCredit{value: 1 ether}();

        uint256 balanceBefore = Alice.balance;
        vm.prank(Alice);
        market.withdrawFeeCredit(amount);

        assertEq(_feeCredit(Alice), 1 ether - amount);
        assertEq(Alice.balance - balanceBefore, amount);
    }

    function test_withdrawClaimableFees_withdrawsEth() external {
        RecordedProposal[] memory proposals = new RecordedProposal[](1);
        _placePendingBid(Alice, 100, _bondForOneAssignment(100));
        _advanceBlock();
        proposals[0] = _proposeRecordedOneWithValue(uint256(100) * 1 gwei);

        _proveRecordedRangeAs(proposals, Alice, Alice);

        uint256 feeWei = uint256(100) * 1 gwei;
        uint256 balanceBefore = Alice.balance;
        vm.prank(Alice);
        market.withdrawClaimableFees(feeWei);

        assertEq(_claimableFees(Alice), 0);
        assertEq(Alice.balance - balanceBefore, feeWei);
    }
}

contract ProverMarketBidAndAssignmentTest is ProverMarketTestBase {
    function test_bid_RevertWhen_ZeroFee() external {
        _depositMarketBond(Alice, MARKET_MIN_BOND_GWEI);
        vm.prank(Alice);
        vm.expectRevert(EssentialContract.ZERO_VALUE.selector);
        market.bid(0);
    }

    function test_bid_RevertWhen_ActiveProverBidsAgain() external {
        _setupActiveBid(Alice, 100);

        vm.prank(Alice);
        vm.expectRevert(ProverMarket.ActiveProverCannotBid.selector);
        market.bid(90);
    }

    function test_bid_pendingProverCanOnlyImproveQuote() external {
        _depositMarketBond(Alice, MARKET_MIN_BOND_GWEI);

        vm.prank(Alice);
        market.bid(100);

        (, uint48 pendingTermId,,,,,) = market.marketState();

        vm.prank(Alice);
        market.bid(90);
        (,,, uint64 fee,,,) = market.terms(pendingTermId);
        assertEq(fee, 90);

        vm.prank(Alice);
        vm.expectRevert(ProverMarket.BidFeeTooHigh.selector);
        market.bid(95);
    }

    function test_bid_replacingPendingReleasesOldQuoteBond() external {
        _depositMarketBond(Alice, MARKET_MIN_BOND_GWEI);
        vm.prank(Alice);
        market.bid(100);
        assertEq(_reservedBond(Alice), MARKET_MIN_BOND_GWEI);

        _depositMarketBond(Bob, MARKET_MIN_BOND_GWEI);
        vm.prank(Bob);
        market.bid(90);

        assertEq(_reservedBond(Alice), 0);
        assertEq(_reservedBond(Bob), MARKET_MIN_BOND_GWEI);
    }

    function test_onProposalAccepted_assignsFundedProposalAndDebitsCredit() external {
        _placePendingBid(Alice, 100, _bondForOneAssignment(100));

        _advanceBlock();
        ProposedEvent memory proposal_ = _proposeOneWithValue(uint256(100) * 1 gwei);

        (uint48 termId, uint48 timestamp, uint64 reservedBondGwei) = market.proposalAssignments(proposal_.id);

        assertGt(termId, 0);
        assertEq(timestamp, uint48(block.timestamp));
        assertEq(reservedBondGwei, _liabilityForFee(100));
        assertEq(_feeCredit(proposer), 0);
        assertEq(_claimableFees(Alice), 0);
        assertEq(_reservedBond(Alice), MARKET_MIN_BOND_GWEI + _liabilityForFee(100));
    }

    function test_onProposalAccepted_underfundedProposalIsPermissionless() external {
        _placePendingBid(Alice, 100, _bondForOneAssignment(100));

        _advanceBlock();
        ProposedEvent memory proposal_ = _proposeOneWithValue(0);

        (uint48 termId,,) = market.proposalAssignments(proposal_.id);
        (uint48 activeTermId,,,,,,) = market.marketState();

        assertEq(termId, 0);
        assertGt(activeTermId, 0);
        assertEq(_feeCredit(proposer), 0);
        assertEq(_reservedBond(Alice), MARKET_MIN_BOND_GWEI);
    }

    function test_onProposalAccepted_doesNotPayRejectingProver() external {
        RejectEtherBidder bidder = new RejectEtherBidder(market, IERC20(address(bondToken)));
        uint64 bondAmount = _bondForOneAssignment(100);
        bondToken.mint(address(bidder), uint256(bondAmount) * 1 gwei);
        bidder.depositAndBid(bondAmount, 100);

        _advanceBlock();
        ProposedEvent memory proposal_ = _proposeOneWithValue(uint256(100) * 1 gwei);

        (uint48 termId,,) = market.proposalAssignments(proposal_.id);
        assertGt(termId, 0);
        assertEq(address(bidder).balance, 0);
        assertEq(_claimableFees(address(bidder)), 0);
    }
}

contract ProverMarketProofAuthTest is ProverMarketTestBase {
    function test_canSubmitProof_allowsAssignedProverWithinWindow() external {
        _placePendingBid(Alice, 100, _bondForOneAssignment(100));
        _advanceBlock();
        ProposedEvent memory proposal_ = _proposeOneWithValue(uint256(100) * 1 gwei);

        assertTrue(market.canSubmitProof(Alice, proposal_.id, proposal_.id));
        assertFalse(market.canSubmitProof(Bob, proposal_.id, proposal_.id));
    }

    function test_canSubmitProof_allowsAnyoneAfterDelay() external {
        _placePendingBid(Alice, 100, _bondForOneAssignment(100));
        _advanceBlock();
        ProposedEvent memory proposal_ = _proposeOneWithValue(uint256(100) * 1 gwei);

        vm.warp(block.timestamp + MARKET_PROVING_WINDOW);

        assertTrue(market.canSubmitProof(Bob, proposal_.id, proposal_.id));
    }

    function test_canSubmitProof_RevertWhen_LaterTermStillExclusive() external {
        RecordedProposal[] memory proposals = new RecordedProposal[](2);

        _placePendingBid(Alice, 100, _bondForOneAssignment(100));
        _advanceBlock();
        proposals[0] = _proposeRecordedOneWithValue(uint256(100) * 1 gwei);

        _placePendingBid(Bob, 90, _bondForOneAssignment(90));
        _advanceBlock();
        proposals[1] = _proposeRecordedOneWithValue(uint256(90) * 1 gwei);

        assertFalse(market.canSubmitProof(Alice, proposals[0].payload.id, proposals[1].payload.id));
        assertFalse(market.canSubmitProof(Bob, proposals[0].payload.id, proposals[1].payload.id));

        vm.warp(proposals[0].timestamp + MARKET_PROVING_WINDOW);
        assertTrue(market.canSubmitProof(Bob, proposals[0].payload.id, proposals[1].payload.id));
    }

    function test_canSubmitProof_allowsAnyoneInForcedPermissionlessMode() external {
        _placePendingBid(Alice, 100, _bondForOneAssignment(100));
        _advanceBlock();
        ProposedEvent memory proposal_ = _proposeOneWithValue(uint256(100) * 1 gwei);

        market.forcePermissionlessMode(true);
        assertTrue(market.canSubmitProof(Bob, proposal_.id, proposal_.id));
    }
}

contract ProverMarketSettlementTest is ProverMarketTestBase {
    function test_onProofAccepted_onTimeProofCreditsAssignedProverAndReleasesLiability() external {
        RecordedProposal[] memory proposals = new RecordedProposal[](1);

        _placePendingBid(Alice, 100, _bondForOneAssignment(100));
        _advanceBlock();
        proposals[0] = _proposeRecordedOneWithValue(uint256(100) * 1 gwei);

        _proveRecordedRangeAs(proposals, Alice, Alice);

        assertEq(_claimableFees(Alice), uint256(100) * 1 gwei);
        assertEq(_reservedBond(Alice), MARKET_MIN_BOND_GWEI);
    }

    function test_onProofAccepted_lateRescueProofCreditsRescuerAndSlashesAssignedProver() external {
        RecordedProposal[] memory proposals = new RecordedProposal[](1);

        _placePendingBid(Alice, 100, _bondForOneAssignment(100));
        _advanceBlock();
        proposals[0] = _proposeRecordedOneWithValue(uint256(100) * 1 gwei);

        vm.warp(block.timestamp + MARKET_PROVING_WINDOW + MARKET_PROVING_GRACE);
        _proveRecordedRangeAs(proposals, Bob, Bob);

        assertEq(_claimableFees(Bob), uint256(100) * 1 gwei);
        assertEq(_bondBalance(Bob), _liabilityForFee(100));
        assertEq(_bondBalance(Alice), MARKET_MIN_BOND_GWEI);
        assertEq(_reservedBond(Alice), 0);
        (uint48 activeTermId,,,,,,) = market.marketState();
        assertEq(activeTermId, 0);
    }

    function test_onProofAccepted_forcePermissionlessStillSettlesAssignments() external {
        RecordedProposal[] memory proposals = new RecordedProposal[](1);

        _placePendingBid(Alice, 100, _bondForOneAssignment(100));
        _advanceBlock();
        proposals[0] = _proposeRecordedOneWithValue(uint256(100) * 1 gwei);

        market.forcePermissionlessMode(true);
        _proveRecordedRangeAs(proposals, Bob, Bob);

        assertEq(_claimableFees(Bob), uint256(100) * 1 gwei);
        assertEq(_bondBalance(Alice), _bondForOneAssignment(100));
        assertEq(_reservedBond(Alice), MARKET_MIN_BOND_GWEI);
    }

    function test_onProofAccepted_batchLateSettlementSlashesMultipleTerms() external {
        RecordedProposal[] memory proposals = new RecordedProposal[](2);

        _placePendingBid(Alice, 100, _bondForOneAssignment(100));
        _advanceBlock();
        proposals[0] = _proposeRecordedOneWithValue(uint256(100) * 1 gwei);

        _placePendingBid(Bob, 90, _bondForOneAssignment(90));
        _advanceBlock();
        proposals[1] = _proposeRecordedOneWithValue(uint256(90) * 1 gwei);

        vm.warp(proposals[1].timestamp + MARKET_PROVING_WINDOW + MARKET_PROVING_GRACE);
        _proveRecordedRangeAs(proposals, Carol, Carol);

        assertEq(_claimableFees(Carol), uint256(190) * 1 gwei);
        assertEq(_bondBalance(Carol), _liabilityForFee(100) + _liabilityForFee(90));
        assertEq(_reservedBond(Alice), 0);
        assertEq(_reservedBond(Bob), 0);
    }

    function test_onProofAccepted_retiresActiveTermWhenLateSlashLeavesOutstandingLiability() external {
        RecordedProposal[] memory firstProposalOnly = new RecordedProposal[](1);

        _placePendingBid(Alice, 100, _bondForAssignments(100, 2));
        _advanceBlock();
        firstProposalOnly[0] = _proposeRecordedOneWithValue(uint256(100) * 1 gwei);

        _advanceBlock();
        _proposeOneWithValue(uint256(100) * 1 gwei);

        vm.warp(firstProposalOnly[0].timestamp + MARKET_PROVING_WINDOW + MARKET_PROVING_GRACE);
        _proveRecordedRangeAs(firstProposalOnly, Bob, Bob);

        (uint48 activeTermId,,,,,,) = market.marketState();
        assertEq(activeTermId, 0);
        assertEq(_reservedBond(Alice), _liabilityForFee(100));
    }
}

contract ProverMarketHardeningTest is ProverMarketTestBase {
    function test_bid_RevertWhen_FeeExceedsMaxFee() external {
        _depositMarketBond(Alice, MARKET_MIN_BOND_GWEI);
        vm.prank(Alice);
        vm.expectRevert(ProverMarket.BidFeeTooHigh.selector);
        market.bid(10_000_000_001);
    }

    function test_bid_RevertWhen_CooldownActive() external {
        _placePendingBid(Alice, 100, _bondForOneAssignment(100));
        _advanceBlock();
        _proposeOneWithValue(uint256(100) * 1 gwei);

        _placePendingBid(Bob, 90, _bondForOneAssignment(90));
        _advanceBlock();
        _proposeOneWithValue(uint256(90) * 1 gwei);

        uint48 cooldownEnd = market.bidCooldownUntil(Alice);
        assertTrue(cooldownEnd > 0);

        _depositMarketBond(Alice, MARKET_MIN_BOND_GWEI);
        vm.prank(Alice);
        vm.expectRevert(ProverMarket.BidCooldownActive.selector);
        market.bid(80);
    }

    function test_bid_succeedsAfterCooldownExpires() external {
        _placePendingBid(Alice, 100, _bondForOneAssignment(100));
        _advanceBlock();
        _proposeOneWithValue(uint256(100) * 1 gwei);

        _placePendingBid(Bob, 90, _bondForOneAssignment(90));
        _advanceBlock();
        _proposeOneWithValue(uint256(90) * 1 gwei);

        uint48 cooldownEnd = market.bidCooldownUntil(Alice);
        vm.warp(cooldownEnd);

        _depositMarketBond(Alice, MARKET_MIN_BOND_GWEI);
        vm.prank(Alice);
        market.bid(80);
    }

    function test_onProofAccepted_withinGracePeriodDoesNotSlash() external {
        RecordedProposal[] memory proposals = new RecordedProposal[](1);

        _placePendingBid(Alice, 100, _bondForOneAssignment(100));
        _advanceBlock();
        proposals[0] = _proposeRecordedOneWithValue(uint256(100) * 1 gwei);

        uint64 bondBefore = _bondBalance(Alice);
        vm.warp(block.timestamp + MARKET_PROVING_WINDOW + 1);
        _proveRecordedRangeAs(proposals, Bob, Bob);

        assertEq(_bondBalance(Alice), bondBefore);
        assertEq(_claimableFees(Bob), uint256(100) * 1 gwei);
    }
}

contract ProverMarketE2ETest is ProverMarketTestBase {
    function test_forcePermissionlessMode_toggles() external {
        market.forcePermissionlessMode(true);
        (,,, uint8 reason,,,) = market.marketState();
        assertEq(reason, 1);

        market.forcePermissionlessMode(false);
        (,,, reason,,,) = market.marketState();
        assertEq(reason, 0);
    }

    function test_forcePermissionlessMode_RevertWhen_NotOwner() external {
        vm.prank(Alice);
        vm.expectRevert();
        market.forcePermissionlessMode(true);
    }

    function test_fullLifecycle_bidProposeProveWithdraw() external {
        RecordedProposal[] memory proposals = new RecordedProposal[](1);
        uint256 feeWei = uint256(100) * 1 gwei;

        _placePendingBid(Alice, 100, _bondForOneAssignment(100));
        _advanceBlock();
        proposals[0] = _proposeRecordedOneWithValue(feeWei + 0.25 ether);

        assertEq(_feeCredit(proposer), 0.25 ether);

        _proveRecordedRangeAs(proposals, Alice, Alice);
        assertEq(_claimableFees(Alice), feeWei);

        uint256 proposerBalanceBefore = proposer.balance;
        vm.prank(proposer);
        market.withdrawFeeCredit(0.25 ether);
        assertEq(proposer.balance - proposerBalanceBefore, 0.25 ether);

        uint256 proverBalanceBefore = Alice.balance;
        vm.prank(Alice);
        market.withdrawClaimableFees(feeWei);
        assertEq(Alice.balance - proverBalanceBefore, feeWei);
    }
}
