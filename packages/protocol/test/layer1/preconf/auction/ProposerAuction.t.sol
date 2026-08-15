// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import { IInbox } from "src/layer1/core/iface/IInbox.sol";
import { IProposerChecker } from "src/layer1/core/iface/IProposerChecker.sol";
import { LibHashOptimized } from "src/layer1/core/libs/LibHashOptimized.sol";
import { IProposerAuction } from "src/layer1/preconf/iface/IProposerAuction.sol";
import { ProposerAuction } from "src/layer1/preconf/impl/ProposerAuction.sol";
import { MockInbox } from "test/layer1/preconf/mocks/MockInbox.sol";
import { TestERC20 } from "test/mocks/TestERC20.sol";
import { CommonTest } from "test/shared/CommonTest.sol";

/// @title TestProposerAuction
/// @dev Tests the perpetual standing-bid preconfer auction:
///      bidding/renewal/quit, epoch-quantized assignments with lazy per-epoch ETH charging,
///      the fallback ladder with gap-disprovable stall slashing, S1 signed-block slashing,
///      bonds, ETH, and proceeds.
contract TestProposerAuction is CommonTest {
    uint256 internal constant SLOT = 12;
    uint256 internal constant EPOCH = SLOT * 32;

    uint96 internal constant LIVENESS_BOND = 100; // gwei
    uint16 internal constant BOND_MULTIPLIER = 2;
    uint16 internal constant REWARD_BPS = 5000; // 50%
    uint16 internal constant SETTLE_BOUNTY_BPS = 500; // 5%
    uint48 internal constant BOND_WITHDRAWAL_DELAY = 1 days;
    uint32 internal constant TENURE_MAX_EPOCHS = 10;
    uint128 internal constant INITIAL_FLOOR = 10; // gwei
    uint8 internal constant AVG_MULTIPLIER = 1;
    uint48 internal constant AVG_WINDOW = uint48(4 * EPOCH);
    uint48 internal constant STALL_GRACE = uint48(4 * SLOT);
    uint48 internal constant ESCROW_GRACE = uint48(2 * STALL_GRACE);
    uint48 internal constant BACKUP_GRACE = uint48(4 * SLOT);
    uint48 internal constant FALLBACK_GRACE = uint48(8 * SLOT);
    uint48 internal constant REFUTE_WINDOW = uint48(EPOCH);
    uint48 internal constant HANDOVER_MARGIN = uint48(8 * SLOT);
    uint16 internal constant FLOOR_DECAY_BPS = 7000;

    uint256 internal constant ALICE_KEY = 0xA11CE;
    uint256 internal constant BOB_KEY = 0xB0B;
    uint256 internal constant CAROL_KEY = 0xC0C;

    bytes32 internal constant BLOCK_TYPEHASH = keccak256(
        "SignedBlockData(uint32 epoch,uint64 seqNo,uint64 blockNumber,bytes32 parentHash,uint48 timestamp,address coinbase,uint48 gasLimit,bytes32 txRoot)"
    );
    bytes32 internal constant DOMAIN_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );

    ProposerAuction internal auction;
    MockInbox internal inbox;
    TestERC20 internal bondToken;

    function setUpOnEthereum() internal virtual override {
        bondToken = new TestERC20("Test TAIKO", "TTKO");
        inbox = new MockInbox();
        auction = ProposerAuction(
            deploy({
                name: "proposer_auction",
                impl: address(new ProposerAuction(_defaultConfig())),
                data: abi.encodeCall(ProposerAuction.init, (Alice))
            })
        );
    }

    function _defaultConfig() internal view returns (IProposerAuction.Config memory) {
        return IProposerAuction.Config({
            inbox: address(inbox),
            bondToken: address(bondToken),
            livenessBondAmount: LIVENESS_BOND,
            bondMultiplier: BOND_MULTIPLIER,
            rewardBps: REWARD_BPS,
            settleBountyBps: SETTLE_BOUNTY_BPS,
            bondWithdrawalDelay: BOND_WITHDRAWAL_DELAY,
            tenureMaxEpochs: TENURE_MAX_EPOCHS,
            initialFloorInGwei: INITIAL_FLOOR,
            movingAverageMultiplier: AVG_MULTIPLIER,
            movingAverageWindow: AVG_WINDOW,
            stallGrace: STALL_GRACE,
            escrowGrace: ESCROW_GRACE,
            backupGrace: BACKUP_GRACE,
            fallbackGrace: FALLBACK_GRACE,
            refuteWindow: REFUTE_WINDOW,
            handoverMargin: HANDOVER_MARGIN,
            floorDecayBps: FLOOR_DECAY_BPS
        });
    }

    // ---------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------

    function epochStart(uint256 _epoch) internal pure returns (uint256) {
        return _epoch * EPOCH;
    }

    function warpToEpoch(uint256 _epoch) internal {
        vm.warp(epochStart(_epoch));
    }

    function currentEpoch() internal view returns (uint256) {
        return block.timestamp / EPOCH;
    }

    function requiredBond() internal view returns (uint128) {
        return auction.getRequiredBond();
    }

    function ejectionThreshold() internal view returns (uint128) {
        return auction.getEjectionThreshold();
    }

    function _depositBond(address _who, uint128 _amountGwei) internal {
        bondToken.mint(_who, uint256(_amountGwei) * 1 gwei);
        vm.prank(_who);
        bondToken.approve(address(auction), type(uint256).max);
        vm.prank(_who);
        auction.depositBond(_amountGwei);
    }

    function _depositEth(address _who, uint256 _amountWei) internal {
        vm.deal(_who, _amountWei);
        vm.prank(_who);
        auction.depositEth{ value: _amountWei }();
    }

    function _bidder(address _who, uint128 _amountGwei, address _signer) internal {
        _depositBond(_who, requiredBond());
        vm.prank(_who);
        auction.bid(_amountGwei, _signer);
    }

    /// @dev Places a bid and funds one epoch of fee payment.
    function _setupWinner(address _who, uint128 _amountGwei, address _signer) internal {
        _bidder(_who, _amountGwei, _signer);
        _depositEth(_who, uint256(_amountGwei) * 1 gwei);
    }

    function _checkProposer(address _proposer) internal returns (uint48 windowEnd_) {
        vm.prank(address(inbox));
        windowEnd_ = auction.checkProposer(_proposer, "");
    }

    function _makeProposal(
        uint48 _id,
        address _proposer,
        uint48 _timestamp
    )
        internal
        pure
        returns (IInbox.Proposal memory)
    {
        return IInbox.Proposal({
            id: _id,
            timestamp: _timestamp,
            endOfSubmissionWindowTimestamp: 0,
            proposer: _proposer,
            parentProposalHash: bytes32(uint256(_id)),
            originBlockNumber: 1,
            originBlockHash: bytes32(0),
            basefeeSharingPctg: 0,
            sources: new IInbox.DerivationSource[](0)
        });
    }

    function _storeProposalHash(uint48 _id, IInbox.Proposal memory _proposal) internal {
        inbox.setProposalHash(_id, LibHashOptimized.hashProposal(_proposal));
    }

    function _domainSeparator() internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                DOMAIN_TYPEHASH,
                keccak256("TAIKO_PRECONF_BLOCK"),
                keccak256("1"),
                block.chainid,
                address(auction)
            )
        );
    }

    function _structHash(IProposerAuction.SignedBlock memory _block)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                BLOCK_TYPEHASH,
                _block.epoch,
                _block.seqNo,
                _block.blockNumber,
                _block.parentHash,
                _block.timestamp,
                _block.coinbase,
                _block.gasLimit,
                _block.txRoot
            )
        );
    }

    function _signedBlock(
        uint256 _key,
        uint32 _epoch,
        uint64 _seqNo,
        uint64 _blockNumber,
        bytes32 _parentHash,
        uint48 _timestamp,
        bytes32 _txRoot
    )
        internal
        view
        returns (IProposerAuction.SignedBlock memory)
    {
        IProposerAuction.SignedBlock memory b = IProposerAuction.SignedBlock({
            epoch: _epoch,
            seqNo: _seqNo,
            blockNumber: _blockNumber,
            parentHash: _parentHash,
            timestamp: _timestamp,
            coinbase: vm.addr(_key),
            gasLimit: 30_000_000,
            txRoot: _txRoot,
            v: 0,
            r: bytes32(0),
            s: bytes32(0)
        });
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", _domainSeparator(), _structHash(b)));
        (b.v, b.r, b.s) = vm.sign(_key, digest);
        return b;
    }

    /// @dev Deploys a winner (Alice, bid 1000 gwei, funded) and a backup (Bob) that serve
    ///      epoch E: both bids are placed in epoch E-2 and take effect from E.
    function _setupServingWinner(uint256 _epoch) internal {
        warpToEpoch(_epoch - 2);
        _setupWinner(Alice, 1000, vm.addr(ALICE_KEY));
        _bidder(Bob, 1000, vm.addr(BOB_KEY));
        _depositEth(Bob, 1000 * 1 gwei);
        warpToEpoch(_epoch);
    }

    // ---------------------------------------------------------------
    // bid()
    // ---------------------------------------------------------------

    function test_bid_setsEffectiveEpochAndExpiry() public {
        warpToEpoch(1000);
        _setupWinner(Alice, 1000, vm.addr(ALICE_KEY));

        (IProposerAuction.BidInfo memory info, address signer) = auction.getBidderInfo(Alice);
        assertEq(info.amountInGwei, 1000);
        assertEq(info.placedEpoch, 1000);
        assertEq(info.effectiveEpoch, 1002);
        assertEq(info.expiresAtEpoch, 1002 + TENURE_MAX_EPOCHS);
        assertEq(info.withdrawEffectiveEpoch, 0);
        assertEq(signer, vm.addr(ALICE_KEY));
        assertEq(auction.getBidderCount(), 1);
        assertEq(auction.getBidderAt(0), Alice);
    }

    function test_bid_RevertWhen_belowReserveFloor() public {
        warpToEpoch(1000);
        _depositBond(Alice, requiredBond());
        vm.prank(Alice);
        vm.expectRevert(ProposerAuction.BidBelowReserve.selector);
        auction.bid(INITIAL_FLOOR - 1, vm.addr(ALICE_KEY));
    }

    function test_bid_RevertWhen_insufficientBond() public {
        warpToEpoch(1000);
        _depositBond(Alice, requiredBond() - 1);
        vm.prank(Alice);
        vm.expectRevert(ProposerAuction.InsufficientBond.selector);
        auction.bid(1000, vm.addr(ALICE_KEY));
    }

    function test_bid_RevertWhen_zeroSigner() public {
        warpToEpoch(1000);
        _depositBond(Alice, requiredBond());
        vm.prank(Alice);
        vm.expectRevert(ProposerAuction.InvalidSigner.selector);
        auction.bid(1000, address(0));
    }

    function test_bid_RevertWhen_incrementTooSmall() public {
        // Alice's bid becomes the active top once it takes effect (epoch 1002).
        warpToEpoch(1000);
        _setupWinner(Alice, 1000, vm.addr(ALICE_KEY));
        warpToEpoch(1002);

        _depositBond(Bob, requiredBond());
        vm.prank(Bob);
        vm.expectRevert(ProposerAuction.IncrementTooSmall.selector);
        auction.bid(1049, vm.addr(BOB_KEY));

        vm.prank(Bob);
        auction.bid(1050, vm.addr(BOB_KEY));
    }

    function test_bid_equalBidRanksBelowExistingTop() public {
        warpToEpoch(1000);
        _setupWinner(Alice, 1000, vm.addr(ALICE_KEY));
        warpToEpoch(1002);

        _bidder(Bob, 1000, vm.addr(BOB_KEY));
        (address provisional, bool isFinal) = auction.getProvisionalWinner();
        assertEq(provisional, Alice, "earlier bid wins ties");
        assertTrue(isFinal);
    }

    function test_bid_updatesOwnBidAsPendingChange() public {
        warpToEpoch(1000);
        _setupWinner(Alice, 1000, vm.addr(ALICE_KEY));

        vm.prank(Alice);
        auction.bid(1200, vm.addr(BOB_KEY));

        // Live entry untouched until the pending change materializes.
        (IProposerAuction.BidInfo memory info, address signer) = auction.getBidderInfo(Alice);
        assertEq(info.amountInGwei, 1000);
        assertEq(signer, vm.addr(ALICE_KEY));
        IProposerAuction.PendingUpdate memory pending = auction.getPendingUpdate(Alice);
        assertEq(pending.amountInGwei, 1200);
        assertEq(pending.signer, vm.addr(BOB_KEY));
        assertEq(pending.effectiveEpoch, 1002);

        _depositEth(Alice, 2000 * 1 gwei); // cover the new 1200 rate
        vm.warp(epochStart(1002));
        auction.snapshot();
        (info, signer) = auction.getBidderInfo(Alice);
        assertEq(info.amountInGwei, 1200);
        assertEq(signer, vm.addr(BOB_KEY));
        assertEq(auction.getPendingUpdate(Alice).effectiveEpoch, 0, "pending consumed");
    }

    function test_bid_evictsLowestWhenFull() public {
        warpToEpoch(1000);
        for (uint256 i; i < 16; ++i) {
            address bidder = makeAddr(string.concat("bidder", vm.toString(i)));
            _bidder(bidder, 100, bidder);
        }
        assertEq(auction.getBidderCount(), 16);

        address extra = makeAddr("extra");
        _depositBond(extra, requiredBond());
        vm.prank(extra);
        auction.bid(200, extra); // Q14: evicts the lowest (100) since 200 >= 100 * 1.05
        assertEq(auction.getBidderCount(), 16, "lowest evicted, new entrant added");
    }

    function test_bid_RevertWhen_fullListAndBelowEvictionIncrement() public {
        warpToEpoch(1000);
        for (uint256 i; i < 16; ++i) {
            address bidder = makeAddr(string.concat("bidder", vm.toString(i)));
            _bidder(bidder, 100, bidder);
        }

        address extra = makeAddr("extra");
        _depositBond(extra, requiredBond());
        vm.prank(extra);
        vm.expectRevert(ProposerAuction.IncrementTooSmall.selector);
        auction.bid(104, extra); // below 100 * 1.05
    }

    // ---------------------------------------------------------------
    // renew() / quit()
    // ---------------------------------------------------------------

    function test_renew_extendsExpiryAsPendingChange() public {
        warpToEpoch(1000);
        _setupWinner(Alice, 1000, vm.addr(ALICE_KEY));
        _depositEth(Alice, 100_000 * 1 gwei); // cover catch-up charges
        uint32 initialExpiry = 1002 + TENURE_MAX_EPOCHS;

        vm.warp(epochStart(1005));
        vm.prank(Alice);
        auction.renew();

        // Pending until it takes effect: live fields untouched, expiry-only pending recorded.
        (IProposerAuction.BidInfo memory info,) = auction.getBidderInfo(Alice);
        assertEq(info.expiresAtEpoch, initialExpiry, "live expiry untouched");
        IProposerAuction.PendingUpdate memory pending = auction.getPendingUpdate(Alice);
        assertEq(pending.effectiveEpoch, 1007);
        assertEq(pending.expiresAtEpoch, 1007 + TENURE_MAX_EPOCHS);
        assertEq(pending.amountInGwei, 0, "expiry-only renewal");

        vm.warp(epochStart(1007));
        auction.snapshot();
        (info,) = auction.getBidderInfo(Alice);
        assertEq(info.expiresAtEpoch, 1007 + TENURE_MAX_EPOCHS);
        assertGt(info.expiresAtEpoch, initialExpiry);
    }

    function test_renew_RevertWhen_notListed() public {
        warpToEpoch(1000);
        vm.prank(Alice);
        vm.expectRevert(ProposerAuction.NotListed.selector);
        auction.renew();
    }

    function test_renew_RevertWhen_alreadyQuitting() public {
        warpToEpoch(1000);
        _setupWinner(Alice, 1000, vm.addr(ALICE_KEY));
        vm.prank(Alice);
        auction.quit();

        vm.prank(Alice);
        vm.expectRevert(ProposerAuction.AlreadyQuitting.selector);
        auction.renew();
    }

    function test_quit_setsWithdrawEpochAndBondDelay() public {
        warpToEpoch(1000);
        _setupWinner(Alice, 1000, vm.addr(ALICE_KEY));

        uint48 quitAt = uint48(block.timestamp);
        vm.prank(Alice);
        auction.quit();

        (IProposerAuction.BidInfo memory info,) = auction.getBidderInfo(Alice);
        assertEq(info.withdrawEffectiveEpoch, 1000 + auction.TRANSITION_LEAD_EPOCHS());
        IProposerAuction.BondInfo memory bond = auction.getBondInfo(Alice);
        assertEq(bond.withdrawableAt, quitAt + BOND_WITHDRAWAL_DELAY);
    }

    function test_quit_RevertWhen_notListed() public {
        warpToEpoch(1000);
        vm.prank(Alice);
        vm.expectRevert(ProposerAuction.NotListed.selector);
        auction.quit();
    }

    function test_quit_thenBidAgainRevivesPending() public {
        warpToEpoch(1000);
        _setupWinner(Alice, 1000, vm.addr(ALICE_KEY));
        vm.prank(Alice);
        auction.quit();

        vm.prank(Alice);
        auction.bid(1000, vm.addr(ALICE_KEY));

        // The quit remains in effect for current/next epochs; the re-bid applies later.
        (IProposerAuction.BidInfo memory info,) = auction.getBidderInfo(Alice);
        assertEq(info.withdrawEffectiveEpoch, 1002, "quit still effective");
        assertEq(auction.getPendingUpdate(Alice).effectiveEpoch, 1002, "re-bid is pending");

        vm.warp(epochStart(1002));
        auction.snapshot();
        (info,) = auction.getBidderInfo(Alice);
        assertEq(info.withdrawEffectiveEpoch, 0, "re-bid revokes the quit when it materializes");
    }

    // ---------------------------------------------------------------
    // Assignment & epochs
    // ---------------------------------------------------------------

    function test_assignment_emptyListIsUnassigned() public {
        warpToEpoch(1000);
        IProposerAuction.Assignment memory current = auction.getAssignmentForCurrentEpoch();
        assertEq(current.winner, address(0));
        assertEq(current.backup, address(0));
        (address provisional,) = auction.getProvisionalWinner();
        assertEq(provisional, address(0));
    }

    function test_assignment_winnerTakesEffectTwoEpochsLater() public {
        warpToEpoch(1000);
        _setupWinner(Alice, 1000, vm.addr(ALICE_KEY));

        // During the placement epoch and the next one, nothing is final yet.
        IProposerAuction.Assignment memory current = auction.getAssignmentForCurrentEpoch();
        assertEq(current.winner, address(0));
        IProposerAuction.Assignment memory next = auction.getAssignmentForNextEpoch();
        assertEq(next.winner, address(0), "bid placed now cannot affect the next epoch");

        warpToEpoch(1001);
        next = auction.getAssignmentForNextEpoch();
        assertEq(next.winner, Alice, "next epoch is final during the current epoch");

        warpToEpoch(1002);
        current = auction.getAssignmentForCurrentEpoch();
        assertEq(current.winner, Alice);
        assertEq(current.backup, address(0));
    }

    function test_assignment_chargesWinnerPerEpochServed() public {
        warpToEpoch(1000);
        _setupWinner(Alice, 1000, vm.addr(ALICE_KEY));
        _depositEth(Alice, 3000 * 1 gwei);
        warpToEpoch(1002);

        _checkProposer(Alice);
        assertEq(auction.getProceeds(), 1000 * 1 gwei, "first epoch charged lazily");
        assertEq(auction.getEthBalance(Alice), 3000 * 1 gwei, "1 of 4 funded gwei charged");

        warpToEpoch(1003);
        _checkProposer(Alice);
        assertEq(auction.getProceeds(), 2000 * 1 gwei, "second epoch charged lazily");
        assertEq(auction.getEthBalance(Alice), 2000 * 1 gwei, "2 of 4 funded gwei charged");
    }

    function test_assignment_winnerWithoutEthIsLapsedAndBackupInherits() public {
        warpToEpoch(1000);
        // Alice (top) has no ETH balance; Bob (backup) is funded.
        _bidder(Alice, 1100, vm.addr(ALICE_KEY));
        _bidder(Bob, 1000, vm.addr(BOB_KEY));
        _depositEth(Bob, 1000 * 1 gwei);
        warpToEpoch(1002);

        vm.expectEmit(true, true, true, true);
        emit IProposerAuction.BidLapsed(Alice);
        _checkProposer(Bob);

        (IProposerAuction.BidInfo memory info,) = auction.getBidderInfo(Alice);
        assertEq(info.amountInGwei, 0, "unpayable winner is lapsed");
        IProposerAuction.Assignment memory current = auction.getAssignmentForCurrentEpoch();
        assertEq(current.winner, Bob, "backup inherits");
        assertEq(auction.getProceeds(), 1000 * 1 gwei);
    }

    function test_assignment_expiryLapsesWinner() public {
        warpToEpoch(1000);
        _setupWinner(Alice, 1000, vm.addr(ALICE_KEY));
        _depositEth(Alice, 3000 * 1 gwei);

        // Active until expiresAtEpoch - 1.
        warpToEpoch(1002 + TENURE_MAX_EPOCHS - 1);
        IProposerAuction.Assignment memory current = auction.getAssignmentForCurrentEpoch();
        assertEq(current.winner, Alice);

        // Lapsed at expiresAtEpoch.
        warpToEpoch(1002 + TENURE_MAX_EPOCHS);
        current = auction.getAssignmentForCurrentEpoch();
        assertEq(current.winner, address(0));
    }

    function test_assignment_renewKeepsWinnerPastOriginalExpiry() public {
        warpToEpoch(1000);
        _setupWinner(Alice, 1000, vm.addr(ALICE_KEY));
        _depositEth(Alice, 100_000 * 1 gwei); // cover catch-up charges

        vm.warp(epochStart(1005));
        vm.prank(Alice);
        auction.renew(); // pending, effective 1007

        vm.warp(epochStart(1007));
        auction.snapshot(); // materialize the renewal

        warpToEpoch(1002 + TENURE_MAX_EPOCHS);
        IProposerAuction.Assignment memory current = auction.getAssignmentForCurrentEpoch();
        assertEq(current.winner, Alice, "renewed bid stays active past the original expiry");
    }

    function test_assignment_quitEffectiveTwoEpochsLater() public {
        warpToEpoch(1000);
        _setupWinner(Alice, 1000, vm.addr(ALICE_KEY));
        _bidder(Bob, 1000, vm.addr(BOB_KEY));
        _depositEth(Bob, 1000 * 1 gwei);

        vm.warp(epochStart(1001));
        vm.prank(Alice);
        auction.quit();

        warpToEpoch(1002);
        IProposerAuction.Assignment memory current = auction.getAssignmentForCurrentEpoch();
        assertEq(current.winner, Alice, "quit is not effective yet");

        warpToEpoch(1003);
        current = auction.getAssignmentForCurrentEpoch();
        assertEq(current.winner, Bob, "quit takes effect two epochs later");
    }

    function test_getProvisionalWinner_finalityFlag() public {
        warpToEpoch(1000);
        _setupWinner(Alice, 1000, vm.addr(ALICE_KEY));

        (address winner, bool isFinal) = auction.getProvisionalWinner();
        assertEq(winner, Alice);
        assertFalse(isFinal, "bid effective in two epochs is not final");

        warpToEpoch(1001);
        (winner, isFinal) = auction.getProvisionalWinner();
        assertEq(winner, Alice);
        assertTrue(isFinal, "effective next epoch is final");
    }

    function test_purgeInactive_removesExpiredAndWithdrawn() public {
        warpToEpoch(1000);
        _setupWinner(Alice, 1000, vm.addr(ALICE_KEY));
        // Fund Alice through her whole tenure: the catch-up charges one fee per epoch served, so
        // an under-funded winner would be lapsed for non-payment before reaching their expiry.
        _depositEth(Alice, uint256(1000) * 1 gwei * TENURE_MAX_EPOCHS);
        _bidder(Bob, 1000, vm.addr(BOB_KEY));

        vm.warp(epochStart(1001));
        vm.prank(Bob);
        auction.quit(); // effective 1003

        warpToEpoch(1013); // past Alice's expiry (1012) and Bob's withdrawal (1003)
        uint256 removed = auction.purgeInactive();
        assertEq(removed, 2, "both the expired and the withdrawn bid are purged");
        assertEq(auction.getBidderCount(), 0);
    }

    function test_reserveFloor_usesMovingAverageOfChargedBids() public {
        warpToEpoch(1000);
        assertEq(auction.getReserveFloor(), INITIAL_FLOOR);

        _setupWinner(Alice, 1000, vm.addr(ALICE_KEY));
        _depositEth(Alice, 1000 * 1 gwei);
        warpToEpoch(1002);
        _checkProposer(Alice);

        assertEq(auction.getReserveFloor(), 1000, "EMA of charged bids sets the floor");

        _depositBond(Bob, requiredBond());
        vm.prank(Bob);
        vm.expectRevert(ProposerAuction.BidBelowReserve.selector);
        auction.bid(999, vm.addr(BOB_KEY));
    }

    // ---------------------------------------------------------------
    // checkProposer / fallback ladder
    // ---------------------------------------------------------------

    function test_checkProposer_RevertWhen_notInbox() public {
        warpToEpoch(1000);
        vm.expectRevert(ProposerAuction.NotInbox.selector);
        auction.checkProposer(Alice, "");
    }

    function test_checkProposer_winnerProposesAndReturnsWindowEnd() public {
        _setupServingWinner(1000);

        uint48 windowEnd = _checkProposer(Alice);
        assertEq(windowEnd, uint48(epochStart(1000) + EPOCH));
    }

    function test_checkProposer_RevertWhen_nonWinnerBeforeStall() public {
        _setupServingWinner(1000);
        vm.warp(epochStart(1000) + 10);
        _checkProposer(Alice);

        // Stall clock alive: nobody but the winner may propose.
        vm.warp(epochStart(1000) + 40);
        vm.prank(address(inbox));
        vm.expectRevert(IProposerChecker.InvalidProposer.selector);
        auction.checkProposer(Bob, "");
    }

    function test_checkProposer_backupProposesAfterStallGrace_noEscrowYet() public {
        _setupServingWinner(1000);
        vm.warp(epochStart(1000) + STALL_GRACE + 1);

        _checkProposer(Bob); // liveness fires immediately...

        IProposerAuction.StallEscrow memory escrow = auction.getPendingStallSlash(1000);
        assertEq(escrow.escrowedAt, 0, "no escrow before the escrow grace");
        assertEq(auction.getBondInfo(Alice).balance, requiredBond(), "bond untouched");
    }

    function test_checkProposer_escrowFiresOnlyAfterEscrowGrace() public {
        _setupServingWinner(1000);
        vm.warp(epochStart(1000) + ESCROW_GRACE + 1);

        vm.expectEmit(true, true, true, true);
        emit IProposerAuction.StallEscrowed(
            1000, Alice, LIVENESS_BOND, uint48(epochStart(1000)), Bob
        );
        _checkProposer(Bob);

        IProposerAuction.StallEscrow memory escrow = auction.getPendingStallSlash(1000);
        assertEq(escrow.winner, Alice);
        assertEq(escrow.amount, LIVENESS_BOND);
        assertEq(escrow.gapStart, uint48(epochStart(1000)));
        assertEq(escrow.challenger, Bob);
        assertTrue(escrow.challengerIsBackup, "the backup is the direct beneficiary");
        assertFalse(escrow.settled);
        assertEq(
            auction.getBondInfo(Alice).balance, requiredBond() - LIVENESS_BOND, "bond escrowed"
        );
    }

    function test_checkProposer_backupProposesAtFullCadenceDuringOutage() public {
        _setupServingWinner(1000);
        vm.warp(epochStart(1000) + STALL_GRACE + 1);
        _checkProposer(Bob);

        vm.warp(epochStart(1000) + STALL_GRACE + 13);
        _checkProposer(Bob); // backup proposals do not reset the winner-absence clock
        assertEq(auction.getPendingStallSlash(1000).escrowedAt, 0);
    }

    function test_checkProposer_winnerReclaimsExclusivityByProposingOnce() public {
        _setupServingWinner(1000);
        vm.warp(epochStart(1000) + ESCROW_GRACE + 1);
        _checkProposer(Bob); // ladder open, escrow fires

        vm.warp(epochStart(1000) + ESCROW_GRACE + 11);
        _checkProposer(Alice); // winner proposes once: exclusivity restored

        vm.warp(epochStart(1000) + ESCROW_GRACE + 21);
        vm.prank(address(inbox));
        vm.expectRevert(IProposerChecker.InvalidProposer.selector);
        auction.checkProposer(Bob, "");

        // Merely proposing again does not release the escrow.
        assertFalse(auction.getPendingStallSlash(1000).settled);
    }

    function test_checkProposer_anyBondedOperatorAfterBackupGrace() public {
        _setupServingWinner(1000);
        _depositBond(Carol, ejectionThreshold());
        vm.warp(epochStart(1000) + STALL_GRACE + BACKUP_GRACE + 1);

        _checkProposer(Carol);
        IProposerAuction.StallEscrow memory escrow = auction.getPendingStallSlash(1000);
        assertEq(escrow.challenger, Carol);
    }

    function test_checkProposer_anyoneAfterFallbackGrace() public {
        _setupServingWinner(1000);
        vm.warp(epochStart(1000) + STALL_GRACE + BACKUP_GRACE + FALLBACK_GRACE + 1);

        _checkProposer(David); // no bond, no bid
        IProposerAuction.StallEscrow memory escrow = auction.getPendingStallSlash(1000);
        assertEq(escrow.challenger, David);
    }

    function test_checkProposer_RevertWhen_backupTooEarlyDuringBackupGrace() public {
        _setupServingWinner(1000);
        // Bonded operator but not the backup: only the backup may propose during rung 1.
        _depositBond(Carol, ejectionThreshold());
        vm.warp(epochStart(1000) + STALL_GRACE + 1);

        vm.prank(address(inbox));
        vm.expectRevert(IProposerChecker.InvalidProposer.selector);
        auction.checkProposer(Carol, "");
    }

    function test_checkProposer_unassignedEpochBondedFirstThenAnyone() public {
        warpToEpoch(1000);
        _depositBond(Carol, ejectionThreshold());
        _depositEth(Carol, INITIAL_FLOOR * 1 gwei); // Q19: the unassigned-mode fee

        vm.prank(address(inbox));
        vm.expectRevert(IProposerChecker.InvalidProposer.selector);
        auction.checkProposer(David, ""); // unbonded before the grace

        _checkProposer(Carol); // bonded operators may propose from the epoch start (pay the fee)
        assertEq(auction.getProceeds(), INITIAL_FLOOR * 1 gwei, "unassigned fee charged once");

        vm.warp(epochStart(1000) + STALL_GRACE + 1);
        _checkProposer(David); // anyone after the grace (free liveness floor)
    }

    function test_checkProposer_oneEscrowPerEpoch() public {
        _setupServingWinner(1000);
        vm.warp(epochStart(1000) + STALL_GRACE + BACKUP_GRACE + FALLBACK_GRACE + 1);

        _checkProposer(David);
        vm.warp(block.timestamp + STALL_GRACE + 1); // the ladder re-opens after the next silence
        _checkProposer(Bob); // backup proposes in the rung-1 window
        assertEq(
            auction.getBondInfo(Alice).balance, requiredBond() - LIVENESS_BOND, "single escrow"
        );
    }

    function test_checkProposer_winnerCanComeBackAfterStall_butEscrowSurvives() public {
        _setupServingWinner(1000);
        vm.warp(epochStart(1000) + ESCROW_GRACE + 1);
        _checkProposer(Bob); // escrows

        vm.warp(epochStart(1000) + ESCROW_GRACE + 10);
        _checkProposer(Alice); // winner comes back

        IProposerAuction.StallEscrow memory escrow = auction.getPendingStallSlash(1000);
        assertFalse(escrow.settled, "re-proposing alone does not release the escrow");
        assertEq(escrow.amount, LIVENESS_BOND);
    }

    function test_checkProposer_stallClockResetsOnWinnerProposal() public {
        _setupServingWinner(1000);
        vm.warp(epochStart(1000) + 10);
        _checkProposer(Alice);

        // 40s after the winner's proposal (< STALL_GRACE): still not stalled.
        vm.warp(epochStart(1000) + 50);
        vm.prank(address(inbox));
        vm.expectRevert(IProposerChecker.InvalidProposer.selector);
        auction.checkProposer(Bob, "");
    }

    // ---------------------------------------------------------------
    // Stall escrow: settle & refute
    // ---------------------------------------------------------------

    function _setupEscrowedStall(uint256 _epoch) internal returns (uint48 escrowedAt_) {
        _setupServingWinner(_epoch);
        vm.warp(epochStart(_epoch) + ESCROW_GRACE + 1);
        _checkProposer(Bob);
        escrowedAt_ = uint48(block.timestamp);
    }

    function test_settleStallSlash_backupChallengerRewardBurnedAndSettlerBountied() public {
        _setupEscrowedStall(1000);
        vm.warp(epochStart(1000) + ESCROW_GRACE + 1 + REFUTE_WINDOW);

        uint128 challengerBefore = auction.getBondInfo(Bob).balance;
        uint128 bounty = uint128(uint256(LIVENESS_BOND) * SETTLE_BOUNTY_BPS / 10_000);

        // Q9: the designated backup's reward is burned; Q8: a settle bounty goes to the caller.
        vm.expectEmit(true, true, true, true);
        emit IProposerAuction.StallSettled(1000, Alice, LIVENESS_BOND, Bob, 0);
        auction.settleStallSlash(1000);

        assertEq(auction.getBondInfo(Bob).balance, challengerBefore, "backup reward burned");
        assertEq(auction.getBondInfo(address(this)).balance, bounty, "settle bounty to caller");
        assertEq(auction.getTotalSlashedAmount(), LIVENESS_BOND - bounty, "rest locked");
    }

    function test_settleStallSlash_nonBackupChallengerGetsReward() public {
        _setupServingWinner(1000);
        _depositBond(Carol, ejectionThreshold());
        vm.warp(epochStart(1000) + STALL_GRACE + BACKUP_GRACE + 1);
        _checkProposer(Carol); // rung 2: a non-backup bonded operator is the challenger
        vm.warp(epochStart(1000) + STALL_GRACE + BACKUP_GRACE + 1 + REFUTE_WINDOW);

        uint128 reward = uint128(uint256(LIVENESS_BOND) * REWARD_BPS / 10_000);
        uint128 bounty = uint128(uint256(LIVENESS_BOND - reward) * SETTLE_BOUNTY_BPS / 10_000);
        auction.settleStallSlash(1000);

        assertEq(
            auction.getBondInfo(Carol).balance, ejectionThreshold() + reward, "watchdog reward"
        );
        assertEq(auction.getTotalSlashedAmount(), LIVENESS_BOND - reward - bounty);
    }

    function test_settleStallSlash_RevertWhen_windowNotPassed() public {
        _setupEscrowedStall(1000);
        vm.warp(epochStart(1000) + ESCROW_GRACE + 1 + REFUTE_WINDOW - 1);
        vm.expectRevert(ProposerAuction.RefuteWindowNotPassed.selector);
        auction.settleStallSlash(1000);
    }

    function test_settleStallSlash_RevertWhen_noPendingSlash() public {
        warpToEpoch(1000);
        vm.expectRevert(ProposerAuction.NoPendingStallSlash.selector);
        auction.settleStallSlash(1000);
    }

    function test_refuteStall_withCanonicalPreimageInGap_releasesEscrow() public {
        _setupEscrowedStall(1000);
        uint48 escrowedAt = uint48(block.timestamp);

        IInbox.Proposal memory proposal = _makeProposal(7, Alice, uint48(epochStart(1000) + 20));
        _storeProposalHash(7, proposal);

        vm.prank(Alice);
        auction.refuteStall(1000, proposal);

        IProposerAuction.StallEscrow memory escrow = auction.getPendingStallSlash(1000);
        assertTrue(escrow.settled);
        assertEq(auction.getBondInfo(Alice).balance, requiredBond(), "escrow released");
    }

    function test_refuteStall_acceptsPreimageAtEscrowBoundary() public {
        _setupEscrowedStall(1000);
        uint48 escrowedAt = uint48(block.timestamp);

        IInbox.Proposal memory proposal = _makeProposal(7, Alice, escrowedAt);
        _storeProposalHash(7, proposal);

        vm.prank(Alice);
        auction.refuteStall(1000, proposal);
        assertEq(auction.getBondInfo(Alice).balance, requiredBond());
    }

    function test_refuteStall_RevertWhen_strategicStallerWakeUpProposal() public {
        _setupEscrowedStall(1000);
        uint48 escrowedAt = uint48(block.timestamp);

        // The winner's wake-up proposal lands AFTER the recorded gap: it does not disprove it.
        IInbox.Proposal memory proposal = _makeProposal(7, Alice, escrowedAt + 1);
        _storeProposalHash(7, proposal);

        vm.prank(Alice);
        vm.expectRevert(ProposerAuction.InvalidRefutation.selector);
        auction.refuteStall(1000, proposal);

        // The slash settles against the staller.
        vm.warp(escrowedAt + REFUTE_WINDOW);
        auction.settleStallSlash(1000);
        assertEq(auction.getBondInfo(Alice).balance, requiredBond() - LIVENESS_BOND);
    }

    function test_refuteStall_RevertWhen_proposalAtGapStart() public {
        _setupEscrowedStall(1000);
        IInbox.Proposal memory proposal = _makeProposal(7, Alice, uint48(epochStart(1000))); // == gapStart, strictly excluded
        _storeProposalHash(7, proposal);

        vm.prank(Alice);
        vm.expectRevert(ProposerAuction.InvalidRefutation.selector);
        auction.refuteStall(1000, proposal);
    }

    function test_refuteStall_RevertWhen_wrongProposer() public {
        _setupEscrowedStall(1000);
        IInbox.Proposal memory proposal = _makeProposal(7, Bob, uint48(epochStart(1000) + 20));
        _storeProposalHash(7, proposal);

        vm.prank(Alice);
        vm.expectRevert(ProposerAuction.InvalidRefutation.selector);
        auction.refuteStall(1000, proposal);
    }

    function test_refuteStall_RevertWhen_hashMismatch() public {
        _setupEscrowedStall(1000);
        IInbox.Proposal memory proposal = _makeProposal(7, Alice, uint48(epochStart(1000) + 20));
        // The stored hash is for a DIFFERENT proposal.
        IInbox.Proposal memory other = _makeProposal(7, Alice, uint48(epochStart(1000) + 21));
        _storeProposalHash(7, other);

        vm.prank(Alice);
        vm.expectRevert(ProposerAuction.InvalidRefutation.selector);
        auction.refuteStall(1000, proposal);
    }

    function test_refuteStall_RevertWhen_notWinner() public {
        _setupEscrowedStall(1000);
        IInbox.Proposal memory proposal = _makeProposal(7, Alice, uint48(epochStart(1000) + 20));
        _storeProposalHash(7, proposal);

        vm.prank(Carol);
        vm.expectRevert(ProposerAuction.NotWinner.selector);
        auction.refuteStall(1000, proposal);
    }

    function test_settleStallSlash_RevertWhen_alreadyRefuted() public {
        _setupEscrowedStall(1000);
        IInbox.Proposal memory proposal = _makeProposal(7, Alice, uint48(epochStart(1000) + 20));
        _storeProposalHash(7, proposal);
        vm.prank(Alice);
        auction.refuteStall(1000, proposal);

        vm.warp(block.timestamp + REFUTE_WINDOW + 1);
        vm.expectRevert(ProposerAuction.NoPendingStallSlash.selector);
        auction.settleStallSlash(1000);
    }

    // ---------------------------------------------------------------
    // S1: signed-block slashing
    // ---------------------------------------------------------------

    function _setupS1Epoch(uint256 _epoch) internal {
        _setupServingWinner(_epoch);
        warpToEpoch(_epoch);
        _checkProposer(Alice); // triggers the snapshot: records winner + signer
    }

    function test_slashInvalidBlock_slashesWinner() public {
        _setupS1Epoch(1000);

        IProposerAuction.SignedBlock memory bad = _signedBlock(
            ALICE_KEY,
            uint32(1000),
            5,
            5,
            bytes32(uint256(1)),
            uint48(epochStart(1000) + EPOCH + 10),
            bytes32(uint256(0xabc))
        );

        vm.expectEmit(true, true, true, true);
        emit IProposerAuction.ProposerSlashed(Alice, 2, LIVENESS_BOND, David, LIVENESS_BOND / 2);
        vm.prank(David);
        auction.slashInvalidBlock(1000, bad);

        assertEq(auction.getBondInfo(Alice).balance, requiredBond() - LIVENESS_BOND);
        assertEq(auction.getBondInfo(David).balance, LIVENESS_BOND / 2);
        assertEq(auction.getTotalSlashedAmount(), LIVENESS_BOND / 2);
    }

    function test_slashInvalidBlock_RevertWhen_timestampInWindow() public {
        _setupS1Epoch(1000);

        IProposerAuction.SignedBlock memory ok = _signedBlock(
            ALICE_KEY,
            uint32(1000),
            5,
            5,
            bytes32(uint256(1)),
            uint48(epochStart(1000) + 50),
            bytes32(uint256(0xabc))
        );

        vm.expectRevert(ProposerAuction.NoViolation.selector);
        auction.slashInvalidBlock(1000, ok);
    }

    function test_slashInvalidBlock_RevertWhen_wrongSigner() public {
        _setupS1Epoch(1000);

        IProposerAuction.SignedBlock memory bad = _signedBlock(
            CAROL_KEY,
            uint32(1000),
            5,
            5,
            bytes32(uint256(1)),
            uint48(epochStart(1000) + EPOCH + 10),
            bytes32(uint256(0xabc))
        );

        vm.expectRevert(ProposerAuction.InvalidSignature.selector);
        auction.slashInvalidBlock(1000, bad);
    }

    function test_slashInvalidBlock_RevertWhen_noWinnerForEpoch() public {
        warpToEpoch(1000);
        IProposerAuction.SignedBlock memory bad = _signedBlock(
            ALICE_KEY,
            uint32(1000),
            5,
            5,
            bytes32(uint256(1)),
            uint48(epochStart(1000) + EPOCH + 10),
            bytes32(uint256(0xabc))
        );

        vm.expectRevert(ProposerAuction.NoWinnerForEpoch.selector);
        auction.slashInvalidBlock(1000, bad);
    }

    function test_slashEquivocation_slashesWinner() public {
        _setupS1Epoch(1000);

        IProposerAuction.SignedBlock memory a = _signedBlock(
            ALICE_KEY,
            uint32(1000),
            5,
            5,
            bytes32(uint256(1)),
            uint48(epochStart(1000) + 10),
            bytes32(uint256(0xa))
        );
        IProposerAuction.SignedBlock memory b = _signedBlock(
            ALICE_KEY,
            uint32(1000),
            5,
            5,
            bytes32(uint256(1)),
            uint48(epochStart(1000) + 20),
            bytes32(uint256(0xb))
        );

        auction.slashEquivocation(1000, a, b);
        assertEq(auction.getBondInfo(Alice).balance, requiredBond() - LIVENESS_BOND);
    }

    function test_slashEquivocation_RevertWhen_sameBlock() public {
        _setupS1Epoch(1000);

        IProposerAuction.SignedBlock memory a = _signedBlock(
            ALICE_KEY,
            uint32(1000),
            5,
            5,
            bytes32(uint256(1)),
            uint48(epochStart(1000) + 10),
            bytes32(uint256(0xa))
        );

        vm.expectRevert(ProposerAuction.NoViolation.selector);
        auction.slashEquivocation(1000, a, a);
    }

    function test_slashEquivocation_RevertWhen_differentSeqNo() public {
        _setupS1Epoch(1000);

        IProposerAuction.SignedBlock memory a = _signedBlock(
            ALICE_KEY,
            uint32(1000),
            5,
            5,
            bytes32(uint256(1)),
            uint48(epochStart(1000) + 10),
            bytes32(uint256(0xa))
        );
        IProposerAuction.SignedBlock memory b = _signedBlock(
            ALICE_KEY,
            uint32(1000),
            6,
            6,
            bytes32(uint256(1)),
            uint48(epochStart(1000) + 20),
            bytes32(uint256(0xb))
        );

        // Q10: equivocation is now keyed on (epoch, seqNo); different seqNo is not equivocation.
        vm.expectRevert(ProposerAuction.NoViolation.selector);
        auction.slashEquivocation(1000, a, b);
    }

    function test_slash_RevertWhen_alreadySlashed() public {
        _setupS1Epoch(1000);

        IProposerAuction.SignedBlock memory bad = _signedBlock(
            ALICE_KEY,
            uint32(1000),
            5,
            5,
            bytes32(uint256(1)),
            uint48(epochStart(1000) + EPOCH + 10),
            bytes32(uint256(0xabc))
        );
        auction.slashInvalidBlock(1000, bad);

        vm.expectRevert(ProposerAuction.AlreadySlashed.selector);
        auction.slashInvalidBlock(1000, bad);
    }

    function test_slash_ejectsWinnerBelowThreshold() public {
        _setupS1Epoch(1000);

        // 1) Stall escrow + settle: 400 -> 300.
        vm.warp(epochStart(1000) + ESCROW_GRACE + 1);
        _checkProposer(Bob);
        vm.warp(epochStart(1000) + ESCROW_GRACE + 1 + REFUTE_WINDOW);
        auction.settleStallSlash(1000);
        assertEq(auction.getBondInfo(Alice).balance, 300);

        // 2) First S1 slash: 300 -> 200 (== threshold, not ejected).
        IProposerAuction.SignedBlock memory bad1 = _signedBlock(
            ALICE_KEY,
            uint32(1000),
            5,
            5,
            bytes32(uint256(1)),
            uint48(epochStart(1000) + EPOCH + 10),
            bytes32(uint256(0x1))
        );
        auction.slashInvalidBlock(1000, bad1);
        (IProposerAuction.BidInfo memory info,) = auction.getBidderInfo(Alice);
        assertEq(info.amountInGwei, 1000, "not ejected at the threshold");

        // 3) Second S1 slash: 200 -> 100 (< threshold) => ejected.
        IProposerAuction.SignedBlock memory bad2 = _signedBlock(
            ALICE_KEY,
            uint32(1000),
            9,
            9,
            bytes32(uint256(2)),
            uint48(epochStart(1000) + EPOCH + 11),
            bytes32(uint256(0x2))
        );
        vm.expectEmit(true, true, true, true);
        emit IProposerAuction.ProposerEjected(Alice);
        auction.slashInvalidBlock(1000, bad2);

        (info,) = auction.getBidderInfo(Alice);
        assertEq(info.amountInGwei, 0, "ejected bidder removed from the list");
        assertEq(auction.getBidderCount(), 1, "Bob remains");
        assertGt(auction.getBondInfo(Alice).withdrawableAt, 0);
    }

    // ---------------------------------------------------------------
    // Bonds, ETH, proceeds
    // ---------------------------------------------------------------

    function test_bond_depositAndWithdraw_unlistedAccount() public {
        warpToEpoch(1000);
        _depositBond(Alice, 500);
        assertEq(auction.getBondInfo(Alice).balance, 500);

        vm.prank(Alice);
        auction.withdrawBond(200);
        assertEq(auction.getBondInfo(Alice).balance, 300);
        assertEq(bondToken.balanceOf(Alice), 200 * 1 gwei);
    }

    function test_withdrawBond_RevertWhen_activeBidder() public {
        warpToEpoch(1000);
        _setupWinner(Alice, 1000, vm.addr(ALICE_KEY));

        vm.prank(Alice);
        vm.expectRevert(ProposerAuction.ActiveBidderMustQuitFirst.selector);
        auction.withdrawBond(100);
    }

    function test_withdrawBond_afterQuitAndDelay() public {
        warpToEpoch(1000);
        _setupWinner(Alice, 1000, vm.addr(ALICE_KEY));
        vm.prank(Alice);
        auction.quit();

        vm.warp(block.timestamp + BOND_WITHDRAWAL_DELAY);
        uint128 bondAmount = requiredBond();
        vm.prank(Alice);
        auction.withdrawBond(bondAmount);
        assertEq(auction.getBondInfo(Alice).balance, 0);
    }

    function test_eth_depositAndWithdraw() public {
        warpToEpoch(1000);
        _depositEth(Alice, 5 ether);
        assertEq(auction.getEthBalance(Alice), 5 ether);

        vm.prank(Alice);
        auction.withdrawEth(2 ether);
        assertEq(auction.getEthBalance(Alice), 3 ether);
    }

    function test_withdrawProceeds_onlyOwner() public {
        warpToEpoch(1000);
        _setupWinner(Alice, 1000, vm.addr(ALICE_KEY));
        _depositEth(Alice, 1000 * 1 gwei);
        warpToEpoch(1002);
        _checkProposer(Alice);
        assertEq(auction.getProceeds(), 1000 * 1 gwei);

        vm.prank(Bob);
        vm.expectRevert("Ownable: caller is not the owner");
        auction.withdrawProceeds(Bob, 1);

        uint256 proceedsBefore = auction.getProceeds();
        vm.prank(Alice);
        auction.withdrawProceeds(Alice, proceedsBefore);
        assertEq(auction.getProceeds(), 0);
    }

    // ---------------------------------------------------------------
    // Review-round-2 fixes: pending transitions & finality
    // ---------------------------------------------------------------

    function test_rebid_doesNotForfeitAlreadyWonEpoch() public {
        warpToEpoch(1000);
        _setupWinner(Alice, 1000, vm.addr(ALICE_KEY));
        _depositEth(Alice, 3000 * 1 gwei);
        warpToEpoch(1001);

        vm.prank(Alice);
        auction.bid(1200, vm.addr(ALICE_KEY)); // pending, effective 1003

        warpToEpoch(1002);
        _checkProposer(Alice);
        assertEq(auction.getProceeds(), 1000 * 1 gwei, "epoch 1002 charged at the old rate");

        warpToEpoch(1003);
        _checkProposer(Alice);
        assertEq(auction.getProceeds(), 1000 * 1 gwei + 1200 * 1 gwei, "epoch 1003 at the new rate");
    }

    function test_renew_doesNotResurrectIntoFinalizedEpoch() public {
        warpToEpoch(1000);
        _setupWinner(Alice, 1000, vm.addr(ALICE_KEY));
        _depositEth(Alice, 100_000 * 1 gwei); // cover catch-up charges
        // Expiry: 1012.

        vm.warp(epochStart(1011));
        vm.prank(Alice);
        auction.renew(); // pending, effective 1013
        auction.snapshot(); // fixes the next (1012) assignment without the renewal

        warpToEpoch(1012);
        IProposerAuction.Assignment memory current = auction.getAssignmentForCurrentEpoch();
        assertEq(current.winner, address(0), "renewal cannot resurrect the finalized epoch");

        warpToEpoch(1013);
        auction.snapshot();
        current = auction.getAssignmentForCurrentEpoch();
        assertEq(current.winner, Alice, "renewal applies from its effective epoch");
    }

    function test_pendingRenewal_survivesPurge() public {
        warpToEpoch(1000);
        _setupWinner(Alice, 1000, vm.addr(ALICE_KEY));
        _depositEth(Alice, 100_000 * 1 gwei); // cover catch-up charges

        vm.warp(epochStart(1011));
        vm.prank(Alice);
        auction.renew(); // pending effective 1013

        warpToEpoch(1012);
        assertEq(auction.purgeInactive(), 0, "pending renewal keeps the entry alive");
        auction.snapshot();
        IProposerAuction.Assignment memory next = auction.getAssignmentForNextEpoch();
        assertEq(next.winner, Alice, "renewed entry serves the next epoch");
    }

    function test_quit_clearsPendingRebid() public {
        warpToEpoch(1000);
        _setupWinner(Alice, 1000, vm.addr(ALICE_KEY));
        vm.prank(Alice);
        auction.bid(1200, vm.addr(BOB_KEY)); // pending
        assertEq(auction.getPendingUpdate(Alice).effectiveEpoch, 1002);

        vm.prank(Alice);
        auction.quit();
        assertEq(auction.getPendingUpdate(Alice).effectiveEpoch, 0, "quit wins over pending");
    }

    function test_withdrawEth_fixedNextWinnerCannotDrainWonEpochFee() public {
        warpToEpoch(1000);
        // _setupWinner funds exactly one epoch of fees: nothing withdrawable while fixed as next.
        _setupWinner(Alice, 1000, vm.addr(ALICE_KEY));
        warpToEpoch(1001);
        auction.snapshot(); // fixes Alice as the next (1002) winner

        vm.prank(Alice);
        vm.expectRevert(ProposerAuction.InsufficientEth.selector);
        auction.withdrawEth(1); // the full balance is reserved for the won epoch

        _depositEth(Alice, 500 * 1 gwei);
        vm.prank(Alice);
        auction.withdrawEth(500 * 1 gwei); // only the surplus is withdrawable
        assertEq(auction.getEthBalance(Alice), 1000 * 1 gwei);
    }

    // ---------------------------------------------------------------
    // Review-round-2 fixes: slashing
    // ---------------------------------------------------------------

    function test_signerRotation_pendingOldSignerRemainsSlashableForCurrentEpoch() public {
        _setupServingWinner(1000); // signer ALICE_KEY, serves epoch 1000
        warpToEpoch(999);
        vm.prank(Alice);
        auction.bid(1000, vm.addr(BOB_KEY)); // pending signer rotation, effective 1001
        warpToEpoch(1000);
        _checkProposer(Alice); // snapshot records the signer for 1000 before the rotation

        IProposerAuction.SignedBlock memory badOld = _signedBlock(
            ALICE_KEY,
            uint32(1000),
            5,
            5,
            bytes32(uint256(1)),
            uint48(epochStart(1000) + EPOCH + 10),
            bytes32(uint256(0xabc))
        );
        vm.prank(David);
        auction.slashInvalidBlock(1000, badOld); // the old signer is still slashable
        assertEq(auction.getBondInfo(Alice).balance, requiredBond() - LIVENESS_BOND);

        IProposerAuction.SignedBlock memory badNew = _signedBlock(
            BOB_KEY,
            uint32(1000),
            6,
            6,
            bytes32(uint256(1)),
            uint48(epochStart(1000) + EPOCH + 11),
            bytes32(uint256(0xabd))
        );
        vm.expectRevert(ProposerAuction.InvalidSignature.selector);
        auction.slashInvalidBlock(1000, badNew); // new signer not yet effective for 1000
    }

    function test_snapshot_pokeRecordsWinnerWithoutProposals() public {
        warpToEpoch(1000);
        _setupWinner(Alice, 1000, vm.addr(ALICE_KEY));
        _depositEth(Alice, 1000 * 1 gwei);
        warpToEpoch(1002); // nobody proposes in 1002

        auction.snapshot();
        assertEq(auction.getProceeds(), 1000 * 1 gwei, "fee charged by the poke");

        IProposerAuction.SignedBlock memory bad = _signedBlock(
            ALICE_KEY,
            uint32(1002),
            5,
            5,
            bytes32(uint256(1)),
            uint48(epochStart(1002) + EPOCH + 10),
            bytes32(uint256(0xabc))
        );
        vm.prank(David);
        auction.slashInvalidBlock(1002, bad);
        assertEq(auction.getBondInfo(Alice).balance, requiredBond() - LIVENESS_BOND);
    }

    function test_constructor_RevertWhen_rewardBpsAboveHalf() public {
        IProposerAuction.Config memory config = _defaultConfig();
        config.rewardBps = 5001;
        vm.expectRevert(ProposerAuction.InvalidBps.selector);
        new ProposerAuction(config);
    }

    function test_constructor_RevertWhen_escrowGraceBelowStallGrace() public {
        IProposerAuction.Config memory config = _defaultConfig();
        config.escrowGrace = STALL_GRACE - 1;
        vm.expectRevert(ProposerAuction.InvalidEscrowGrace.selector);
        new ProposerAuction(config);
    }

    function test_slash_RevertWhen_noBondLeft() public {
        _setupS1Epoch(1000);
        vm.prank(Alice);
        auction.quit();
        vm.warp(block.timestamp + BOND_WITHDRAWAL_DELAY);
        uint128 bondAmount = requiredBond();
        vm.prank(Alice);
        auction.withdrawBond(bondAmount);

        IProposerAuction.SignedBlock memory bad = _signedBlock(
            ALICE_KEY,
            uint32(1000),
            5,
            5,
            bytes32(uint256(1)),
            uint48(epochStart(1000) + EPOCH + 10),
            bytes32(uint256(0xabc))
        );
        vm.expectRevert(ProposerAuction.NoBondToSlash.selector);
        auction.slashInvalidBlock(1000, bad);
    }

    // ---------------------------------------------------------------
    // Round-4 regressions
    // ---------------------------------------------------------------

    function test_reserveFloor_decaysDuringUnassignedEpochs() public {
        warpToEpoch(1000);
        _setupWinner(Alice, 1000, vm.addr(ALICE_KEY));
        _depositEth(Alice, 3 * 1000 * 1 gwei);

        warpToEpoch(1002);
        _checkProposer(Alice); // charge 1000 => EMA = 1000, floor = 1000
        assertEq(auction.getReserveFloor(), 1000);

        vm.prank(Alice);
        auction.quit(); // effective 1004: Alice serves 1002/1003, then unassigned

        warpToEpoch(1003);
        _checkProposer(Alice); // still serving 1003

        warpToEpoch(1004);
        auction.snapshot(); // 1004 unassigned: one decay step (Q1)
        assertEq(
            auction.getReserveFloor(),
            uint128(uint256(1000) * FLOOR_DECAY_BPS / 10_000),
            "one decay step"
        );
    }

    function test_checkProposer_ladderDoesNotRecloseAtBoundary() public {
        _setupServingWinner(1000);
        _depositEth(Alice, 1000 * 1 gwei); // fund one more epoch

        vm.warp(epochStart(1000) + 10);
        _checkProposer(Alice); // _lastWinnerProposalAt = epochStart(1000) + 10

        vm.warp(epochStart(1000) + STALL_GRACE + 11);
        _checkProposer(Bob); // ladder opens mid-epoch (absence > stallGrace)

        // Q2: crossing the boundary with an unchanged (stalled) winner must not re-close the
        // ladder — the backup proposes immediately, without re-waiting stallGrace.
        warpToEpoch(1001);
        _checkProposer(Bob);
    }

    function test_withdrawBond_expiredBidderStartsWithdrawalClock() public {
        warpToEpoch(1000);
        _setupWinner(Alice, 1000, vm.addr(ALICE_KEY));

        warpToEpoch(1013); // past Alice's expiry (1012)
        uint128 bondAmount = requiredBond();
        vm.prank(Alice);
        vm.expectRevert(ProposerAuction.WithdrawalDelayNotPassed.selector);
        auction.withdrawBond(bondAmount); // Q6: expiry alone is not a delay-free exit

        // Purging lapses the expired bid and starts the withdrawal clock; she still must wait.
        auction.purgeInactive();
        assertGt(auction.getBondInfo(Alice).withdrawableAt, 0, "clock started by purge");
        vm.prank(Alice);
        vm.expectRevert(ProposerAuction.WithdrawalDelayNotPassed.selector);
        auction.withdrawBond(bondAmount);
    }

    function test_slashEquivocation_fabricatedParentHashSameSeqNo() public {
        _setupS1Epoch(1000);

        // Q10: same (epoch, seqNo) but different blockNumber/parentHash/content — a fabricated
        // parentHash double-spend is a second signature for the same slot, regardless of parent.
        IProposerAuction.SignedBlock memory a = _signedBlock(
            ALICE_KEY,
            uint32(1000),
            5,
            5,
            bytes32(uint256(1)),
            uint48(epochStart(1000) + 10),
            bytes32(uint256(0xa))
        );
        IProposerAuction.SignedBlock memory b = _signedBlock(
            ALICE_KEY,
            uint32(1000),
            5,
            999,
            bytes32(uint256(0xdead)),
            uint48(epochStart(1000) + 20),
            bytes32(uint256(0xb))
        );

        auction.slashEquivocation(1000, a, b); // slashes (no revert)
        assertEq(auction.getBondInfo(Alice).balance, requiredBond() - LIVENESS_BOND);
    }

    function test_slashInvalidBlock_handoverMarginAllowsIncomingOperator() public {
        _setupS1Epoch(1000);

        // Q3: an incoming operator's handover block sits in the last HANDOVER_MARGIN seconds of
        // the outgoing epoch; it must not be slashable.
        IProposerAuction.SignedBlock memory handover = _signedBlock(
            ALICE_KEY,
            uint32(1000),
            5,
            5,
            bytes32(uint256(1)),
            uint48(epochStart(1000) - HANDOVER_MARGIN / 2),
            bytes32(uint256(0xabc))
        );
        vm.expectRevert(ProposerAuction.NoViolation.selector);
        auction.slashInvalidBlock(1000, handover);
    }

    function test_checkProposer_bondUsedDefersWithdrawal() public {
        _setupServingWinner(1000);
        _depositBond(Carol, ejectionThreshold());
        assertEq(auction.getBondInfo(Carol).withdrawableAt, 0);

        vm.warp(epochStart(1000) + STALL_GRACE + BACKUP_GRACE + 1);
        _checkProposer(Carol); // rung 2 via the bond

        // Q15: using the bond to pass the rung starts its withdrawal clock.
        assertEq(
            auction.getBondInfo(Carol).withdrawableAt,
            uint48(epochStart(1000) + STALL_GRACE + BACKUP_GRACE + 1) + BOND_WITHDRAWAL_DELAY
        );
    }

    // ---------------------------------------------------------------
    // Round-5 adversarial review regressions
    // ---------------------------------------------------------------

    /// @dev R5-F1: a chain-wide quiet period (nobody proposes at all) must not be charged to the
    ///      winner as absence. Before the fix the carried clock made the first post-gap proposal
    ///      escrow the winner's bond over a gap they could not refute.
    function test_R5_outageRecovery_doesNotEscrowHonestWinner() public {
        _setupServingWinner(1000);

        // The winner serves epoch 1000 normally.
        vm.warp(epochStart(1000) + 10);
        _checkProposer(Alice);

        // A chain-wide outage: no proposals at all for several epochs.
        _depositEth(Alice, uint256(1000) * 1 gwei * 12);
        warpToEpoch(1006);

        // The backup front-runs the winner's first post-recovery proposal, past the ladder-open
        // grace but still inside the (larger) escrow grace measured from THIS epoch's start.
        // With the pre-fix carried clock the absence would span the whole outage and escrow here.
        vm.warp(epochStart(1006) + STALL_GRACE + 1);
        _checkProposer(Bob);

        assertEq(
            auction.getPendingStallSlash(1006).escrowedAt,
            0,
            "no escrow may fire on the first proposal after a backfilled gap"
        );
        assertEq(auction.getBondInfo(Alice).balance, requiredBond(), "winner bond untouched");

        // The winner is still slashable if they stay silent past the fresh grace.
        vm.warp(epochStart(1006) + ESCROW_GRACE + 1);
        _checkProposer(Bob);
        assertEq(
            auction.getPendingStallSlash(1006).winner,
            Alice,
            "a genuine in-epoch stall still escrows after recovery"
        );
    }

    /// @dev R5-F1 companion: a *continuous* outage, where fallback proposals keep arriving every
    ///      epoch, must still escrow — the Q2 clock carry is preserved for the witnessed case.
    function test_R5_continuousOutage_stillEscrowsStallingWinner() public {
        _setupServingWinner(1000);
        vm.warp(epochStart(1000) + ESCROW_GRACE + 1);
        _checkProposer(Bob);

        assertEq(
            auction.getPendingStallSlash(1000).winner, Alice, "a witnessed stall still escrows"
        );
    }

    /// @dev R5-F2: a new bid must never evict an address holding a finalized assignment, even
    ///      when that address is the cheapest entry on a full list.
    function test_R5_eviction_cannotRemoveActiveWinner() public {
        // Alice wins from epoch 1000 at the lowest rate on the list.
        warpToEpoch(998);
        _setupWinner(Alice, 1000, vm.addr(ALICE_KEY));
        _depositEth(Alice, uint256(1000) * 1 gwei * 20);
        warpToEpoch(1000);
        _checkProposer(Alice); // fix the assignment cache on Alice

        assertEq(auction.getAssignmentForCurrentEpoch().winner, Alice);

        // Fill the list with higher, not-yet-effective bids.
        for (uint256 i; i < 15; ++i) {
            address filler = makeAddr(string.concat("filler", vm.toString(i)));
            _bidder(filler, 2000, filler);
        }
        assertEq(auction.getBidderCount(), 16);

        // A new entrant clears Alice's raw amount by the increment but must not evict her.
        address newcomer = makeAddr("newcomer");
        _depositBond(newcomer, requiredBond());
        vm.prank(newcomer);
        auction.bid(2100, newcomer);

        assertEq(
            auction.getAssignmentForCurrentEpoch().winner,
            Alice,
            "the reigning winner survives the eviction"
        );
        (IProposerAuction.BidInfo memory aliceInfo,) = auction.getBidderInfo(Alice);
        assertGt(aliceInfo.amountInGwei, 0, "Alice is still listed");
    }

    /// @dev R5-F4: the settle bounty is a watchdog fee. Neither the slashed winner nor a backup
    ///      challenger (whose reward Q9 burns) may collect it by self-settling.
    function test_R5_settleBounty_deniedToSlashedWinnerAndBackupChallenger() public {
        uint48 escrowedAt = _setupEscrowedStall(1000);
        vm.warp(escrowedAt + REFUTE_WINDOW);

        uint128 backupBefore = auction.getBondInfo(Bob).balance;
        uint128 winnerBefore = auction.getBondInfo(Alice).balance;

        // Bob is the designated backup and the recorded challenger: self-settling pays him nothing.
        vm.prank(Bob);
        auction.settleStallSlash(1000);

        assertEq(auction.getBondInfo(Bob).balance, backupBefore, "backup gets no bounty");
        assertEq(auction.getBondInfo(Alice).balance, winnerBefore, "winner gets no refund");
        assertEq(
            auction.getTotalSlashedAmount(), LIVENESS_BOND, "the whole slash stays locked/burned"
        );
    }

    /// @dev R5-F4 companion: the slashed winner cannot claw back a bounty either.
    function test_R5_settleBounty_deniedToSlashedWinner() public {
        _setupServingWinner(1000);
        _depositBond(Carol, ejectionThreshold());
        vm.warp(epochStart(1000) + STALL_GRACE + BACKUP_GRACE + 1);
        _checkProposer(Carol); // non-backup challenger
        vm.warp(block.timestamp + REFUTE_WINDOW);

        uint128 winnerBefore = auction.getBondInfo(Alice).balance;
        vm.prank(Alice);
        auction.settleStallSlash(1000);

        assertEq(auction.getBondInfo(Alice).balance, winnerBefore, "no self-refund via the bounty");
    }

    /// @dev R5-F5: the increment cap must never drag the reserve floor below initialFloor, and an
    ///      incumbent must not be able to self-lower below their own live rate.
    function test_R5_reserveFloor_neverBelowInitialFloorAndSelfLowerBounded() public {
        warpToEpoch(998);
        _setupWinner(Alice, 1000, vm.addr(ALICE_KEY));
        _depositEth(Alice, uint256(1000) * 1 gwei * 10);
        warpToEpoch(1000);
        _checkProposer(Alice);

        // A self re-bid below the incumbent's own live rate is rejected.
        vm.prank(Alice);
        vm.expectRevert(ProposerAuction.BidBelowReserve.selector);
        auction.bid(1, vm.addr(ALICE_KEY));

        // Re-bidding at the same rate (a signer rotation) is still allowed.
        vm.prank(Alice);
        auction.bid(1000, vm.addr(CAROL_KEY));

        assertGe(auction.getReserveFloor(), INITIAL_FLOOR, "floor never sinks below initialFloor");
    }

    /// @dev R5-F6: one equivocation is slashable exactly once, in either argument order.
    function test_R5_equivocation_cannotBeSlashedTwiceByReorderingEvidence() public {
        _setupServingWinner(1000);
        vm.warp(epochStart(1000) + 10);
        _checkProposer(Alice);

        IProposerAuction.SignedBlock memory a = _signedBlock(
            ALICE_KEY,
            1000,
            7,
            100,
            bytes32(uint256(1)),
            uint48(epochStart(1000) + 10),
            bytes32("A")
        );
        IProposerAuction.SignedBlock memory b = _signedBlock(
            ALICE_KEY,
            1000,
            7,
            100,
            bytes32(uint256(1)),
            uint48(epochStart(1000) + 10),
            bytes32("B")
        );

        auction.slashEquivocation(1000, a, b);
        uint128 afterFirst = auction.getBondInfo(Alice).balance;

        vm.expectRevert(ProposerAuction.AlreadySlashed.selector);
        auction.slashEquivocation(1000, b, a);

        assertEq(auction.getBondInfo(Alice).balance, afterFirst, "no second burn for one fault");
    }

    /// @dev R5-F7: the handover margin is only granted for a genuine handover. An operator that
    ///      won both adjacent epochs cannot hold two legal epoch tags at once.
    function test_R5_handoverMargin_withheldWhenSameOperatorHoldsBothEpochs() public {
        _setupServingWinner(1000);
        vm.warp(epochStart(1000) + 10);
        _checkProposer(Alice); // records epoch 1000 -> Alice

        _depositEth(Alice, uint256(1000) * 1 gwei * 4);
        warpToEpoch(1001);
        vm.warp(epochStart(1001) + 10);
        _checkProposer(Alice); // records epoch 1001 -> Alice as well

        // A block tagged 1001 inside the pre-epoch handover window is NOT legal here: Alice held
        // 1000 too, so there was no handover to justify the early window.
        IProposerAuction.SignedBlock memory early = _signedBlock(
            ALICE_KEY,
            1001,
            0,
            200,
            bytes32(uint256(2)),
            uint48(epochStart(1001) - 10),
            bytes32("X")
        );
        auction.slashInvalidBlock(1001, early);

        assertEq(
            auction.getBondInfo(Alice).balance,
            requiredBond() - LIVENESS_BOND,
            "the overlap-tagged block is slashable when there was no handover"
        );
    }

    /// @dev R5-F9: a pending update must not survive its entry's removal and clobber a later bid.
    ///      quit() clears its own pending, so the orphan is reached through a removal path that
    ///      does not — here, lapsing for non-payment.
    function test_R5_pendingUpdate_clearedOnRemoval() public {
        warpToEpoch(1000);
        _setupWinner(Alice, 1000, vm.addr(ALICE_KEY)); // funded for exactly one epoch
        warpToEpoch(1002);
        auction.snapshot(); // Alice wins 1002 and spends her only prepaid epoch

        // Alice queues a pending re-bid, then runs out of ETH and is lapsed (not via quit()).
        vm.prank(Alice);
        auction.bid(2000, vm.addr(BOB_KEY));
        assertGt(auction.getPendingUpdate(Alice).effectiveEpoch, 0, "pending re-bid queued");

        warpToEpoch(1003);
        auction.snapshot();
        (IProposerAuction.BidInfo memory gone,) = auction.getBidderInfo(Alice);
        assertEq(gone.amountInGwei, 0, "Alice was lapsed for non-payment");
        assertEq(
            auction.getPendingUpdate(Alice).effectiveEpoch, 0, "the pending update is cleared too"
        );

        // A fresh entry must not be retroactively activated by the stale pending update.
        warpToEpoch(1005);
        vm.prank(Alice);
        auction.bid(500, vm.addr(CAROL_KEY));
        _depositEth(Alice, uint256(500) * 1 gwei * 5); // funded, so any lapse is the pending bug
        warpToEpoch(1007);
        auction.snapshot();

        (IProposerAuction.BidInfo memory info,) = auction.getBidderInfo(Alice);
        assertEq(info.amountInGwei, 500, "the stale pending must not clobber the fresh bid");
        assertEq(info.effectiveEpoch, 1007, "the fresh bid keeps its own 2-epoch lead");
    }

    /// @dev R5-F3: with a backlog deeper than the backfill window, the cache is fast-forwarded to
    ///      the live epoch (and the skip reported) rather than left stale for authorization.
    function test_R5_deepBacklog_landsCacheOnCurrentEpochAndReportsSkip() public {
        warpToEpoch(1000);
        _setupWinner(Alice, 1000, vm.addr(ALICE_KEY));
        _depositEth(Alice, uint256(1000) * 1 gwei * 4);
        warpToEpoch(1002);
        _checkProposer(Alice);

        // A very deep gap: far more epochs than MAX_BACKFILL_EPOCHS.
        warpToEpoch(1300);
        auction.snapshot();

        // The cache is current, so the ladder authorizes against a live assignment.
        assertEq(
            auction.getAssignmentForCurrentEpoch().winner,
            auction.getAssignmentForNextEpoch().winner,
            "cache resolved without reverting"
        );
        vm.warp(epochStart(1300) + 10);
        _checkProposer(Alice); // does not revert: authorization is not stale
    }
}
