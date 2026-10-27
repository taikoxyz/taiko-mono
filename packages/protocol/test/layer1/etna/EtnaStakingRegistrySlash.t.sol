// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EtnaStakingRegistryTestBase } from "./EtnaStakingRegistryTestBase.sol";
import { EtnaTestKeys } from "./EtnaTestKeys.sol";
import { LibEtnaVectors } from "./LibEtnaVectors.sol";
import { MockEtnaInbox } from "./MockEtnaInbox.sol";
import { ReentrantERC20 } from "./ReentrantERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Vm } from "forge-std/src/Vm.sol";
import { IEtnaStakingRegistry } from "src/layer1/etna/iface/IEtnaStakingRegistry.sol";
import { LibCometVote } from "src/layer1/etna/libs/LibCometVote.sol";
import { LibEntriesTree } from "src/layer1/etna/libs/LibEntriesTree.sol";
import { LibEtnaKeys } from "src/layer1/etna/libs/LibEtnaKeys.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";

/// @dev Every test starts at L1 block 30 with bond 0 registered by Alice with `MIN_STAKE` (active
/// from block 40, no exit) and an initialized mock Inbox at generation 0 and snapshot 0. Bob
/// reports unless a test says otherwise.
contract EtnaStakingRegistrySlashTest is EtnaStakingRegistryTestBase {
    /// @dev Consensus private keys.
    uint256 private constant _CK_A = 0xC0A;
    uint256 private constant _CK_B = 0xC0B;

    /// @dev The `exitEffectiveL1` of an entry with no exit set.
    uint48 private constant _NO_EXIT = type(uint48).max;

    /// @dev Bond 0's registration block and the exit an immediate request gives it.
    uint256 private constant _REGISTERED_AT = 30;
    uint48 private constant _EXIT = 60;

    /// @dev 1000 bps of `MIN_STAKE` (1000 ether) to the reporter, the rest to the sink.
    uint256 private constant _BOUNTY = 100 ether;
    uint256 private constant _TO_SINK = 900 ether;

    /// @dev The height and round of the votes `_vote` builds.
    uint64 private constant _HEIGHT = 1000;
    uint32 private constant _ROUND = 3;

    /// @dev Two block hashes; `_vote` gives each a one-part part set header.
    bytes32 private constant _BLOCK_A = keccak256("block a");
    bytes32 private constant _BLOCK_B = keccak256("block b");

    /// @dev 0001-01-01T00:00:00Z and 10000-01-01T00:00:00Z: CometBFT's Timestamp range is
    /// [_MIN_SECONDS, _END_SECONDS) (C7).
    int64 private constant _MIN_SECONDS = -62_135_596_800;
    int64 private constant _END_SECONDS = 253_402_300_800;

    /// @dev The vote fields `_withField` sets.
    uint256 private constant _FIELD_TYPE = 0;
    uint256 private constant _FIELD_HEIGHT = 1;
    uint256 private constant _FIELD_ROUND = 2;
    uint256 private constant _FIELD_SECONDS = 3;
    uint256 private constant _FIELD_NANOS = 4;

    function setUp() public override {
        super.setUp();
        mockInbox.setInitialized(true);
        vm.roll(_REGISTERED_AT);
        assertEq(_register(Alice, _CK_A), 0, "bond 0");
    }

    // ---------------------------------------------------------------
    // Slashing
    // ---------------------------------------------------------------

    /// @dev Bob reports Alice's double sign at block 50: the whole stake goes, 1000 bps (100
    /// ether) to Bob and 900 ether to the sink. The entry keeps its key and activation, its exit
    /// moves from none to min(none, 50) = 50, and block 50's checkpoint is appended over the new
    /// leaf before any stake moves. A landed committee covering block 50 then lets anyone confirm
    /// the exit and, after the delay, release the slot without payment (Lean
    /// `double_sign_then_release`).
    function test_slashDoubleSign_SlashesWholeStakeAndPaysBounty() external {
        (IEtnaStakingRegistry.Vote memory a, IEtnaStakingRegistry.Vote memory b) = _conflict(_CK_A);
        IEtnaStakingRegistry.Entry memory expected = registry.entryAt(0);
        assertEq(expected.effStake, MIN_STAKE, "staked");
        assertEq(expected.exitEffectiveL1, _NO_EXIT, "no exit");
        expected.effStake = 0;
        expected.exitEffectiveL1 = 50;
        bytes32 leaf = LibEntriesTree.leaf(0, expected);
        vm.roll(50);

        vm.expectEmit(address(registry));
        emit IEtnaStakingRegistry.CheckpointWritten(1, 50, 1, leaf);
        vm.expectEmit(address(token));
        emit IERC20.Transfer(address(registry), Bob, _BOUNTY);
        vm.expectEmit(address(token));
        emit IERC20.Transfer(address(registry), SLASH_SINK, _TO_SINK);
        vm.expectEmit(address(registry));
        emit IEtnaStakingRegistry.DoubleSignSlashed(
            0, Bob, MIN_STAKE, _BOUNTY, 0, _HEIGHT, _ROUND, 2
        );
        vm.prank(Bob);
        registry.slashDoubleSign(0, a, b);

        _assertEntry(0, expected);
        assertEq(token.balanceOf(Bob), _BOUNTY, "bounty to the reporter");
        assertEq(token.balanceOf(SLASH_SINK), _TO_SINK, "rest to the sink");
        assertEq(token.balanceOf(address(registry)), 0, "registry empty");
        assertEq(token.balanceOf(Alice), 0, "nothing to the owner");
        assertEq(registry.entriesRoot(), leaf, "root");
        assertEq(registry.checkpointCount(), 2, "checkpoint appended");
        _assertCheckpoint(1, 50, 1, leaf);
        assertEq(registry.ownerOf(0), Alice, "owner kept");
        assertEq(registry.exitConfirmedAtL1(0), 0, "not confirmed");
        assertTrue(registry.keyUsed(vm.addr(_CK_A)), "key used");

        vm.expectRevert(IEtnaStakingRegistry.ExitNotCovered.selector);
        registry.confirmExit(0);
        mockInbox.setActiveCommitteeSnapshot(50);
        vm.prank(Carol);
        registry.confirmExit(0);
        vm.roll(50 + WITHDRAWAL_DELAY);
        vm.prank(Carol);
        registry.withdraw(0, Carol);

        IEtnaStakingRegistry.Entry memory zero;
        _assertEntry(0, zero);
        assertEq(registry.freeSlotCount(), 1, "slot freed");
        assertEq(token.balanceOf(Carol), 0, "nothing to the releaser");
        assertEq(token.balanceOf(Bob) + token.balanceOf(SLASH_SINK), MIN_STAKE, "paid once");
    }

    /// @dev A nil precommit and a precommit for a block in the same round have different block
    /// ids, so together they are a double sign, in either order (C7).
    function test_slashDoubleSign_NilAgainstNonNilIsDoubleSign() external {
        IEtnaStakingRegistry.Vote memory forBlock = _signed(_CK_A, _vote(_BLOCK_A, 0));
        IEtnaStakingRegistry.Vote memory nil = _signed(_CK_A, _vote(0, 0));
        assertTrue(LibCometVote.isNil(nil), "nil");
        assertFalse(LibCometVote.isNil(forBlock), "not nil");

        uint256 snapshot = vm.snapshotState();
        _slash(0, forBlock, nil);
        assertEq(registry.entryAt(0).effStake, 0, "block, nil");
        vm.revertToState(snapshot);

        _slash(0, nil, forBlock);
        assertEq(registry.entryAt(0).effStake, 0, "nil, block");
    }

    /// @dev A block id is its hash and its part set header, so two votes for the same hash with
    /// a different part set total or part set hash conflict (CometBFT compares the whole block
    /// id).
    function test_slashDoubleSign_SameHashWithOtherPartSetHeaderIsDoubleSign() external {
        IEtnaStakingRegistry.Vote memory a = _signed(_CK_A, _vote(_BLOCK_A, 0));

        IEtnaStakingRegistry.Vote memory b = _vote(_BLOCK_A, 0);
        b.partsTotal = 2;
        uint256 snapshot = vm.snapshotState();
        _slash(0, a, _signed(_CK_A, b));
        assertEq(registry.entryAt(0).effStake, 0, "other part set total");
        vm.revertToState(snapshot);

        b = _vote(_BLOCK_A, 0);
        b.partsHash = keccak256("other parts");
        _slash(0, a, _signed(_CK_A, b));
        assertEq(registry.entryAt(0).effStake, 0, "other part set hash");
    }

    /// @dev After recoveries to generation 2, evidence from generations 0 and 1, each signed
    /// under its own generation's chain id, still slashes. The chain id comes from the votes'
    /// generation, not the current one: generation-0 votes signed under generation 2's chain id
    /// do not verify.
    function test_slashDoubleSign_AcceptsHistoricalGeneration() external {
        mockInbox.setRecoveryGeneration(2);

        for (uint48 generation; generation < 2; ++generation) {
            uint256 snapshot = vm.snapshotState();
            _slash(
                0,
                _signed(_CK_A, _vote(_BLOCK_A, generation)),
                _signed(_CK_A, _vote(_BLOCK_B, generation))
            );
            assertEq(registry.entryAt(0).effStake, 0, "historical generation slashes");
            vm.revertToState(snapshot);
        }

        bytes memory currentId = _deploymentChainId(2);
        IEtnaStakingRegistry.Vote memory a =
            EtnaTestKeys.signVote(_CK_A, _vote(_BLOCK_A, 0), currentId);
        IEtnaStakingRegistry.Vote memory b =
            EtnaTestKeys.signVote(_CK_A, _vote(_BLOCK_B, 0), currentId);
        _assertSlashReverts(0, a, b, IEtnaStakingRegistry.InvalidSignature.selector, "other id");
    }

    /// @dev Alice's exit (block 60) is confirmed at block 100 when Bob reports her double sign at
    /// block 110. The stake goes, the exit stays at min(60, 110) = 60 and the confirmation stays
    /// at 100, so the slash neither restarts nor skips the withdrawal delay. At block 129 the
    /// release is still early; at block 130 Carol, who is not the owner, releases the slot and no
    /// TAIKO moves (spec 4.1: a slashed entry is released by anyone without payment).
    function test_slashDoubleSign_KeepsExistingConfirmationAndAllowsAnyoneToRelease() external {
        vm.prank(Alice);
        registry.requestExit(0);
        mockInbox.setActiveCommitteeSnapshot(_EXIT);
        vm.roll(100);
        registry.confirmExit(0);

        vm.roll(110);
        (IEtnaStakingRegistry.Vote memory a, IEtnaStakingRegistry.Vote memory b) = _conflict(_CK_A);
        _slash(0, a, b);
        IEtnaStakingRegistry.Entry memory entry = registry.entryAt(0);
        assertEq(entry.effStake, 0, "slashed");
        assertEq(entry.exitEffectiveL1, _EXIT, "earlier exit kept");
        assertEq(registry.exitConfirmedAtL1(0), 100, "confirmation kept");
        assertEq(token.balanceOf(address(registry)), 0, "stake paid out by the slash");

        vm.roll(129);
        _assertWithdrawReverts(Carol, IEtnaStakingRegistry.WithdrawalNotReady.selector, "early");

        vm.roll(130);
        IEtnaStakingRegistry.Entry memory zero;
        bytes32 releasedLeaf = LibEntriesTree.leaf(0, zero);
        vm.expectEmit(address(registry));
        emit IEtnaStakingRegistry.CheckpointWritten(2, 130, 1, releasedLeaf);
        vm.expectEmit(address(registry));
        emit IEtnaStakingRegistry.StakeWithdrawn(0, Carol, 0);
        vm.recordLogs();
        vm.prank(Carol);
        registry.withdraw(0, Carol);

        Vm.Log[] memory logs = vm.getRecordedLogs();
        for (uint256 i; i < logs.length; ++i) {
            assertTrue(logs[i].emitter != address(token), "no TAIKO transfer");
        }
        assertEq(token.balanceOf(Carol), 0, "nothing to the releaser");
        assertEq(token.balanceOf(Alice), 0, "nothing to the owner");
        assertEq(token.balanceOf(Bob), _BOUNTY, "bounty");
        assertEq(token.balanceOf(SLASH_SINK), _TO_SINK, "sink");
        _assertEntry(0, zero);
        assertEq(registry.ownerOf(0), address(0), "owner cleared");
        assertEq(registry.exitConfirmedAtL1(0), 0, "confirmation cleared");
        assertEq(registry.freeSlotCount(), 1, "slot freed");
        assertEq(registry.entriesRoot(), releasedLeaf, "root");
    }

    /// @dev A slash neither confirms the exit nor skips the delay (Lean `zero_stake_still_waits`).
    /// Alice's exit (block 60) is unconfirmed when Bob reports at block 45, which moves it to
    /// min(60, 45) = 45. However long after, nobody can withdraw until a landed committee covers
    /// block 45, the exit is confirmed (block 10,000) and the full delay has passed from there
    /// (block 10,030); then anyone releases it, to any recipient.
    function test_slashDoubleSign_UnconfirmedSlashedBondStillWaits() external {
        vm.prank(Alice);
        registry.requestExit(0);
        vm.roll(45);
        (IEtnaStakingRegistry.Vote memory a, IEtnaStakingRegistry.Vote memory b) = _conflict(_CK_A);
        _slash(0, a, b);
        assertEq(registry.entryAt(0).exitEffectiveL1, 45, "exit moved earlier");
        assertEq(registry.exitConfirmedAtL1(0), 0, "not confirmed");

        vm.roll(10_000);
        _assertWithdrawReverts(Carol, IEtnaStakingRegistry.ExitNotConfirmed.selector, "anyone");
        _assertWithdrawReverts(Alice, IEtnaStakingRegistry.ExitNotConfirmed.selector, "owner");

        mockInbox.setActiveCommitteeSnapshot(44);
        vm.expectRevert(IEtnaStakingRegistry.ExitNotCovered.selector);
        registry.confirmExit(0);
        mockInbox.setActiveCommitteeSnapshot(45);
        registry.confirmExit(0);
        assertEq(registry.exitConfirmedAtL1(0), 10_000, "confirmed");

        vm.roll(10_000 + WITHDRAWAL_DELAY - 1);
        _assertWithdrawReverts(Carol, IEtnaStakingRegistry.WithdrawalNotReady.selector, "early");
        vm.roll(10_000 + WITHDRAWAL_DELAY);
        // Nothing is paid, so any recipient will do, even the zero address.
        vm.expectEmit(address(registry));
        emit IEtnaStakingRegistry.StakeWithdrawn(0, address(0), 0);
        vm.prank(Carol);
        registry.withdraw(0, address(0));
        assertEq(registry.freeSlotCount(), 1, "slot freed");
        assertEq(token.balanceOf(Carol), 0, "nothing paid");
    }

    /// @dev The vector deployment (L1 chain 1, L2 chain 167001, Inbox 0x1111…) with the vector key
    /// registered as bond 0, the Inbox at each pair's `current_generation`, and the vector
    /// signatures used as given. Every `votes.pairs` item with `double_sign` slashes the whole
    /// stake; every other pair reverts with the error of its reason. A bond is slashed once and a
    /// key registers once, so each pair runs from the same snapshot.
    function test_slashDoubleSign_MatchesCometBftVectorPairs() external {
        string memory j = LibEtnaVectors.load();
        address inbox = LibEtnaVectors.addressAt(j, ".deployment.inbox");
        assertEq(inbox, address(0x1111111111111111111111111111111111111111), "vector inbox");
        vm.etch(inbox, address(new MockEtnaInbox()).code);
        MockEtnaInbox vectorInbox = MockEtnaInbox(inbox);
        vectorInbox.setInitialized(true);
        vm.chainId(LibEtnaVectors.uintAt(j, ".deployment.l1_chain_id"));
        assertEq(block.chainid, 1, "L1 chain id");
        assertEq(LibEtnaVectors.uintAt(j, ".deployment.l2_chain_id"), L2_CHAIN_ID, "L2 chain id");
        registry = _deployRegistry(inbox);

        uint256 pk = LibEtnaVectors.uintAt(j, ".votes.key.private_key");
        assertEq(EtnaTestKeys.publicKey(pk), LibEtnaVectors.bytesAt(j, ".votes.key.public_key"));
        assertEq(_register(Alice, pk), 0, "bond 0");
        assertTrue(registry.keyUsed(LibEtnaVectors.addressAt(j, ".votes.key.signer")), "key");

        string[] memory names = _caseNames(j);
        uint256 n = LibEtnaVectors.lengthAt(j, ".votes.pairs");
        assertEq(n, 14, "pairs");
        uint256 slashed;
        for (uint256 i; i < n; ++i) {
            uint256 snapshot = vm.snapshotState();
            if (_checkVectorPair(j, names, vectorInbox, i)) ++slashed;
            vm.revertToState(snapshot);
        }
        assertEq(slashed, 6, "double-sign pairs");
    }

    // ---------------------------------------------------------------
    // Rejected evidence
    // ---------------------------------------------------------------

    /// @dev Two signatures for the same block id are not a double sign, whatever their
    /// timestamps (CometBFT re-signs a vote with a later timestamp); nor are two nil votes or one
    /// vote submitted twice.
    function test_slashDoubleSign_RevertWhen_SameBlockId() external {
        bytes4 notDoubleSign = IEtnaStakingRegistry.NotDoubleSign.selector;
        IEtnaStakingRegistry.Vote memory a = _signed(_CK_A, _vote(_BLOCK_A, 0));
        IEtnaStakingRegistry.Vote memory late = _vote(_BLOCK_A, 0);
        late.timestampSeconds += 1;
        late.timestampNanos = 0;
        late = _signed(_CK_A, late);
        _assertSlashReverts(0, a, late, notDoubleSign, "later timestamp");
        _assertSlashReverts(0, a, a, notDoubleSign, "same vote twice");

        IEtnaStakingRegistry.Vote memory nil = _signed(_CK_A, _vote(0, 0));
        IEtnaStakingRegistry.Vote memory lateNil = _vote(0, 0);
        lateNil.timestampSeconds += 1;
        lateNil = _signed(_CK_A, lateNil);
        _assertSlashReverts(0, nil, lateNil, notDoubleSign, "two nil votes");
        assertEq(registry.entryAt(0).effStake, MIN_STAKE, "not slashed");
    }

    /// @dev Conflicting block ids in different rounds, types, heights or generations are not a
    /// same-round double sign. Each vote is signed by the bond's key under its own generation's
    /// chain id, and the recovery generation (1) covers both. The check precedes the generation,
    /// bond and signature checks: a pair with one vote in a future generation, and an unsigned
    /// pair for an unknown bond, still revert `NotDoubleSign`.
    function test_slashDoubleSign_RevertWhen_DifferentRoundTypeHeightOrGeneration() external {
        bytes4 notDoubleSign = IEtnaStakingRegistry.NotDoubleSign.selector;
        mockInbox.setRecoveryGeneration(1);
        IEtnaStakingRegistry.Vote memory a = _signed(_CK_A, _vote(_BLOCK_A, 0));

        IEtnaStakingRegistry.Vote memory b = _vote(_BLOCK_B, 0);
        b.round = _ROUND + 1;
        _assertSlashReverts(0, a, _signed(_CK_A, b), notDoubleSign, "round");
        b = _vote(_BLOCK_B, 0);
        b.voteType = 1;
        _assertSlashReverts(0, a, _signed(_CK_A, b), notDoubleSign, "type");
        b = _vote(_BLOCK_B, 0);
        b.height = _HEIGHT + 1;
        _assertSlashReverts(0, a, _signed(_CK_A, b), notDoubleSign, "height");
        b = _signed(_CK_A, _vote(_BLOCK_B, 1));
        _assertSlashReverts(0, a, b, notDoubleSign, "generation");
        _assertSlashReverts(0, b, a, notDoubleSign, "generation, swapped");

        b = _signed(_CK_A, _vote(_BLOCK_B, 2));
        _assertSlashReverts(0, b, a, notDoubleSign, "before the generation check");
        _assertSlashReverts(0, a, b, notDoubleSign, "before the generation check, swapped");
        IEtnaStakingRegistry.Vote memory unsignedA = _vote(_BLOCK_A, 0);
        IEtnaStakingRegistry.Vote memory unsignedB = _vote(_BLOCK_B, 0);
        unsignedB.round = _ROUND + 1;
        _assertSlashReverts(7, unsignedA, unsignedB, notDoubleSign, "before bond and signatures");
        assertEq(registry.entryAt(0).effStake, MIN_STAKE, "not slashed");
    }

    /// @dev Evidence signed under a generation above the Inbox's recovery generation is rejected
    /// before the bond and the signatures are read; at the recovery generation itself it slashes.
    function test_slashDoubleSign_RevertWhen_FutureGeneration() external {
        bytes4 futureGeneration = IEtnaStakingRegistry.FutureGeneration.selector;
        IEtnaStakingRegistry.Vote memory a = _signed(_CK_A, _vote(_BLOCK_A, 1));
        IEtnaStakingRegistry.Vote memory b = _signed(_CK_A, _vote(_BLOCK_B, 1));
        _assertSlashReverts(0, a, b, futureGeneration, "generation 1 at generation 0");

        _assertSlashReverts(
            7, _vote(_BLOCK_A, 1), _vote(_BLOCK_B, 1), futureGeneration, "before bond, signatures"
        );
        uint48 maxGeneration = type(uint48).max;
        _assertSlashReverts(
            0,
            _signed(_CK_A, _vote(_BLOCK_A, maxGeneration)),
            _signed(_CK_A, _vote(_BLOCK_B, maxGeneration)),
            futureGeneration,
            "generation 2^48 - 1"
        );

        mockInbox.setRecoveryGeneration(1);
        _slash(0, a, b);
        assertEq(registry.entryAt(0).effStake, 0, "the current generation slashes");
    }

    /// @dev Until the Inbox is initialized no evidence is accepted, checked before anything else
    /// (out-of-range votes for an unknown bond); afterwards the same evidence slashes.
    function test_slashDoubleSign_RevertWhen_InboxNotInitialized() external {
        bytes4 notInitialized = IEtnaStakingRegistry.InboxNotInitialized.selector;
        mockInbox.setInitialized(false);
        (IEtnaStakingRegistry.Vote memory a, IEtnaStakingRegistry.Vote memory b) = _conflict(_CK_A);
        _assertSlashReverts(0, a, b, notInitialized, "valid evidence");

        IEtnaStakingRegistry.Vote memory bad = _vote(_BLOCK_A, 0);
        bad.voteType = 0;
        bad.signature = "";
        _assertSlashReverts(7, bad, bad, notInitialized, "checked first");

        mockInbox.setInitialized(true);
        _slash(0, a, b);
        assertEq(registry.entryAt(0).effStake, 0, "slashed once initialized");
    }

    /// @dev The registry derives the chain id from its own L1 chain id, L2 chain id and Inbox.
    /// Votes the bond's key signed for another Inbox, another L1 chain or another L2 chain are not
    /// evidence here, even when only one of the two is foreign. Each foreign pair is valid
    /// evidence at the deployment it was signed for: a registry fixed to the other Inbox, a
    /// registry with the other L2 chain id, and this registry on the other L1 chain.
    function test_slashDoubleSign_RevertWhen_SignedForAnotherDeployment() external {
        bytes4 invalidSignature = IEtnaStakingRegistry.InvalidSignature.selector;
        MockEtnaInbox otherInbox = new MockEtnaInbox();
        otherInbox.setInitialized(true);
        bytes[3] memory foreignIds = [
            _chainIdOf(block.chainid, L2_CHAIN_ID, address(otherInbox), 0),
            _chainIdOf(block.chainid, L2_CHAIN_ID + 1, address(mockInbox), 0),
            _chainIdOf(block.chainid + 1, L2_CHAIN_ID, address(mockInbox), 0)
        ];
        string[3] memory labels = ["other inbox", "other L2 chain", "other L1 chain"];
        IEtnaStakingRegistry.Vote memory ownA = _signed(_CK_A, _vote(_BLOCK_A, 0));

        for (uint256 i; i < 3; ++i) {
            IEtnaStakingRegistry.Vote memory a =
                EtnaTestKeys.signVote(_CK_A, _vote(_BLOCK_A, 0), foreignIds[i]);
            IEtnaStakingRegistry.Vote memory b =
                EtnaTestKeys.signVote(_CK_A, _vote(_BLOCK_B, 0), foreignIds[i]);
            _assertSlashReverts(0, a, b, invalidSignature, labels[i]);
            _assertSlashReverts(0, ownA, b, invalidSignature, string.concat(labels[i], ": one"));
        }
        assertEq(registry.entryAt(0).effStake, MIN_STAKE, "not slashed");

        uint256 snapshot = vm.snapshotState();
        registry = _deployRegistry(address(otherInbox));
        assertEq(_register(Alice, _CK_A), 0, "bond 0 at the other inbox's registry");
        _assertForeignPairSlashes(foreignIds[0], labels[0]);
        vm.revertToState(snapshot);

        snapshot = vm.snapshotState();
        IEtnaStakingRegistry.Config memory config =
            _registryConfig(address(token), address(mockInbox));
        config.l2ChainId = L2_CHAIN_ID + 1;
        registry = _deployRegistry(config);
        assertEq(_register(Alice, _CK_A), 0, "bond 0 at the other L2 chain's registry");
        _assertForeignPairSlashes(foreignIds[1], labels[1]);
        vm.revertToState(snapshot);

        vm.chainId(block.chainid + 1);
        _assertForeignPairSlashes(foreignIds[2], labels[2]);
    }

    /// @dev Evidence must be signed by the bond's own key. Another validator's double sign does
    /// not slash bond 0, nor does a pair with one vote from each key; that validator's evidence
    /// slashes its own bond only.
    function test_slashDoubleSign_RevertWhen_SignerIsAnotherKey() external {
        bytes4 invalidSignature = IEtnaStakingRegistry.InvalidSignature.selector;
        assertEq(_register(Bob, _CK_B), 1, "bond 1");
        (IEtnaStakingRegistry.Vote memory aA, IEtnaStakingRegistry.Vote memory bA) =
            _conflict(_CK_A);
        (IEtnaStakingRegistry.Vote memory aB, IEtnaStakingRegistry.Vote memory bB) =
            _conflict(_CK_B);

        _assertSlashReverts(0, aB, bB, invalidSignature, "other key");
        _assertSlashReverts(0, aA, bB, invalidSignature, "second vote from another key");
        _assertSlashReverts(0, aB, bA, invalidSignature, "first vote from another key");
        _assertSlashReverts(1, aA, bA, invalidSignature, "bond 0's key against bond 1");

        _slash(1, aB, bB);
        assertEq(registry.entryAt(1).effStake, 0, "bond 1 slashed");
        assertEq(registry.entryAt(0).effStake, MIN_STAKE, "bond 0 untouched");
    }

    /// @dev A 65-byte signature passes the range check; a V outside {0, 1} or a high S is then
    /// rejected by signature recovery (`InvalidSignature`), in either vote. The high-S form is the
    /// same signature's other half, which `ecrecover` alone accepts; the low-S form slashes.
    function test_slashDoubleSign_RevertWhen_SignatureHasBadVOrHighS() external {
        bytes4 invalidSignature = IEtnaStakingRegistry.InvalidSignature.selector;
        (IEtnaStakingRegistry.Vote memory a, IEtnaStakingRegistry.Vote memory b) = _conflict(_CK_A);
        bytes memory goodB = b.signature;
        (bytes32 r, bytes32 s, uint8 v) = _split(goodB);
        bytes32 highS = bytes32(LibEtnaKeys.N - uint256(s));
        bytes32 digest = keccak256(LibCometVote.signBytes(b, _deploymentChainId(0)));
        assertEq(ecrecover(digest, 28 - v, r, highS), vm.addr(_CK_A), "high S recovers the key");

        b.signature = abi.encodePacked(r, s, uint8(2));
        _assertSlashReverts(0, a, b, invalidSignature, "V = 2");
        b.signature = abi.encodePacked(r, s, uint8(3));
        _assertSlashReverts(0, a, b, invalidSignature, "V = 3");
        b.signature = abi.encodePacked(r, s, v + 27);
        _assertSlashReverts(0, a, b, invalidSignature, "V = 27 or 28");
        b.signature = abi.encodePacked(r, highS, 1 - v);
        _assertSlashReverts(0, a, b, invalidSignature, "high S");
        _assertSlashReverts(0, b, a, invalidSignature, "high S, first vote");
        b.signature = abi.encodePacked(bytes32(0), s, v);
        _assertSlashReverts(0, a, b, invalidSignature, "R = 0");

        b.signature = goodB;
        _slash(0, a, b);
        assertEq(registry.entryAt(0).effStake, 0, "low S slashes");
    }

    /// @dev A bond is slashed once: the same evidence again, or new evidence, finds no stake.
    /// The stake check precedes the signatures.
    function test_slashDoubleSign_RevertWhen_NothingToSlash() external {
        bytes4 nothingToSlash = IEtnaStakingRegistry.NothingToSlash.selector;
        (IEtnaStakingRegistry.Vote memory a, IEtnaStakingRegistry.Vote memory b) = _conflict(_CK_A);
        _slash(0, a, b);
        uint256 checkpoints = registry.checkpointCount();

        _assertSlashReverts(0, a, b, nothingToSlash, "same evidence");
        IEtnaStakingRegistry.Vote memory c = _vote(_BLOCK_A, 0);
        IEtnaStakingRegistry.Vote memory d = _vote(_BLOCK_B, 0);
        c.round = _ROUND + 1;
        d.round = _ROUND + 1;
        _assertSlashReverts(0, _signed(_CK_A, c), _signed(_CK_A, d), nothingToSlash, "new evidence");
        _assertSlashReverts(
            0, _vote(_BLOCK_A, 0), _vote(_BLOCK_B, 0), nothingToSlash, "before signatures"
        );
        assertEq(token.balanceOf(Bob), _BOUNTY, "bounty paid once");
        assertEq(registry.checkpointCount(), checkpoints, "no checkpoint");
    }

    /// @dev A withdrawn bond can no longer be slashed, checked before the signatures. Once
    /// another key reuses the slot, the old key's evidence does not match the new occupant.
    function test_slashDoubleSign_RevertWhen_SlotReleased() external {
        bytes4 slotReleased = IEtnaStakingRegistry.SlotReleased.selector;
        (IEtnaStakingRegistry.Vote memory a, IEtnaStakingRegistry.Vote memory b) = _conflict(_CK_A);
        _release(0);

        _assertSlashReverts(0, a, b, slotReleased, "released");
        _assertSlashReverts(
            0, _vote(_BLOCK_A, 0), _vote(_BLOCK_B, 0), slotReleased, "before signatures"
        );

        assertEq(_register(Bob, _CK_B), 0, "slot reused");
        _assertSlashReverts(
            0, a, b, IEtnaStakingRegistry.InvalidSignature.selector, "previous occupant's key"
        );
        assertEq(registry.entryAt(0).effStake, MIN_STAKE, "new occupant untouched");
    }

    /// @dev A bond id past the used slots, checked before the signatures.
    function test_slashDoubleSign_RevertWhen_UnknownBond() external {
        bytes4 unknownBond = IEtnaStakingRegistry.UnknownBond.selector;
        (IEtnaStakingRegistry.Vote memory a, IEtnaStakingRegistry.Vote memory b) = _conflict(_CK_A);
        _assertSlashReverts(1, a, b, unknownBond, "next slot");
        _assertSlashReverts(type(uint256).max, a, b, unknownBond, "max");
        _assertSlashReverts(
            1, _vote(_BLOCK_A, 0), _vote(_BLOCK_B, 0), unknownBond, "before signatures"
        );
    }

    /// @dev Each C7 bound, applied to both votes of a signed conflicting pair: an accepted value
    /// slashes and a rejected one reverts `InvalidVote` when either vote carries it, before the
    /// pair checks. Timestamp seconds are the int64 two's-complement pattern, accepted in
    /// [-62,135,596,800, 253,402,300,800). The signature must be exactly 65 bytes; its V and S are
    /// left to recovery (`test_slashDoubleSign_RevertWhen_SignatureHasBadVOrHighS`).
    function test_slashDoubleSign_RevertWhen_VoteOutOfRange() external {
        _assertBound(_FIELD_TYPE, 0, false, "type 0");
        _assertBound(_FIELD_TYPE, 1, true, "prevote");
        _assertBound(_FIELD_TYPE, 2, true, "precommit");
        _assertBound(_FIELD_TYPE, 3, false, "type 3");

        _assertBound(_FIELD_HEIGHT, 0, false, "height 0");
        _assertBound(_FIELD_HEIGHT, 1, true, "height 1");
        _assertBound(_FIELD_HEIGHT, 2 ** 63 - 1, true, "height 2^63 - 1");
        _assertBound(_FIELD_HEIGHT, 2 ** 63, false, "height 2^63");

        _assertBound(_FIELD_ROUND, 0, true, "round 0");
        _assertBound(_FIELD_ROUND, 2 ** 31 - 1, true, "round 2^31 - 1");
        _assertBound(_FIELD_ROUND, 2 ** 31, false, "round 2^31");

        _assertBound(_FIELD_SECONDS, uint64(_MIN_SECONDS - 1), false, "seconds min - 1");
        _assertBound(_FIELD_SECONDS, uint64(_MIN_SECONDS), true, "seconds min");
        _assertBound(_FIELD_SECONDS, type(uint64).max, true, "seconds -1");
        _assertBound(_FIELD_SECONDS, uint64(_END_SECONDS - 1), true, "seconds max - 1");
        _assertBound(_FIELD_SECONDS, uint64(_END_SECONDS), false, "seconds max");
        _assertBound(_FIELD_SECONDS, uint64(type(int64).max), false, "seconds int64 max");
        _assertBound(_FIELD_SECONDS, uint64(type(int64).min), false, "seconds int64 min");

        _assertBound(_FIELD_NANOS, 1e9 - 1, true, "nanos 10^9 - 1");
        _assertBound(_FIELD_NANOS, 1e9, false, "nanos 10^9");

        bytes4 invalidVote = IEtnaStakingRegistry.InvalidVote.selector;
        (IEtnaStakingRegistry.Vote memory a, IEtnaStakingRegistry.Vote memory b) = _conflict(_CK_A);
        bytes memory sig = b.signature;
        bytes[3] memory badLengths = [bytes(""), _prefix(sig, 64), bytes.concat(sig, hex"00")];
        for (uint256 i; i < 3; ++i) {
            b.signature = badLengths[i];
            string memory label =
                string.concat("signature of ", vm.toString(badLengths[i].length), " bytes");
            _assertSlashReverts(0, a, b, invalidVote, string.concat(label, ", second vote"));
            _assertSlashReverts(0, b, a, invalidVote, string.concat(label, ", first vote"));
        }
    }

    /// @dev The lock taken by `slashDoubleSign` stops a token that re-enters it from `transfer`.
    /// The slash is written before any stake moves: a `confirmExit` re-entered from the bounty
    /// transfer already sees the exit the slash set.
    function test_slashDoubleSign_RevertWhen_TokenReenters() external {
        ReentrantERC20 reentrant = new ReentrantERC20();
        registry = _deployRegistry(address(reentrant), address(mockInbox));
        reentrant.mint(Alice, MIN_STAKE);
        vm.prank(Alice);
        reentrant.approve(address(registry), MIN_STAKE);
        bytes memory publicKey = EtnaTestKeys.publicKey(_CK_A);
        bytes memory pop = EtnaTestKeys.popSig(_CK_A, registry, Alice);
        vm.prank(Alice);
        registry.register(publicKey, MIN_STAKE, pop);
        (IEtnaStakingRegistry.Vote memory a, IEtnaStakingRegistry.Vote memory b) = _conflict(_CK_A);

        reentrant.armReentry(address(registry), abi.encodeCall(registry.slashDoubleSign, (0, a, b)));
        _assertSlashReverts(0, a, b, EssentialContract.REENTRANT_CALL.selector, "re-entered");
        assertEq(registry.entryAt(0).effStake, MIN_STAKE, "not slashed");

        mockInbox.setActiveCommitteeSnapshot(block.number);
        reentrant.armReentry(address(registry), abi.encodeCall(registry.confirmExit, (0)));
        _slash(0, a, b);
        assertEq(registry.exitConfirmedAtL1(0), block.number, "confirmed during the bounty");
        assertEq(reentrant.balanceOf(Bob), _BOUNTY, "bounty");
        assertEq(reentrant.balanceOf(SLASH_SINK), _TO_SINK, "sink");
    }

    // ---------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------

    /// @dev An unsigned precommit at `_HEIGHT`, `_ROUND` and `_generation`, timestamped
    /// 1,700,000,000.000000123, for block `_blockHash` with a one-part part set header, or nil
    /// when `_blockHash` is zero. Its signature is 65 zero bytes, in range but invalid.
    function _vote(
        bytes32 _blockHash,
        uint48 _generation
    )
        private
        pure
        returns (IEtnaStakingRegistry.Vote memory v_)
    {
        v_.voteType = 2;
        v_.height = _HEIGHT;
        v_.round = _ROUND;
        if (_blockHash != 0) {
            v_.blockHash = _blockHash;
            v_.partsTotal = 1;
            v_.partsHash = keccak256(abi.encode(_blockHash));
        }
        v_.timestampSeconds = 1_700_000_000;
        v_.timestampNanos = 123;
        v_.generation = _generation;
        v_.signature = new bytes(65);
    }

    /// @dev Two generation-0 precommits for different blocks at the same height and round,
    /// signed by `_pk` for this registry's deployment.
    function _conflict(uint256 _pk)
        private
        view
        returns (IEtnaStakingRegistry.Vote memory a_, IEtnaStakingRegistry.Vote memory b_)
    {
        a_ = _signed(_pk, _vote(_BLOCK_A, 0));
        b_ = _signed(_pk, _vote(_BLOCK_B, 0));
    }

    /// @dev Signs `_v` with `_pk` under the chain id of the deployment (this L1, `L2_CHAIN_ID`,
    /// the mock Inbox) for the vote's generation.
    function _signed(
        uint256 _pk,
        IEtnaStakingRegistry.Vote memory _v
    )
        private
        view
        returns (IEtnaStakingRegistry.Vote memory)
    {
        return EtnaTestKeys.signVote(_pk, _v, _deploymentChainId(_v.generation));
    }

    /// @dev The chain id of the deployment (this L1, `L2_CHAIN_ID`, the mock Inbox) for
    /// `_generation`.
    function _deploymentChainId(uint48 _generation) private view returns (bytes memory) {
        return _chainIdOf(block.chainid, L2_CHAIN_ID, address(mockInbox), _generation);
    }

    function _chainIdOf(
        uint256 _l1ChainId,
        uint256 _l2ChainId,
        address _inbox,
        uint48 _generation
    )
        private
        pure
        returns (bytes memory)
    {
        return LibCometVote.chainId(
            LibCometVote.chainDomain(_l1ChainId, _l2ChainId, _inbox, _generation)
        );
    }

    /// @dev Bob reports a conflicting pair `_CK_A` signed under `_cometChainId` against bond 0 of
    /// the current registry, which must slash it.
    function _assertForeignPairSlashes(bytes memory _cometChainId, string memory _label) private {
        _slash(
            0,
            EtnaTestKeys.signVote(_CK_A, _vote(_BLOCK_A, 0), _cometChainId),
            EtnaTestKeys.signVote(_CK_A, _vote(_BLOCK_B, 0), _cometChainId)
        );
        assertEq(registry.entryAt(0).effStake, 0, string.concat(_label, ": slashed there"));
    }

    /// @dev Bob reports `_a` and `_b` against `_bondId`.
    function _slash(
        uint256 _bondId,
        IEtnaStakingRegistry.Vote memory _a,
        IEtnaStakingRegistry.Vote memory _b
    )
        private
    {
        vm.prank(Bob);
        registry.slashDoubleSign(_bondId, _a, _b);
    }

    function _assertSlashReverts(
        uint256 _bondId,
        IEtnaStakingRegistry.Vote memory _a,
        IEtnaStakingRegistry.Vote memory _b,
        bytes4 _error,
        string memory _label
    )
        private
    {
        vm.prank(Bob);
        try registry.slashDoubleSign(_bondId, _a, _b) {
            assertTrue(false, string.concat(_label, ": slashed"));
        } catch (bytes memory err) {
            assertEq(err, abi.encodeWithSelector(_error), _label);
        }
    }

    function _assertWithdrawReverts(address _caller, bytes4 _error, string memory _label) private {
        vm.prank(_caller);
        try registry.withdraw(0, _caller) {
            assertTrue(false, string.concat(_label, ": withdrew"));
        } catch (bytes memory err) {
            assertEq(err, abi.encodeWithSelector(_error), _label);
        }
    }

    /// @dev Sets field `_field` (a `_FIELD_*` constant) of both votes of a conflicting pair to
    /// `_value` and signs them. An accepted value must slash (from a snapshot); a rejected one
    /// must revert `InvalidVote` when either vote carries it.
    function _assertBound(
        uint256 _field,
        uint256 _value,
        bool _accepted,
        string memory _label
    )
        private
    {
        IEtnaStakingRegistry.Vote memory a =
            _signed(_CK_A, _withField(_vote(_BLOCK_A, 0), _field, _value));
        IEtnaStakingRegistry.Vote memory b =
            _signed(_CK_A, _withField(_vote(_BLOCK_B, 0), _field, _value));
        if (_accepted) {
            uint256 snapshot = vm.snapshotState();
            _slash(0, a, b);
            assertEq(registry.entryAt(0).effStake, 0, _label);
            vm.revertToState(snapshot);
        } else {
            bytes4 invalidVote = IEtnaStakingRegistry.InvalidVote.selector;
            (IEtnaStakingRegistry.Vote memory inRangeA, IEtnaStakingRegistry.Vote memory inRangeB) =
                _conflict(_CK_A);
            _assertSlashReverts(0, a, inRangeB, invalidVote, string.concat(_label, ", first vote"));
            _assertSlashReverts(0, inRangeA, b, invalidVote, string.concat(_label, ", second vote"));
        }
    }

    function _withField(
        IEtnaStakingRegistry.Vote memory _v,
        uint256 _field,
        uint256 _value
    )
        private
        pure
        returns (IEtnaStakingRegistry.Vote memory)
    {
        if (_field == _FIELD_TYPE) _v.voteType = uint8(_value);
        else if (_field == _FIELD_HEIGHT) _v.height = uint64(_value);
        else if (_field == _FIELD_ROUND) _v.round = uint32(_value);
        else if (_field == _FIELD_SECONDS) _v.timestampSeconds = uint64(_value);
        else _v.timestampNanos = uint32(_value);
        return _v;
    }

    /// @dev Sets `_inbox` to the `current_generation` of `votes.pairs` item `_i` and submits its
    /// votes: a `double_sign` pair must slash the whole stake, any other must revert with the
    /// error of its reason.
    /// @return slashed_ Whether the pair is a double sign.
    function _checkVectorPair(
        string memory _j,
        string[] memory _names,
        MockEtnaInbox _inbox,
        uint256 _i
    )
        private
        returns (bool slashed_)
    {
        string memory p = string.concat(".votes.pairs[", vm.toString(_i), "].");
        string memory name = _pairField(_j, p, "name");
        IEtnaStakingRegistry.Vote memory a = _vectorVote(_j, _names, _pairField(_j, p, "a"));
        IEtnaStakingRegistry.Vote memory b = _vectorVote(_j, _names, _pairField(_j, p, "b"));
        _inbox.setRecoveryGeneration(
            uint48(LibEtnaVectors.uintAt(_j, string.concat(p, "current_generation")))
        );

        slashed_ = vm.parseJsonBool(_j, string.concat(p, "double_sign"));
        if (!slashed_) {
            _assertSlashReverts(0, a, b, _errorFor(_pairField(_j, p, "reason")), name);
            return false;
        }
        assertEq(_pairField(_j, p, "reason"), "double_sign", name);
        vm.expectEmit(address(registry));
        emit IEtnaStakingRegistry.DoubleSignSlashed(
            0, Bob, MIN_STAKE, _BOUNTY, a.generation, a.height, a.round, a.voteType
        );
        _slash(0, a, b);
        assertEq(registry.entryAt(0).effStake, 0, name);
        assertEq(token.balanceOf(Bob), _BOUNTY, name);
        assertEq(token.balanceOf(SLASH_SINK), _TO_SINK, name);
    }

    /// @dev The error a non-double-sign `votes.pairs` reason reverts with.
    function _errorFor(string memory _reason) private pure returns (bytes4) {
        bytes32 r = keccak256(bytes(_reason));
        if (
            r == keccak256("same_block_id") || r == keccak256("different_round")
                || r == keccak256("different_type") || r == keccak256("different_height")
                || r == keccak256("different_generation")
        ) return IEtnaStakingRegistry.NotDoubleSign.selector;
        if (r == keccak256("future_generation")) {
            return IEtnaStakingRegistry.FutureGeneration.selector;
        }
        if (r == keccak256("other_deployment")) {
            return IEtnaStakingRegistry.InvalidSignature.selector;
        }
        revert(string.concat("unknown pair reason ", _reason));
    }

    /// @dev The string field `_field` of the `votes.pairs` item at `_p`.
    function _pairField(
        string memory _j,
        string memory _p,
        string memory _field
    )
        private
        pure
        returns (string memory)
    {
        return LibEtnaVectors.stringAt(_j, string.concat(_p, _field));
    }

    /// @dev The names of the `votes.cases` items, in order.
    function _caseNames(string memory _j) private view returns (string[] memory names_) {
        names_ = new string[](LibEtnaVectors.lengthAt(_j, ".votes.cases"));
        for (uint256 i; i < names_.length; ++i) {
            names_[i] = LibEtnaVectors.stringAt(_j, string.concat(_case(i), "name"));
        }
    }

    /// @dev The vote of the `votes.cases` item named `_name`, with its vector signature.
    function _vectorVote(
        string memory _j,
        string[] memory _names,
        string memory _name
    )
        private
        pure
        returns (IEtnaStakingRegistry.Vote memory v_)
    {
        uint256 i;
        while (i < _names.length && keccak256(bytes(_names[i])) != keccak256(bytes(_name))) {
            ++i;
        }
        require(i < _names.length, string.concat("no vote case named ", _name));
        string memory p = _case(i);
        string memory q = string.concat(p, "vote.");
        v_.voteType = uint8(LibEtnaVectors.uintAt(_j, string.concat(q, "voteType")));
        v_.height = uint64(LibEtnaVectors.uintAt(_j, string.concat(q, "height")));
        v_.round = uint32(LibEtnaVectors.uintAt(_j, string.concat(q, "round")));
        v_.blockHash = LibEtnaVectors.bytes32At(_j, string.concat(q, "blockHash"));
        v_.partsTotal = uint32(LibEtnaVectors.uintAt(_j, string.concat(q, "partsTotal")));
        v_.partsHash = LibEtnaVectors.bytes32At(_j, string.concat(q, "partsHash"));
        // The registry takes the int64 seconds as their two's-complement pattern.
        v_.timestampSeconds =
            uint64(LibEtnaVectors.uintAt(_j, string.concat(q, "timestampSecondsU64")));
        v_.timestampNanos = uint32(LibEtnaVectors.uintAt(_j, string.concat(q, "timestampNanos")));
        v_.generation = uint48(LibEtnaVectors.uintAt(_j, string.concat(q, "generation")));
        v_.signature = LibEtnaVectors.bytesAt(_j, string.concat(p, "signature"));
    }

    function _case(uint256 _i) private pure returns (string memory) {
        return string.concat(".votes.cases[", vm.toString(_i), "].");
    }

    /// @dev The first `_n` bytes of `_b`.
    function _prefix(bytes memory _b, uint256 _n) private pure returns (bytes memory out_) {
        out_ = new bytes(_n);
        for (uint256 i; i < _n; ++i) {
            out_[i] = _b[i];
        }
    }
}
