// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EtnaStakingTestBase } from "./EtnaStakingTestBase.sol";
import { EtnaVoteKeys } from "./EtnaVoteKeys.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Vm } from "forge-std/src/Vm.sol";
import { IEtnaStaking } from "src/layer2/etna/iface/IEtnaStaking.sol";
import { LibCometVote } from "src/layer2/etna/libs/LibCometVote.sol";
import { LibEtnaKeys } from "src/shared/etna/LibEtnaKeys.sol";
import { EtnaTestKeys } from "test/shared/etna/EtnaTestKeys.sol";
import { LibEtnaVectors } from "test/shared/etna/LibEtnaVectors.sol";

/// @dev Double-sign slashing. Every test starts at L2 block 30 with bond 0 registered by Alice
/// with `MIN_STAKE` in seat 0 and no exit, before any block-start call, so `lastGeneration()` is
/// 0. Bob reports unless a test says otherwise. Votes are signed under the chain id of the base's
/// deployment: L1 chain 1, L2 chain 167001 and the Inbox at `INBOX`.
contract EtnaStakingSlashTest is EtnaStakingTestBase {
    /// @dev Consensus private keys.
    uint256 private constant _CK_A = 0xC0A;
    uint256 private constant _CK_B = 0xC0B;
    /// @dev A consensus key no bond registers.
    uint256 private constant _CK_UNREGISTERED = 0xC0F;
    /// @dev The keys that fill seats are `_FILLER_KEYS + i`.
    uint256 private constant _FILLER_KEYS = 0x1000;

    /// @dev Bond 0's registration block.
    uint256 private constant _REGISTERED_AT = 30;

    /// @dev 1000 bps of `MIN_STAKE` (7,812,500 ether) to the reporter, the rest to the sink.
    uint256 private constant _BOUNTY = 781_250 ether;
    uint256 private constant _TO_SINK = 7_031_250 ether;

    /// @dev The height and round of the votes `_vote` builds.
    uint64 private constant _HEIGHT = 1000;
    uint32 private constant _ROUND = 3;

    /// @dev Two block hashes; `_vote` gives each a one-part part set header.
    bytes32 private constant _BLOCK_A = keccak256("block a");
    bytes32 private constant _BLOCK_B = keccak256("block b");

    /// @dev The block hash and part set hash of the independently encoded stock votes.
    bytes32 private constant _STOCK_BLOCK_HASH =
        0x1111111111111111111111111111111111111111111111111111111111111111;
    bytes32 private constant _STOCK_PARTS_HASH =
        0x2222222222222222222222222222222222222222222222222222222222222222;

    /// @dev 0001-01-01T00:00:00Z and 10000-01-01T00:00:00Z: CometBFT's Timestamp range is
    /// [_MIN_SECONDS, _END_SECONDS), negative seconds included. The staking contract accepts
    /// seconds outside it too.
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
        vm.roll(_REGISTERED_AT);
        assertEq(_register(_CK_A, Alice, MIN_STAKE), 0, "bond 0");
    }

    // ---------------------------------------------------------------
    // Slashing
    // ---------------------------------------------------------------

    /// @dev Bob reports at block 50. Bond 0 in seat 0 and bond 127 in seat 127, which stakes
    /// 3m + 7 so that its bounty rounds down, each lose their whole stake, get an exit at block
    /// 50 and release their seats. Bond 1, whose exit at block 40 already released seat 1, keeps
    /// that earlier exit. Each time Bob receives floor(stake * 1000 / 10,000) and slashSink the
    /// rest.
    function test_slash_TakesAllPrincipalReleasesSeatAndSplitsBounty() external {
        for (uint256 i = 1; i < 127; ++i) {
            _register(_FILLER_KEYS + i, Carol, MIN_STAKE);
        }
        uint256 lastStake = 3 * MIN_STAKE + 7;
        assertEq(_register(_CK_B, David, lastStake), 127, "bond 127");
        _assertSeatOfBond(127, true, 127, "bond 127 in seat 127");
        vm.roll(40);
        _requestExit(1);
        vm.roll(50);

        _assertSlashTakesAll(0, _CK_A, MIN_STAKE, _BOUNTY, 50);
        _assertSlashTakesAll(127, _CK_B, lastStake, 2_343_750 ether, 50);
        _assertSlashTakesAll(1, _FILLER_KEYS + 1, MIN_STAKE, _BOUNTY, 40);
        assertEq(staking.bondCount(), 128, "no bond issued or removed");
    }

    /// @dev An owner reporting its own signer receives only the bounty, calculated over the
    /// whole stake, the top-up included.
    function test_slashDoubleSign_OwnerMaySelfReport() external {
        _assertSlashPayout(MIN_STAKE, MIN_STAKE / 4, 1000, Alice, MIN_STAKE / 8, MIN_STAKE * 9 / 8);
    }

    /// @dev The signer may also report, independently of the bond's owner.
    function test_slashDoubleSign_SignerMaySelfReport() external {
        _assertSlashPayout(
            MIN_STAKE, MIN_STAKE / 4, 1000, vm.addr(_CK_B), MIN_STAKE / 8, MIN_STAKE * 9 / 8
        );
    }

    /// @dev The fractional bounty goes to the sink instead of rounding up.
    function test_slashDoubleSign_RoundsBountyDown() external {
        _assertSlashPayout(MIN_STAKE + 1, 0, 1000, Bob, MIN_STAKE / 10, MIN_STAKE * 9 / 10 + 1);
    }

    /// @dev Even the highest allowed bounty rate leaves a one-unit slash at the sink.
    function test_slashDoubleSign_OneUnitPaysNoBounty() external {
        _assertSlashPayout(1, 0, 9999, Bob, 0, 1);
    }

    /// @dev A zero bounty rate sends all principal to the sink.
    function test_slashDoubleSign_ZeroBountyPaysAllPrincipalToSink() external {
        _assertSlashPayout(MIN_STAKE + 1, 0, 0, Bob, 0, MIN_STAKE + 1);
    }

    /// @dev A nil precommit and a precommit for a block in the same round have different block
    /// ids, so together they are a double sign, in either order.
    function test_slashDoubleSign_NilAgainstNonNilIsDoubleSign() external {
        IEtnaStaking.Vote memory forBlock = _signed(_CK_A, _vote(_BLOCK_A, 0));
        IEtnaStaking.Vote memory nil = _signed(_CK_A, _vote(0, 0));
        assertTrue(LibCometVote.isNil(nil), "nil");
        assertFalse(LibCometVote.isNil(forBlock), "not nil");

        uint256 snapshot = vm.snapshotState();
        _slash(0, forBlock, nil);
        assertEq(staking.bondAt(0).effStake, 0, "block, nil");
        vm.revertToState(snapshot);

        _slash(0, nil, forBlock);
        assertEq(staking.bondAt(0).effStake, 0, "nil, block");
    }

    /// @dev A block id is its hash and its part set header, so two votes for the same hash with
    /// a different part set total or part set hash conflict (CometBFT compares the whole block
    /// id).
    function test_slashDoubleSign_SameHashWithOtherPartSetHeaderIsDoubleSign() external {
        IEtnaStaking.Vote memory a = _signed(_CK_A, _vote(_BLOCK_A, 0));

        IEtnaStaking.Vote memory b = _vote(_BLOCK_A, 0);
        b.partsTotal = 2;
        uint256 snapshot = vm.snapshotState();
        _slash(0, a, _signed(_CK_A, b));
        assertEq(staking.bondAt(0).effStake, 0, "other part set total");
        vm.revertToState(snapshot);

        b = _vote(_BLOCK_A, 0);
        b.partsHash = abi.encodePacked(keccak256("other parts"));
        _slash(0, a, _signed(_CK_A, b));
        assertEq(staking.bondAt(0).effStake, 0, "other part set hash");
    }

    /// @dev Vote timestamps are not range-checked: a double sign whose two votes carry seconds
    /// 2^63 - 1, long past CometBFT's year 9999, and nanos 2^32 - 1, the int32 -1, which stock
    /// CometBFT would not sign, slashes the whole stake like any other, since only the key
    /// holder can have signed it.
    function test_slashDoubleSign_AcceptsTimestampsOutsideCometBftRange() external {
        IEtnaStaking.Vote memory a = _vote(_BLOCK_A, 0);
        IEtnaStaking.Vote memory b = _vote(_BLOCK_B, 0);
        a.timestampSeconds = uint64(type(int64).max);
        b.timestampSeconds = uint64(type(int64).max);
        a.timestampNanos = type(uint32).max;
        b.timestampNanos = type(uint32).max;
        a = _signed(_CK_A, a);
        b = _signed(_CK_A, b);

        vm.expectEmit(address(staking));
        emit IEtnaStaking.DoubleSignSlashed(0, Bob, MIN_STAKE, _BOUNTY, 0, _HEIGHT, _ROUND, 2);
        vm.expectEmit(address(token));
        emit IERC20.Transfer(address(staking), Bob, _BOUNTY);
        vm.expectEmit(address(token));
        emit IERC20.Transfer(address(staking), SLASH_SINK, _TO_SINK);
        _slash(0, a, b);

        assertEq(staking.bondAt(0).effStake, 0, "stake slashed");
        assertEq(token.balanceOf(Bob), _BOUNTY, "bounty to the reporter");
        assertEq(token.balanceOf(SLASH_SINK), _TO_SINK, "rest to the sink");
        assertEq(token.balanceOf(address(staking)), 0, "staking empty");
    }

    /// @dev After block-start calls stored generation 2, evidence from generations 0 and 1, each
    /// signed under its own generation's chain id, still slashes. The chain id comes from the
    /// votes' generation, not the stored one: generation-0 votes signed under generation 2's
    /// chain id do not verify.
    function test_slashDoubleSign_AcceptsHistoricalGeneration() external {
        _blockStart(1, 0);
        _blockStart(2, 0);

        for (uint48 generation; generation < 2; ++generation) {
            uint256 snapshot = vm.snapshotState();
            _slash(
                0,
                _signed(_CK_A, _vote(_BLOCK_A, generation)),
                _signed(_CK_A, _vote(_BLOCK_B, generation))
            );
            assertEq(staking.bondAt(0).effStake, 0, "historical generation slashes");
            vm.revertToState(snapshot);
        }

        bytes memory storedId = _deploymentChainId(2);
        IEtnaStaking.Vote memory a = EtnaVoteKeys.signVote(_CK_A, _vote(_BLOCK_A, 0), storedId);
        IEtnaStaking.Vote memory b = EtnaVoteKeys.signVote(_CK_A, _vote(_BLOCK_B, 0), storedId);
        _assertSlashReverts(0, a, b, LibEtnaKeys.InvalidSignature.selector, "other id");
    }

    /// @dev Two precommits for height 6 whose part set hashes are 0x2222…2222 and 32 zero bytes,
    /// each signed by the bond's key over sign bytes encoded independently of the library, as
    /// stock CometBFT encodes them: a present 32-byte hash is written even when all zero. The
    /// library's sign bytes of the first equal the stock bytes, and another caller's slash
    /// succeeds.
    function test_slashDoubleSign_AcceptsStockSignedZeroPartsHash() external {
        bytes memory chainId = LibCometVote.chainId(
            LibCometVote.chainDomain(staking.l1ChainId(), L2_CHAIN_ID, staking.inbox(), 0)
        );
        IEtnaStaking.Vote memory a = _stockSignedVote(_STOCK_PARTS_HASH, chainId);
        IEtnaStaking.Vote memory b = _stockSignedVote(bytes32(0), chainId);
        assertEq(LibCometVote.signBytes(a, chainId), _stockSignBytes(_STOCK_PARTS_HASH, chainId));

        vm.prank(Bob);
        staking.slashDoubleSign(0, a, b);

        assertEq(staking.bondAt(0).effStake, 0, "slashed");
        assertEq(token.balanceOf(Bob), _BOUNTY, "bounty");
        assertEq(token.balanceOf(SLASH_SINK), _TO_SINK, "rest to the sink");
    }

    /// @dev A bond that a missed-signature penalty left below minStake holds no seat and has no
    /// exit. A slash still takes the rest of its stake and sets its exit at the current block, and
    /// it releases no seat, so it emits no `SeatReleased` and leaves the seat table as it was.
    function test_slashDoubleSign_SlashesSeatlessBondBelowMinStake() external {
        IEtnaStaking.Config memory cfg = _config();
        cfg.missLimit = 1;
        staking = _deploy(cfg);
        assertEq(_register(_CK_A, Alice, MIN_STAKE), 0, "bond 0");
        assertEq(_register(_CK_B, Carol, MIN_STAKE), 1, "bond 1");
        _blockStart(0, 1);
        uint256 rest = MIN_STAKE - MIN_STAKE / 10;
        assertEq(staking.bondAt(0).effStake, rest, "penalized below minStake");
        _assertSeatOfBond(0, false, 0, "seat released by the penalty");
        assertEq(staking.bondAt(0).exitHeight, NO_EXIT, "no exit");

        vm.roll(block.number + 5);
        (IEtnaStaking.Vote memory a, IEtnaStaking.Vote memory b) = _conflict(_CK_A);
        vm.recordLogs();
        vm.expectEmit(address(staking));
        emit IEtnaStaking.DoubleSignSlashed(0, Bob, rest, rest / 10, 0, _HEIGHT, _ROUND, 2);
        _slash(0, a, b);

        assertEq(_logsFrom(vm.getRecordedLogs(), address(staking)), 1, "no seat event");
        assertEq(staking.bondAt(0).effStake, 0, "rest slashed");
        assertEq(staking.bondAt(0).exitHeight, block.number, "exit set now");
        _assertBondInSeat(0, false, 0, "seat 0 still empty");
        _assertBondInSeat(1, true, 1, "seat 1 untouched");
        assertEq(token.balanceOf(Bob), rest / 10, "bounty on the rest");
    }

    /// @dev The staking contract reads no Inbox state: nothing is deployed at the Inbox address,
    /// so votes signed before the Inbox was initialized slash like any others.
    function test_slash_NeedsNoInboxState() external {
        assertEq(INBOX.code.length, 0, "no code at the Inbox");
        assertEq(staking.inbox(), INBOX, "the bound Inbox");
        (IEtnaStaking.Vote memory a, IEtnaStaking.Vote memory b) = _conflict(_CK_A);
        _slash(0, a, b);
        assertEq(staking.bondAt(0).effStake, 0, "slashed");
        assertEq(token.balanceOf(Bob), _BOUNTY, "bounty");
    }

    /// @dev The vector deployment (L1 chain 1, L2 chain 167001, Inbox 0x1111…) with the vector key
    /// registered as bond 0, the block-start call storing each pair's `current_generation`, and
    /// the vector signatures used as given. Every `votes.pairs` item with `double_sign` slashes
    /// the whole stake; every other pair reverts with the error of its reason. A bond is slashed
    /// once and a key registers once, so each pair runs from the same snapshot.
    function test_slashDoubleSign_MatchesCometBftVectorPairs() external {
        string memory j = LibEtnaVectors.load();
        assertEq(LibEtnaVectors.uintAt(j, ".deployment.l1_chain_id"), L1_CHAIN_ID, "L1 chain");
        assertEq(LibEtnaVectors.uintAt(j, ".deployment.l2_chain_id"), block.chainid, "L2 chain");
        assertEq(LibEtnaVectors.addressAt(j, ".deployment.inbox"), INBOX, "vector inbox");
        staking = _deploy(_config());

        uint256 pk = LibEtnaVectors.uintAt(j, ".votes.key.private_key");
        assertEq(EtnaTestKeys.publicKey(pk), LibEtnaVectors.bytesAt(j, ".votes.key.public_key"));
        assertEq(_register(pk, Alice, MIN_STAKE), 0, "bond 0");
        _assertBondForKey(LibEtnaVectors.addressAt(j, ".votes.key.signer"), true, 0, "key");

        string[] memory names = _caseNames(j);
        uint256 n = LibEtnaVectors.lengthAt(j, ".votes.pairs");
        assertEq(n, 20, "pairs");
        uint256 slashed;
        for (uint256 i; i < n; ++i) {
            uint256 snapshot = vm.snapshotState();
            if (_checkVectorPair(j, names, i)) ++slashed;
            vm.revertToState(snapshot);
        }
        assertEq(slashed, 12, "double-sign pairs");
    }

    /// @dev The shared ABI fixture includes the dynamic hash fields and a stock-signed conflict
    /// with a present zero parts hash, so external evidence builders agree with the contract.
    function test_slashDoubleSign_MatchesSharedAbiFixture() external view {
        string memory j = LibEtnaVectors.load();
        string[] memory names = _caseNames(j);
        IEtnaStaking.Vote memory a =
            _vectorVote(j, names, LibEtnaVectors.stringAt(j, ".votes.slash_abi.a"));
        IEtnaStaking.Vote memory b =
            _vectorVote(j, names, LibEtnaVectors.stringAt(j, ".votes.slash_abi.b"));
        uint256 bondId = LibEtnaVectors.uintAt(j, ".votes.slash_abi.bond_id");
        bytes4 selector = bytes4(LibEtnaVectors.bytesAt(j, ".votes.slash_abi.selector"));
        assertEq(IEtnaStaking.slashDoubleSign.selector, selector, "selector");
        assertEq(
            bytes4(keccak256(bytes(LibEtnaVectors.stringAt(j, ".votes.slash_abi.signature")))),
            selector,
            "signature"
        );
        assertEq(
            abi.encodeCall(IEtnaStaking.slashDoubleSign, (bondId, a, b)),
            LibEtnaVectors.bytesAt(j, ".votes.slash_abi.calldata"),
            "calldata"
        );
    }

    /// @dev A slash at block 50 leaves bond 0 with no stake and its exit at block 50. One block
    /// before the delay has passed, the withdrawal is still early. Then Carol, a stranger, withdraws
    /// it to the zero address: nothing is paid, so no TAIKO moves, the event names the zero
    /// address, and the bond is withdrawn with its owner cleared.
    function test_withdraw_ZeroBalanceByAnyoneAfterSlash() external {
        vm.roll(50);
        (IEtnaStaking.Vote memory a, IEtnaStaking.Vote memory b) = _conflict(_CK_A);
        _slash(0, a, b);
        assertEq(staking.bondAt(0).exitHeight, 50, "exit set by the slash");

        vm.roll(50 + WITHDRAWAL_DELAY - 1);
        vm.expectRevert(IEtnaStaking.WithdrawalNotReady.selector);
        vm.prank(Carol);
        staking.withdraw(0, address(0));

        vm.roll(50 + WITHDRAWAL_DELAY);
        vm.expectEmit(address(staking));
        emit IEtnaStaking.Withdrawn(0, address(0), 0);
        vm.recordLogs();
        vm.prank(Carol);
        staking.withdraw(0, address(0));

        assertEq(_logsFrom(vm.getRecordedLogs(), address(token)), 0, "no TAIKO transfer");
        IEtnaStaking.Bond memory bond = staking.bondAt(0);
        assertTrue(bond.withdrawn, "withdrawn");
        assertEq(bond.owner, address(0), "owner cleared");
        assertEq(bond.effStake, 0, "no stake");
        assertEq(bond.exitHeight, 50, "exit height kept");
        assertEq(token.balanceOf(Carol), 0, "nothing to the caller");
        assertEq(token.balanceOf(Alice), 0, "nothing to the owner");
        assertEq(token.balanceOf(Bob), _BOUNTY, "bounty");
        assertEq(token.balanceOf(SLASH_SINK), _TO_SINK, "sink");
        _assertBondForKey(EtnaTestKeys.ckAddr(_CK_A), true, 0, "key registration kept");
    }

    // ---------------------------------------------------------------
    // Rejected evidence
    // ---------------------------------------------------------------

    /// @dev Two signatures for the same block id are not a double sign, whatever their
    /// timestamps (CometBFT re-signs a vote with a later timestamp); nor are two nil votes or one
    /// vote submitted twice.
    function test_slashDoubleSign_RevertWhen_SameBlockId() external {
        bytes4 notDoubleSign = IEtnaStaking.NotDoubleSign.selector;
        IEtnaStaking.Vote memory a = _signed(_CK_A, _vote(_BLOCK_A, 0));
        IEtnaStaking.Vote memory late = _vote(_BLOCK_A, 0);
        late.timestampSeconds += 1;
        late.timestampNanos = 0;
        late = _signed(_CK_A, late);
        _assertSlashReverts(0, a, late, notDoubleSign, "later timestamp");
        _assertSlashReverts(0, a, a, notDoubleSign, "same vote twice");

        IEtnaStaking.Vote memory nil = _signed(_CK_A, _vote(0, 0));
        IEtnaStaking.Vote memory lateNil = _vote(0, 0);
        lateNil.timestampSeconds += 1;
        lateNil = _signed(_CK_A, lateNil);
        _assertSlashReverts(0, nil, lateNil, notDoubleSign, "two nil votes");
        assertEq(staking.bondAt(0).effStake, MIN_STAKE, "not slashed");
    }

    /// @dev Conflicting block ids in different rounds, types, heights or generations are not a
    /// same-round double sign. Each vote is signed by the bond's key under its own generation's
    /// chain id, and the stored generation (1) covers both. The check precedes the generation,
    /// bond and signature checks: a pair with one vote in a future generation, and an unsigned
    /// pair for an unknown bond, still revert `NotDoubleSign`.
    function test_slashDoubleSign_RevertWhen_DifferentRoundTypeHeightOrGeneration() external {
        bytes4 notDoubleSign = IEtnaStaking.NotDoubleSign.selector;
        _blockStart(1, 0);
        IEtnaStaking.Vote memory a = _signed(_CK_A, _vote(_BLOCK_A, 0));

        IEtnaStaking.Vote memory b = _vote(_BLOCK_B, 0);
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
        IEtnaStaking.Vote memory unsignedA = _vote(_BLOCK_A, 0);
        IEtnaStaking.Vote memory unsignedB = _vote(_BLOCK_B, 0);
        unsignedB.round = _ROUND + 1;
        _assertSlashReverts(7, unsignedA, unsignedB, notDoubleSign, "before bond and signatures");
        assertEq(staking.bondAt(0).effStake, MIN_STAKE, "not slashed");
    }

    /// @dev With no block-start call yet the stored generation is 0, so generation-1 evidence is
    /// in the future, checked before the bond and the signatures, and so is generation 2^48 - 1.
    /// Once the block-start call stores generation 3, generation-3 evidence slashes in the same
    /// block.
    function test_slash_RevertWhen_GenerationAboveLastStored() external {
        bytes4 futureGeneration = IEtnaStaking.FutureGeneration.selector;
        assertEq(staking.lastGeneration(), 0, "no call yet");
        _assertSlashReverts(
            0,
            _signed(_CK_A, _vote(_BLOCK_A, 1)),
            _signed(_CK_A, _vote(_BLOCK_B, 1)),
            futureGeneration,
            "generation 1 before any call"
        );
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

        _blockStart(3, 0);
        IEtnaStaking.Vote memory a = _signed(_CK_A, _vote(_BLOCK_A, 4));
        IEtnaStaking.Vote memory b = _signed(_CK_A, _vote(_BLOCK_B, 4));
        _assertSlashReverts(0, a, b, futureGeneration, "generation 4 after storing 3");
        _slash(0, _signed(_CK_A, _vote(_BLOCK_A, 3)), _signed(_CK_A, _vote(_BLOCK_B, 3)));
        assertEq(staking.bondAt(0).effStake, 0, "the stored generation slashes in its block");
    }

    /// @dev The staking contract derives the chain id from its own L1 chain id, the L2 chain id
    /// (block.chainid) and its Inbox. Votes the bond's key signed for another Inbox, another L2
    /// chain or another L1 chain are not evidence here, even when only one of the two is foreign.
    /// Each foreign pair is valid evidence at the deployment it was signed for: a staking contract
    /// bound to the other Inbox, this one on the other L2 chain, and a staking contract bound to
    /// the other L1 chain.
    function test_slashDoubleSign_RevertWhen_SignedForAnotherDeployment() external {
        bytes4 invalidSignature = LibEtnaKeys.InvalidSignature.selector;
        address otherInbox = address(0x2222222222222222222222222222222222222222);
        bytes[3] memory foreignIds = [
            _chainIdOf(L1_CHAIN_ID, L2_CHAIN_ID, otherInbox, 0),
            _chainIdOf(L1_CHAIN_ID, L2_CHAIN_ID + 1, INBOX, 0),
            _chainIdOf(L1_CHAIN_ID + 1, L2_CHAIN_ID, INBOX, 0)
        ];
        string[3] memory labels = ["other inbox", "other L2 chain", "other L1 chain"];
        IEtnaStaking.Vote memory ownA = _signed(_CK_A, _vote(_BLOCK_A, 0));

        for (uint256 i; i < 3; ++i) {
            IEtnaStaking.Vote memory a =
                EtnaVoteKeys.signVote(_CK_A, _vote(_BLOCK_A, 0), foreignIds[i]);
            IEtnaStaking.Vote memory b =
                EtnaVoteKeys.signVote(_CK_A, _vote(_BLOCK_B, 0), foreignIds[i]);
            _assertSlashReverts(0, a, b, invalidSignature, labels[i]);
            _assertSlashReverts(0, ownA, b, invalidSignature, string.concat(labels[i], ": one"));
        }
        assertEq(staking.bondAt(0).effStake, MIN_STAKE, "not slashed");

        uint256 snapshot = vm.snapshotState();
        IEtnaStaking.Config memory cfg = _config();
        cfg.inbox = otherInbox;
        staking = _deploy(cfg);
        assertEq(_register(_CK_A, Alice, MIN_STAKE), 0, "bond 0 bound to the other inbox");
        _assertForeignPairSlashes(foreignIds[0], labels[0]);
        vm.revertToState(snapshot);

        snapshot = vm.snapshotState();
        vm.chainId(L2_CHAIN_ID + 1);
        _assertForeignPairSlashes(foreignIds[1], labels[1]);
        vm.revertToState(snapshot);

        cfg = _config();
        cfg.l1ChainId = L1_CHAIN_ID + 1;
        staking = _deploy(cfg);
        assertEq(_register(_CK_A, Alice, MIN_STAKE), 0, "bond 0 bound to the other L1 chain");
        _assertForeignPairSlashes(foreignIds[2], labels[2]);
    }

    /// @dev The domain puts the L1 chain id first and the L2 chain id second. Votes signed under
    /// the domain with the two swapped, (167001, 1), do not verify; the same votes signed under
    /// (1, 167001) slash.
    function test_slash_RevertWhen_VotesSignedWithChainIdsSwapped() external {
        for (uint48 generation; generation < 2; ++generation) {
            if (generation != 0) _blockStart(generation, 0);
            bytes memory swapped = _chainIdOf(L2_CHAIN_ID, L1_CHAIN_ID, INBOX, generation);
            _assertSlashReverts(
                0,
                EtnaVoteKeys.signVote(_CK_A, _vote(_BLOCK_A, generation), swapped),
                EtnaVoteKeys.signVote(_CK_A, _vote(_BLOCK_B, generation), swapped),
                LibEtnaKeys.InvalidSignature.selector,
                "swapped chain ids"
            );
        }
        assertEq(staking.bondAt(0).effStake, MIN_STAKE, "not slashed");

        bytes memory ordered = _chainIdOf(L1_CHAIN_ID, L2_CHAIN_ID, INBOX, 1);
        _slash(
            0,
            EtnaVoteKeys.signVote(_CK_A, _vote(_BLOCK_A, 1), ordered),
            EtnaVoteKeys.signVote(_CK_A, _vote(_BLOCK_B, 1), ordered)
        );
        assertEq(staking.bondAt(0).effStake, 0, "the L1-first domain slashes");
    }

    /// @dev Evidence must be signed by the bond's own key. Another validator's double sign does
    /// not slash bond 0, nor does a pair with one vote from each key; that validator's evidence
    /// slashes its own bond only.
    function test_slashDoubleSign_RevertWhen_SignerIsAnotherKey() external {
        bytes4 invalidSignature = LibEtnaKeys.InvalidSignature.selector;
        assertEq(_register(_CK_B, Bob, MIN_STAKE), 1, "bond 1");
        (IEtnaStaking.Vote memory aA, IEtnaStaking.Vote memory bA) = _conflict(_CK_A);
        (IEtnaStaking.Vote memory aB, IEtnaStaking.Vote memory bB) = _conflict(_CK_B);

        _assertSlashReverts(0, aB, bB, invalidSignature, "other key");
        _assertSlashReverts(0, aA, bB, invalidSignature, "second vote from another key");
        _assertSlashReverts(0, aB, bA, invalidSignature, "first vote from another key");
        _assertSlashReverts(1, aA, bA, invalidSignature, "bond 0's key against bond 1");

        _slash(1, aB, bB);
        assertEq(staking.bondAt(1).effStake, 0, "bond 1 slashed");
        assertEq(staking.bondAt(0).effStake, MIN_STAKE, "bond 0 untouched");
    }

    /// @dev A double sign by a key registered to no bond slashes nothing, whichever bond it
    /// names.
    function test_slashDoubleSign_RevertWhen_SignerKeyIsUnregistered() external {
        (IEtnaStaking.Vote memory a, IEtnaStaking.Vote memory b) = _conflict(_CK_UNREGISTERED);
        _assertBondForKey(EtnaTestKeys.ckAddr(_CK_UNREGISTERED), false, 0, "unused key");
        _assertSlashReverts(0, a, b, LibEtnaKeys.InvalidSignature.selector, "unregistered key");
        assertEq(staking.bondAt(0).effStake, MIN_STAKE, "bond 0 untouched");
    }

    /// @dev After bond 0 is withdrawn and bond 1 takes seat 0, evidence signed by bond 0's key
    /// resolves to bond 0, never to the seat's new holder: naming bond 1 fails the key lookup and
    /// naming bond 0 fails because it is withdrawn.
    function test_slashDoubleSign_RevertWhen_OldKeyNamesTheSeatsNewHolder() external {
        _withdrawBond(0);
        assertEq(_register(_CK_B, Bob, MIN_STAKE), 1, "bond 1");
        _assertSeatOfBond(1, true, 0, "bond 1 takes seat 0");
        _assertBondForKey(EtnaTestKeys.ckAddr(_CK_A), true, 0, "bond 0's key still names bond 0");

        (IEtnaStaking.Vote memory a, IEtnaStaking.Vote memory b) = _conflict(_CK_A);
        _assertSlashReverts(1, a, b, LibEtnaKeys.InvalidSignature.selector, "the seat's new holder");
        _assertSlashReverts(0, a, b, IEtnaStaking.BondWithdrawn.selector, "withdrawn");
        assertEq(staking.bondAt(1).effStake, MIN_STAKE, "bond 1 untouched");
    }

    /// @dev The lifetime key lookup written at registration decides, and the stored key is not
    /// decompressed again, not even to release the seat. With bond 0's stored X overwritten, its
    /// own key's evidence still slashes it and clears that key's key-to-seat word.
    function test_slashDoubleSign_UsesTheLifetimeKeyLookupNotTheStoredKey() external {
        bytes32 ckXWord = _bondWord(0, 1);
        assertEq(vm.load(address(staking), ckXWord), staking.bondAt(0).ckX, "ckX word");
        vm.store(address(staking), ckXWord, bytes32(uint256(1)));
        assertEq(staking.bondAt(0).ckX, bytes32(uint256(1)), "stored X overwritten");
        address ckAddr = EtnaTestKeys.ckAddr(_CK_A);
        assertEq(_keySeatWord(ckAddr), bytes32(uint256(0x0001)), "seat 0 before the slash");

        (IEtnaStaking.Vote memory a, IEtnaStaking.Vote memory b) = _conflict(_CK_A);
        _slash(0, a, b);
        assertEq(staking.bondAt(0).effStake, 0, "slashed through the key lookup");
        assertEq(_keySeatWord(ckAddr), bytes32(0), "the signer's key-to-seat word cleared");
        _assertBondInSeat(0, false, 0, "seat 0 released");
    }

    /// @dev A 65-byte signature passes the range check; a V outside {0, 1} or a high S is then
    /// rejected by signature recovery (`InvalidSignature`), in either vote. The high-S form is
    /// the same signature's other half, which `ecrecover` alone accepts; the low-S form slashes.
    function test_slashDoubleSign_RevertWhen_SignatureHasBadVOrHighS() external {
        bytes4 invalidSignature = LibEtnaKeys.InvalidSignature.selector;
        (IEtnaStaking.Vote memory a, IEtnaStaking.Vote memory b) = _conflict(_CK_A);
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
        assertEq(staking.bondAt(0).effStake, 0, "low S slashes");
    }

    /// @dev A bond is slashed once: the same evidence again, or new evidence, finds no stake. A
    /// withdrawn bond cannot be slashed, and an id never issued names no bond. Each check
    /// precedes the signatures, so unsigned votes revert with the same error.
    function test_slash_RevertWhen_NothingLeftWithdrawnOrUnissued() external {
        bytes4 nothingToSlash = IEtnaStaking.NothingToSlash.selector;
        (IEtnaStaking.Vote memory a, IEtnaStaking.Vote memory b) = _conflict(_CK_A);
        _slash(0, a, b);

        _assertSlashReverts(0, a, b, nothingToSlash, "same evidence");
        IEtnaStaking.Vote memory c = _vote(_BLOCK_A, 0);
        IEtnaStaking.Vote memory d = _vote(_BLOCK_B, 0);
        c.round = _ROUND + 1;
        d.round = _ROUND + 1;
        _assertSlashReverts(0, _signed(_CK_A, c), _signed(_CK_A, d), nothingToSlash, "new evidence");
        _assertSlashReverts(
            0, _vote(_BLOCK_A, 0), _vote(_BLOCK_B, 0), nothingToSlash, "nothing, unsigned"
        );
        assertEq(token.balanceOf(Bob), _BOUNTY, "bounty paid once");

        bytes4 bondWithdrawn = IEtnaStaking.BondWithdrawn.selector;
        assertEq(_register(_CK_B, Carol, MIN_STAKE), 1, "bond 1");
        (IEtnaStaking.Vote memory aB, IEtnaStaking.Vote memory bB) = _conflict(_CK_B);
        _withdrawBond(1);
        _assertSlashReverts(1, aB, bB, bondWithdrawn, "withdrawn");
        _assertSlashReverts(
            1, _vote(_BLOCK_A, 0), _vote(_BLOCK_B, 0), bondWithdrawn, "withdrawn, unsigned"
        );

        bytes4 unknownBond = IEtnaStaking.UnknownBond.selector;
        _assertSlashReverts(2, a, b, unknownBond, "next bond id");
        _assertSlashReverts(type(uint256).max, a, b, unknownBond, "max");
        _assertSlashReverts(
            2, _vote(_BLOCK_A, 0), _vote(_BLOCK_B, 0), unknownBond, "unissued, unsigned"
        );
        assertEq(staking.bondCount(), 2, "no bond issued");
    }

    /// @dev Each vote field bound, applied to both votes of a signed conflicting pair: an accepted
    /// value slashes and a rejected one reverts `InvalidVote` when either vote carries it, before
    /// the pair checks. Timestamps have no bound: seconds (an int64 two's-complement pattern) and
    /// nanos slash on either side of CometBFT's Timestamp range. The signature must be exactly
    /// 65 bytes; its V and S are left to recovery
    /// (`test_slashDoubleSign_RevertWhen_SignatureHasBadVOrHighS`).
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

        _assertBound(_FIELD_SECONDS, uint64(_MIN_SECONDS - 1), true, "seconds min - 1");
        _assertBound(_FIELD_SECONDS, uint64(_MIN_SECONDS), true, "seconds min");
        _assertBound(_FIELD_SECONDS, type(uint64).max, true, "seconds -1");
        _assertBound(_FIELD_SECONDS, uint64(_END_SECONDS - 1), true, "seconds max - 1");
        _assertBound(_FIELD_SECONDS, uint64(_END_SECONDS), true, "seconds max");
        _assertBound(_FIELD_SECONDS, uint64(type(int64).max), true, "seconds int64 max");
        _assertBound(_FIELD_SECONDS, uint64(type(int64).min), true, "seconds int64 min");

        _assertBound(_FIELD_NANOS, 1e9 - 1, true, "nanos 10^9 - 1");
        _assertBound(_FIELD_NANOS, 1e9, true, "nanos 10^9");

        bytes4 invalidVote = IEtnaStaking.InvalidVote.selector;
        (IEtnaStaking.Vote memory a, IEtnaStaking.Vote memory b) = _conflict(_CK_A);
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

    /// @dev A hash is empty or exactly 32 bytes; any other length is rejected before the
    /// signatures are checked, whichever vote carries the malformed field.
    function test_slashDoubleSign_RevertWhen_HashLengthIsInvalid() external {
        uint256[4] memory lengths = [uint256(1), 31, 33, 64];
        for (uint256 i; i < lengths.length; ++i) {
            for (uint256 field; field < 2; ++field) {
                (IEtnaStaking.Vote memory a, IEtnaStaking.Vote memory b) = _conflict(_CK_A);
                if (field == 0) b.blockHash = new bytes(lengths[i]);
                else b.partsHash = new bytes(lengths[i]);
                string memory label = string.concat(
                    field == 0 ? "block hash of " : "parts hash of ",
                    vm.toString(lengths[i]),
                    " bytes"
                );
                _assertSlashReverts(
                    0,
                    a,
                    b,
                    IEtnaStaking.InvalidVote.selector,
                    string.concat(label, ", second vote")
                );
                _assertSlashReverts(
                    0, b, a, IEtnaStaking.InvalidVote.selector, string.concat(label, ", first vote")
                );
            }
        }
        assertEq(staking.bondAt(0).effStake, MIN_STAKE, "not slashed");
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
        returns (IEtnaStaking.Vote memory v_)
    {
        v_.voteType = 2;
        v_.height = _HEIGHT;
        v_.round = _ROUND;
        if (_blockHash != 0) {
            v_.blockHash = abi.encodePacked(_blockHash);
            v_.partsTotal = 1;
            v_.partsHash = abi.encodePacked(keccak256(abi.encode(_blockHash)));
        }
        v_.timestampSeconds = 1_700_000_000;
        v_.timestampNanos = 123;
        v_.generation = _generation;
        v_.signature = new bytes(65);
    }

    /// @dev Two generation-0 precommits for different blocks at the same height and round,
    /// signed by `_pk` for the base's deployment.
    function _conflict(uint256 _pk)
        private
        pure
        returns (IEtnaStaking.Vote memory a_, IEtnaStaking.Vote memory b_)
    {
        a_ = _signed(_pk, _vote(_BLOCK_A, 0));
        b_ = _signed(_pk, _vote(_BLOCK_B, 0));
    }

    /// @dev Signs `_v` with `_pk` under the chain id of the base's deployment for the vote's
    /// generation.
    function _signed(
        uint256 _pk,
        IEtnaStaking.Vote memory _v
    )
        private
        pure
        returns (IEtnaStaking.Vote memory)
    {
        return EtnaVoteKeys.signVote(_pk, _v, _deploymentChainId(_v.generation));
    }

    /// @dev The chain id of the base's deployment (L1 chain 1, L2 chain 167001, `INBOX`) for
    /// `_generation`.
    function _deploymentChainId(uint48 _generation) private pure returns (bytes memory) {
        return _chainIdOf(L1_CHAIN_ID, L2_CHAIN_ID, INBOX, _generation);
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
    /// the current staking contract, which must slash it.
    function _assertForeignPairSlashes(
        bytes memory _cometChainId,
        string memory _label
    )
        private
    {
        _slash(
            0,
            EtnaVoteKeys.signVote(_CK_A, _vote(_BLOCK_A, 0), _cometChainId),
            EtnaVoteKeys.signVote(_CK_A, _vote(_BLOCK_B, 0), _cometChainId)
        );
        assertEq(staking.bondAt(0).effStake, 0, string.concat(_label, ": slashed there"));
    }

    /// @dev Bob reports a conflicting pair of `_pk` against bond `_bondId`, which stakes
    /// `_stake`: `DoubleSignSlashed` is emitted, then `SeatReleased` if the bond held a seat, Bob
    /// receives `_bounty` and slashSink the rest. The bond keeps its owner and key registration,
    /// with no stake, exit height `_exit`, no seat and a zero key-to-seat word.
    function _assertSlashTakesAll(
        uint256 _bondId,
        uint256 _pk,
        uint256 _stake,
        uint256 _bounty,
        uint256 _exit
    )
        private
    {
        string memory label = string.concat("bond ", vm.toString(_bondId));
        (bool seated, uint8 seat) = staking.seatOfBond(_bondId);
        uint256 reporterBefore = token.balanceOf(Bob);
        uint256 sinkBefore = token.balanceOf(SLASH_SINK);
        uint256 heldBefore = token.balanceOf(address(staking));
        (IEtnaStaking.Vote memory a, IEtnaStaking.Vote memory b) = _conflict(_pk);

        vm.recordLogs();
        vm.expectEmit(address(staking));
        emit IEtnaStaking.DoubleSignSlashed(_bondId, Bob, _stake, _bounty, 0, _HEIGHT, _ROUND, 2);
        if (seated) {
            vm.expectEmit(address(staking));
            emit IEtnaStaking.SeatReleased(_bondId, seat);
        }
        vm.expectEmit(address(token));
        emit IERC20.Transfer(address(staking), Bob, _bounty);
        vm.expectEmit(address(token));
        emit IERC20.Transfer(address(staking), SLASH_SINK, _stake - _bounty);
        _slash(_bondId, a, b);
        assertEq(
            _logsFrom(vm.getRecordedLogs(), address(staking)),
            seated ? 2 : 1,
            string.concat(label, ": staking events")
        );

        assertEq(token.balanceOf(Bob) - reporterBefore, _bounty, string.concat(label, ": bounty"));
        assertEq(
            token.balanceOf(SLASH_SINK) - sinkBefore,
            _stake - _bounty,
            string.concat(label, ": rest to the sink")
        );
        assertEq(
            heldBefore - token.balanceOf(address(staking)),
            _stake,
            string.concat(label, ": whole stake paid out")
        );
        _assertSlashedBond(_bondId, _pk, _exit, seated, seat, label);
    }

    /// @dev Asserts the state of a bond that a slash took everything from.
    function _assertSlashedBond(
        uint256 _bondId,
        uint256 _pk,
        uint256 _exit,
        bool _wasSeated,
        uint8 _seat,
        string memory _label
    )
        private
        view
    {
        IEtnaStaking.Bond memory bond = staking.bondAt(_bondId);
        assertEq(bond.effStake, 0, string.concat(_label, ": no stake"));
        assertEq(bond.exitHeight, _exit, string.concat(_label, ": exit height"));
        assertFalse(bond.withdrawn, string.concat(_label, ": not withdrawn"));
        assertTrue(bond.owner != address(0), string.concat(_label, ": owner kept"));
        _assertSeatOfBond(_bondId, false, 0, _label);
        if (_wasSeated) _assertBondInSeat(_seat, false, 0, _label);
        address ckAddr = EtnaTestKeys.ckAddr(_pk);
        assertEq(_keySeatWord(ckAddr), bytes32(0), string.concat(_label, ": key-to-seat word"));
        _assertBondForKey(ckAddr, true, _bondId, _label);
    }

    /// @dev Deploys a staking contract with bounty rate `_bps`, gives bond 0 (key `_CK_B`, owner
    /// Alice) a stake of `_stake` and a top-up of `_topUp`, and checks that `_reporter`'s slash
    /// pays it `_bounty` and slashSink `_remainder` in real transfers and leaves the bond empty.
    function _assertSlashPayout(
        uint256 _stake,
        uint256 _topUp,
        uint256 _bps,
        address _reporter,
        uint256 _bounty,
        uint256 _remainder
    )
        private
    {
        IEtnaStaking.Config memory cfg = _config();
        cfg.slashBountyBps = _bps;
        staking = _deploy(cfg);
        if (_stake >= MIN_STAKE) {
            _register(_CK_B, Alice, _stake);
        } else {
            // No registration stakes less than minStake: register the minimum, then plant
            // `_stake` as bond 0's effStake and leave the staking contract holding exactly that.
            _register(_CK_B, Alice, MIN_STAKE);
            vm.store(address(staking), _bondWord(0, 2), bytes32(_stake));
            deal(address(token), address(staking), _stake);
            assertEq(staking.bondAt(0).effStake, _stake, "planted stake");
        }
        if (_topUp != 0) {
            _fund(Alice, _topUp);
            vm.prank(Alice);
            staking.topUp(0, _topUp);
        }
        uint256 reporterBefore = token.balanceOf(_reporter);
        uint256 sinkBefore = token.balanceOf(SLASH_SINK);
        (IEtnaStaking.Vote memory a, IEtnaStaking.Vote memory b) = _conflict(_CK_B);
        // No bounty means no transfer to the reporter at all, not a zero-amount one.
        if (_bounty == 0) {
            vm.expectCall(address(token), abi.encodeCall(IERC20.transfer, (_reporter, 0)), 0);
        }
        vm.expectEmit(address(staking));
        emit IEtnaStaking.DoubleSignSlashed(
            0, _reporter, _stake + _topUp, _bounty, 0, _HEIGHT, _ROUND, 2
        );
        vm.prank(_reporter);
        staking.slashDoubleSign(0, a, b);

        assertEq(token.balanceOf(_reporter) - reporterBefore, _bounty, "reporter payment");
        assertEq(token.balanceOf(SLASH_SINK) - sinkBefore, _remainder, "sink payment");
        assertEq(token.balanceOf(address(staking)), 0, "all principal paid");
        assertEq(staking.bondAt(0).effStake, 0, "principal slashed");
    }

    /// @dev Bob reports `_a` and `_b` against `_bondId`.
    function _slash(
        uint256 _bondId,
        IEtnaStaking.Vote memory _a,
        IEtnaStaking.Vote memory _b
    )
        private
    {
        vm.prank(Bob);
        staking.slashDoubleSign(_bondId, _a, _b);
    }

    function _assertSlashReverts(
        uint256 _bondId,
        IEtnaStaking.Vote memory _a,
        IEtnaStaking.Vote memory _b,
        bytes4 _error,
        string memory _label
    )
        private
    {
        vm.prank(Bob);
        try staking.slashDoubleSign(_bondId, _a, _b) {
            assertTrue(false, string.concat(_label, ": slashed"));
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
        IEtnaStaking.Vote memory a = _signed(_CK_A, _withField(_vote(_BLOCK_A, 0), _field, _value));
        IEtnaStaking.Vote memory b = _signed(_CK_A, _withField(_vote(_BLOCK_B, 0), _field, _value));
        if (_accepted) {
            uint256 snapshot = vm.snapshotState();
            _slash(0, a, b);
            assertEq(staking.bondAt(0).effStake, 0, _label);
            vm.revertToState(snapshot);
        } else {
            bytes4 invalidVote = IEtnaStaking.InvalidVote.selector;
            (IEtnaStaking.Vote memory inRangeA, IEtnaStaking.Vote memory inRangeB) =
                _conflict(_CK_A);
            _assertSlashReverts(0, a, inRangeB, invalidVote, string.concat(_label, ", first vote"));
            _assertSlashReverts(0, inRangeA, b, invalidVote, string.concat(_label, ", second vote"));
        }
    }

    function _withField(
        IEtnaStaking.Vote memory _v,
        uint256 _field,
        uint256 _value
    )
        private
        pure
        returns (IEtnaStaking.Vote memory)
    {
        if (_field == _FIELD_TYPE) _v.voteType = uint8(_value);
        else if (_field == _FIELD_HEIGHT) _v.height = uint64(_value);
        else if (_field == _FIELD_ROUND) _v.round = uint32(_value);
        else if (_field == _FIELD_SECONDS) _v.timestampSeconds = uint64(_value);
        else _v.timestampNanos = uint32(_value);
        return _v;
    }

    /// @dev A precommit for height 6, round 0, block `_STOCK_BLOCK_HASH` with a one-part part set
    /// header of hash `_partsHash`, timestamped 1,700,000,000 with zero nanos, at generation 0:
    /// the fields CometBFT v0.40.0's Vote.ValidateBasic and evidence.VerifyDuplicateVote check.
    /// It is signed by bond 0's key over `_stockSignBytes`, and the signature recovers that key.
    function _stockSignedVote(
        bytes32 _partsHash,
        bytes memory _chainId
    )
        private
        pure
        returns (IEtnaStaking.Vote memory vote_)
    {
        vote_.voteType = 2;
        vote_.height = 6;
        vote_.blockHash = abi.encodePacked(_STOCK_BLOCK_HASH);
        vote_.partsTotal = 1;
        vote_.partsHash = abi.encodePacked(_partsHash);
        vote_.timestampSeconds = 1_700_000_000;
        bytes32 digest = keccak256(_stockSignBytes(_partsHash, _chainId));
        vote_.signature = EtnaTestKeys.sig65(_CK_A, digest);
        assertEq(LibEtnaKeys.recoverSigner(digest, vote_.signature), vm.addr(_CK_A), "signer");
    }

    /// @dev The literal stock VoteSignBytes prefix and suffix for height 6, round 0, total 1 and
    /// timestamp 1700000000; the deployment's 48-byte chain id is the only variable-length input.
    function _stockSignBytes(
        bytes32 _partsHash,
        bytes memory _chainId
    )
        private
        pure
        returns (bytes memory)
    {
        assert(_chainId.length == 48);
        return bytes.concat(
            hex"8f01080211060000000000000022480a20",
            _STOCK_BLOCK_HASH,
            hex"122408011220",
            _partsHash,
            hex"2a060880e2cfaa063230",
            _chainId
        );
    }

    /// @dev Stores the `current_generation` of `votes.pairs` item `_i` through a block-start call
    /// and submits its votes: a `double_sign` pair must slash the whole stake, any other must
    /// revert with the error of its reason.
    /// @return slashed_ Whether the pair is a double sign.
    function _checkVectorPair(
        string memory _j,
        string[] memory _names,
        uint256 _i
    )
        private
        returns (bool slashed_)
    {
        string memory p = LibEtnaVectors.itemAt(".votes.pairs", _i);
        string memory name = _pairField(_j, p, "name");
        IEtnaStaking.Vote memory a = _vectorVote(_j, _names, _pairField(_j, p, "a"));
        IEtnaStaking.Vote memory b = _vectorVote(_j, _names, _pairField(_j, p, "b"));
        _blockStart(uint48(LibEtnaVectors.uintAt(_j, string.concat(p, "current_generation"))), 0);

        slashed_ = vm.parseJsonBool(_j, string.concat(p, "double_sign"));
        if (!slashed_) {
            _assertSlashReverts(0, a, b, _errorFor(_pairField(_j, p, "reason")), name);
            return false;
        }
        assertEq(_pairField(_j, p, "reason"), "double_sign", name);
        vm.expectEmit(address(staking));
        emit IEtnaStaking.DoubleSignSlashed(
            0, Bob, MIN_STAKE, _BOUNTY, a.generation, a.height, a.round, a.voteType
        );
        _slash(0, a, b);
        assertEq(staking.bondAt(0).effStake, 0, name);
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
        ) return IEtnaStaking.NotDoubleSign.selector;
        if (r == keccak256("future_generation")) return IEtnaStaking.FutureGeneration.selector;
        if (r == keccak256("other_deployment")) return LibEtnaKeys.InvalidSignature.selector;
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
            names_[i] = LibEtnaVectors.stringAt(
                _j, string.concat(LibEtnaVectors.itemAt(".votes.cases", i), "name")
            );
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
        returns (IEtnaStaking.Vote memory v_)
    {
        uint256 i;
        while (i < _names.length && keccak256(bytes(_names[i])) != keccak256(bytes(_name))) {
            ++i;
        }
        require(i < _names.length, string.concat("no vote case named ", _name));
        string memory p = LibEtnaVectors.itemAt(".votes.cases", i);
        string memory q = string.concat(p, "vote.");
        v_.voteType = uint8(LibEtnaVectors.uintAt(_j, string.concat(q, "voteType")));
        v_.height = uint64(LibEtnaVectors.uintAt(_j, string.concat(q, "height")));
        v_.round = uint32(LibEtnaVectors.uintAt(_j, string.concat(q, "round")));
        v_.blockHash = LibEtnaVectors.bytesAt(_j, string.concat(q, "blockHash"));
        v_.partsTotal = uint32(LibEtnaVectors.uintAt(_j, string.concat(q, "partsTotal")));
        v_.partsHash = LibEtnaVectors.bytesAt(_j, string.concat(q, "partsHash"));
        // The staking contract takes the int64 seconds as their two's-complement pattern.
        v_.timestampSeconds =
            uint64(LibEtnaVectors.uintAt(_j, string.concat(q, "timestampSecondsU64")));
        v_.timestampNanos = uint32(LibEtnaVectors.uintAt(_j, string.concat(q, "timestampNanos")));
        v_.generation = uint48(LibEtnaVectors.uintAt(_j, string.concat(q, "generation")));
        v_.signature = LibEtnaVectors.bytesAt(_j, string.concat(p, "signature"));
    }

    /// @dev Requests the exit of bond `_bondId`, waits out the withdrawal delay and withdraws it
    /// to its owner.
    function _withdrawBond(uint256 _bondId) private {
        address owner = staking.bondAt(_bondId).owner;
        _requestExit(_bondId);
        vm.roll(block.number + WITHDRAWAL_DELAY);
        vm.prank(owner);
        staking.withdraw(_bondId, owner);
    }

    /// @dev The slot of word `_word` (0 to 2) of bond `_bondId`'s record, at
    /// keccak256(abi.encode(bondId, T + 260)) + word.
    function _bondWord(uint256 _bondId, uint256 _word) private pure returns (bytes32) {
        return bytes32(uint256(keccak256(abi.encode(_bondId, uint256(T) + 260))) + _word);
    }

    /// @dev Splits a 65-byte signature into R, S and V.
    function _split(bytes memory _sig) private pure returns (bytes32 r_, bytes32 s_, uint8 v_) {
        assembly {
            r_ := mload(add(_sig, 0x20))
            s_ := mload(add(_sig, 0x40))
            v_ := byte(0, mload(add(_sig, 0x60)))
        }
    }

    /// @dev The first `_n` bytes of `_b`.
    function _prefix(bytes memory _b, uint256 _n) private pure returns (bytes memory out_) {
        out_ = new bytes(_n);
        for (uint256 i; i < _n; ++i) {
            out_[i] = _b[i];
        }
    }

    /// @dev Counts the logs `_emitter` emitted.
    function _logsFrom(
        Vm.Log[] memory _logs,
        address _emitter
    )
        private
        pure
        returns (uint256 n_)
    {
        for (uint256 i; i < _logs.length; ++i) {
            if (_logs[i].emitter == _emitter) ++n_;
        }
    }
}
