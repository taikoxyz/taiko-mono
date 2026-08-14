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
    uint48 internal constant BOND_WITHDRAWAL_DELAY = 1 days;
    uint32 internal constant TENURE_MAX_EPOCHS = 10;
    uint128 internal constant INITIAL_FLOOR = 10; // gwei
    uint8 internal constant AVG_MULTIPLIER = 1;
    uint48 internal constant AVG_WINDOW = uint48(4 * EPOCH);
    uint48 internal constant STALL_GRACE = uint48(4 * SLOT);
    uint48 internal constant BACKUP_GRACE = uint48(4 * SLOT);
    uint48 internal constant FALLBACK_GRACE = uint48(8 * SLOT);
    uint48 internal constant REFUTE_WINDOW = uint48(EPOCH);

    uint256 internal constant ALICE_KEY = 0xA11CE;
    uint256 internal constant BOB_KEY = 0xB0B;
    uint256 internal constant CAROL_KEY = 0xC0C;

    bytes32 internal constant BLOCK_TYPEHASH = keccak256(
        "SignedBlockData(uint32 epoch,uint64 blockNumber,bytes32 parentHash,uint48 timestamp,address coinbase,uint48 gasLimit,bytes32 txRoot)"
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
                impl: address(
                    new ProposerAuction(
                        address(inbox),
                        address(bondToken),
                        LIVENESS_BOND,
                        BOND_MULTIPLIER,
                        REWARD_BPS,
                        BOND_WITHDRAWAL_DELAY,
                        TENURE_MAX_EPOCHS,
                        INITIAL_FLOOR,
                        AVG_MULTIPLIER,
                        AVG_WINDOW,
                        STALL_GRACE,
                        BACKUP_GRACE,
                        FALLBACK_GRACE,
                        REFUTE_WINDOW
                    )
                ),
                data: abi.encodeCall(ProposerAuction.init, (Alice))
            })
        );
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

    function test_bid_updatesOwnBidAndSigner() public {
        warpToEpoch(1000);
        _setupWinner(Alice, 1000, vm.addr(ALICE_KEY));

        vm.prank(Alice);
        auction.bid(1200, vm.addr(BOB_KEY));

        (IProposerAuction.BidInfo memory info, address signer) = auction.getBidderInfo(Alice);
        assertEq(info.amountInGwei, 1200);
        assertEq(signer, vm.addr(BOB_KEY));
        assertEq(auction.getBidderCount(), 1);
    }

    function test_bid_RevertWhen_listFull() public {
        warpToEpoch(1000);
        for (uint256 i; i < 16; ++i) {
            address bidder = makeAddr(string.concat("bidder", vm.toString(i)));
            _bidder(bidder, 100, bidder);
        }
        assertEq(auction.getBidderCount(), 16);

        address extra = makeAddr("extra");
        _depositBond(extra, requiredBond());
        vm.prank(extra);
        vm.expectRevert(ProposerAuction.ListFull.selector);
        auction.bid(200, extra);
    }

    // ---------------------------------------------------------------
    // renew() / quit()
    // ---------------------------------------------------------------

    function test_renew_extendsExpiryWithoutIncrement() public {
        warpToEpoch(1000);
        _setupWinner(Alice, 1000, vm.addr(ALICE_KEY));
        uint32 initialExpiry = 1002 + TENURE_MAX_EPOCHS;

        vm.warp(epochStart(1005));
        vm.prank(Alice);
        auction.renew();

        (IProposerAuction.BidInfo memory info,) = auction.getBidderInfo(Alice);
        assertEq(
            info.expiresAtEpoch,
            1002 + TENURE_MAX_EPOCHS + TENURE_MAX_EPOCHS,
            "renew extends from the current expiry"
        );
        assertGt(info.expiresAtEpoch, initialExpiry);
        assertEq(info.amountInGwei, 1000, "renew does not change the amount");
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

    function test_quit_thenBidAgainRevives() public {
        warpToEpoch(1000);
        _setupWinner(Alice, 1000, vm.addr(ALICE_KEY));
        vm.prank(Alice);
        auction.quit();

        vm.prank(Alice);
        auction.bid(1000, vm.addr(ALICE_KEY));

        (IProposerAuction.BidInfo memory info,) = auction.getBidderInfo(Alice);
        assertEq(info.withdrawEffectiveEpoch, 0);
        IProposerAuction.BondInfo memory bond = auction.getBondInfo(Alice);
        assertEq(bond.withdrawableAt, 0, "re-bid cancels the pending bond withdrawal");
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
        _depositEth(Alice, 3000 * 1 gwei);

        vm.warp(epochStart(1005));
        vm.prank(Alice);
        auction.renew();

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

    function test_checkProposer_backupProposesAfterStallGraceAndEscrows() public {
        _setupServingWinner(1000);
        vm.warp(epochStart(1000) + STALL_GRACE + 1);

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
        assertFalse(escrow.settled);
        assertEq(
            auction.getBondInfo(Alice).balance, requiredBond() - LIVENESS_BOND, "bond escrowed"
        );
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

        vm.prank(address(inbox));
        vm.expectRevert(IProposerChecker.InvalidProposer.selector);
        auction.checkProposer(David, ""); // unbonded before the grace

        _checkProposer(Carol); // bonded operators may propose from the epoch start

        vm.warp(epochStart(1000) + STALL_GRACE + 1);
        _checkProposer(David); // anyone after the grace
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
        vm.warp(epochStart(1000) + STALL_GRACE + 1);
        _checkProposer(Bob); // escrows

        vm.warp(epochStart(1000) + STALL_GRACE + 10);
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
        vm.warp(epochStart(_epoch) + STALL_GRACE + 1);
        _checkProposer(Bob);
        escrowedAt_ = uint48(block.timestamp);
    }

    function test_settleStallSlash_afterWindowRewardsChallengerAndLocksRemainder() public {
        _setupEscrowedStall(1000);
        vm.warp(epochStart(1000) + STALL_GRACE + 1 + REFUTE_WINDOW);

        uint128 challengerBefore = auction.getBondInfo(Bob).balance;
        uint128 lockedBefore = auction.getTotalSlashedAmount();

        vm.expectEmit(true, true, true, true);
        emit IProposerAuction.StallSettled(1000, Alice, LIVENESS_BOND, Bob, LIVENESS_BOND / 2);
        auction.settleStallSlash(1000);

        assertEq(
            auction.getBondInfo(Bob).balance, challengerBefore + LIVENESS_BOND / 2, "50% reward"
        );
        assertEq(auction.getTotalSlashedAmount(), lockedBefore + LIVENESS_BOND / 2, "50% locked");
        assertEq(
            auction.getBondInfo(Alice).balance, requiredBond() - LIVENESS_BOND, "winner debited"
        );
    }

    function test_settleStallSlash_RevertWhen_windowNotPassed() public {
        _setupEscrowedStall(1000);
        vm.warp(epochStart(1000) + STALL_GRACE + 1 + REFUTE_WINDOW - 1);
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
            bytes32(uint256(1)),
            uint48(epochStart(1000) + 10),
            bytes32(uint256(0xa))
        );
        IProposerAuction.SignedBlock memory b = _signedBlock(
            ALICE_KEY,
            uint32(1000),
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
            bytes32(uint256(1)),
            uint48(epochStart(1000) + 10),
            bytes32(uint256(0xa))
        );

        vm.expectRevert(ProposerAuction.NoViolation.selector);
        auction.slashEquivocation(1000, a, a);
    }

    function test_slashEquivocation_RevertWhen_differentBlockNumber() public {
        _setupS1Epoch(1000);

        IProposerAuction.SignedBlock memory a = _signedBlock(
            ALICE_KEY,
            uint32(1000),
            5,
            bytes32(uint256(1)),
            uint48(epochStart(1000) + 10),
            bytes32(uint256(0xa))
        );
        IProposerAuction.SignedBlock memory b = _signedBlock(
            ALICE_KEY,
            uint32(1000),
            6,
            bytes32(uint256(1)),
            uint48(epochStart(1000) + 20),
            bytes32(uint256(0xb))
        );

        vm.expectRevert(ProposerAuction.NoViolation.selector);
        auction.slashEquivocation(1000, a, b);
    }

    function test_slash_RevertWhen_alreadySlashed() public {
        _setupS1Epoch(1000);

        IProposerAuction.SignedBlock memory bad = _signedBlock(
            ALICE_KEY,
            uint32(1000),
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
        vm.warp(epochStart(1000) + STALL_GRACE + 1);
        _checkProposer(Bob);
        vm.warp(epochStart(1000) + STALL_GRACE + 1 + REFUTE_WINDOW);
        auction.settleStallSlash(1000);
        assertEq(auction.getBondInfo(Alice).balance, 300);

        // 2) First S1 slash: 300 -> 200 (== threshold, not ejected).
        IProposerAuction.SignedBlock memory bad1 = _signedBlock(
            ALICE_KEY,
            uint32(1000),
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
}
