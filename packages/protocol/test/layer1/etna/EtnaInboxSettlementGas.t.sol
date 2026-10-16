// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EtnaInboxTestBase } from "./EtnaInboxTestBase.sol";
import { console2 } from "forge-std/src/console2.sol";
import { IEtnaInbox } from "src/layer1/etna/iface/IEtnaInbox.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";

/// @dev `vm.cool` (forge 1.0+), which the pinned forge-std does not declare yet.
interface IVmCoolGas {
    function cool(address _target) external;
}

/// @notice Lands a freezing batch at the client's committee size cap and measures its transaction.
/// @dev The Inbox runs 200-block epochs and the registry holds `MAX_MEMBERS` validators, each
/// with its own registration owner, so every member's settlement credits an owner for the first
/// time. A test lands a freezing batch on a funded pool and reports what its transaction needs:
/// the `land` call's execution gas before refunds, with every contract and storage slot cold as
/// at the start of a transaction, plus the intrinsic 21,000 and the calldata gas. Every member
/// signs every height of the batch and has a proposer score in every part. The verifier accepts
/// every proof and the batch consumes no forced inclusion, so a real verifier and consumed forced
/// inclusions come on top. A test's setUp runs as an earlier transaction, so the state it leaves is
/// not warm or dirty in the measured one.
abstract contract EtnaInboxSettlementGasTestBase is EtnaInboxTestBase {
    /// @dev EIP-7825's transaction gas cap, at which the lander caps a landing's gas limit.
    uint256 internal constant TX_GAS_CAP = 16_777_216;
    /// @dev The largest committee the client accepts (`MAX_N_MAX` in taiko-client-rs).
    uint256 internal constant MAX_MEMBERS = 300;
    uint64 internal constant GAS_EPOCH_LEN = 200;
    uint64 internal constant L1_HEAD = 20_000;
    bytes internal constant PROOF = "etna proof";
    address internal constant FEE_RECIPIENT = address(0xfee0fee0);

    IEtnaInbox.CommitteeMember[] internal _members;

    function setUp() public virtual override {
        super.setUp();
        IEtnaInbox.GenesisParams memory params = _defaultGenesisParams();
        params.epochLenL2 = GAS_EPOCH_LEN;
        etnaInbox.init(address(this), params);
        // The registrations would exceed the test's block gas limit; their gas is not measured.
        vm.pauseGasMetering();
        for (uint256 i; i < MAX_MEMBERS; ++i) {
            address owner = address(uint160(0x10000 + i));
            uint256 stake = MIN_STAKE + i * 1 ether;
            taikoToken.mint(owner, stake);
            vm.startPrank(owner);
            taikoToken.approve(address(registry), stake);
            uint256 bondId = registry.register(bytes32(0x1000 + i), stake, owner);
            vm.stopPrank();
            _members.push(
                IEtnaInbox.CommitteeMember({
                    bondId: uint32(bondId),
                    activeFromL1: registry.entryAt(bondId).activeFromL1,
                    effStake: stake
                })
            );
        }
        vm.resumeGasMetering();
        vm.roll(L1_HEAD);
        vm.setBlockhash(L1_HEAD - 1, keccak256("anchor"));
        vm.deal(address(rewardPool), 100 ether);
    }

    /// @dev The tests initialize the Inbox with their own epoch length.
    function _initializeOnDeploy() internal pure override returns (bool) {
        return false;
    }

    /// @dev Lands `(_parent, _lastHeight]` with proposer scores, every account and slot cold, and
    /// returns the transaction's gas; checks that it froze epoch 0 and credited the last owner.
    function _measureLanding(uint64 _parent, uint64 _lastHeight) internal returns (uint256 gas_) {
        bytes memory data = _landCalldata(_parent, _lastHeight, true);
        _coolProxy(address(etnaInbox));
        _coolProxy(address(rewardPool));
        _coolProxy(address(registry));
        _coolProxy(address(signalService));
        IVmCoolGas(address(vm)).cool(address(landVerifier));
        _land(data);
        gas_ = vm.lastCallGas().gasTotalUsed + 21_000 + _calldataGas(data);

        assertEq(rewardPool.epochRecord(0).frozenAtL1, block.number, "epoch 0 frozen");
        address lastOwner = address(uint160(0x10000 + MAX_MEMBERS - 1));
        assertGt(rewardPool.creditsOf(lastOwner), 0, "last owner credited");
    }

    /// @dev Bob lands `_data` with one blob.
    function _land(bytes memory _data) internal {
        vm.blobhashes(_getBlobHashes(1));
        vm.prank(Bob);
        (bool success,) = address(etnaInbox).call(_data);
        assertTrue(success, "landed");
    }

    /// @dev The `land` calldata of `(_parent, _lastHeight]` for the whole committee, settling each
    /// epoch whose last height its commit range reaches; without `_signed`, every count and score
    /// is zero.
    function _landCalldata(
        uint64 _parent,
        uint64 _lastHeight,
        bool _signed
    )
        internal
        view
        returns (bytes memory)
    {
        IEtnaInbox.CommitteeMember[] memory committee = _members;
        uint64 first = _parent > 1 ? _parent : 1;
        uint64 last = _lastHeight - 1;
        uint256 complete = last / GAS_EPOCH_LEN - (first - 1) / GAS_EPOCH_LEN;
        IEtnaInbox.CommitteeMember[][] memory settlements =
            new IEtnaInbox.CommitteeMember[][](complete);
        for (uint256 k; k < complete; ++k) {
            settlements[k] = committee;
        }
        (uint48 head,) = etnaInbox.getForcedInclusionState();
        IEtnaInbox.LandInput memory input = IEtnaInbox.LandInput({
            lastHeight: _lastHeight,
            lastBlockHash: keccak256(abi.encode("l2 block", _lastHeight)),
            lastStateRoot: keccak256(abi.encode("l2 state", _lastHeight)),
            l1ReferenceBlockNumber: L1_HEAD - 1,
            forcedInclusionHead: head,
            feeRecipient: FEE_RECIPIENT
        });
        IEtnaInbox.EpochParticipation[] memory parts =
            _parts(first, last, keccak256(abi.encode(committee)), _signed);
        return abi.encodeCall(IEtnaInbox.land, (input, parts, settlements, PROOF));
    }

    /// @dev One part per epoch of the commit range `[_first, _last]`. With `_signed`, every member
    /// signs every height of the part and scores an equal share of its 10,000 per height;
    /// otherwise every count and score is zero.
    function _parts(
        uint64 _first,
        uint64 _last,
        bytes32 _committeeHash,
        bool _signed
    )
        internal
        pure
        returns (IEtnaInbox.EpochParticipation[] memory parts_)
    {
        uint64 eFirst = (_first - 1) / GAS_EPOCH_LEN;
        parts_ = new IEtnaInbox.EpochParticipation[]((_last - 1) / GAS_EPOCH_LEN - eFirst + 1);
        for (uint256 k; k < parts_.length; ++k) {
            uint64 e = eFirst + uint64(k);
            uint64 lo = _first > e * GAS_EPOCH_LEN + 1 ? _first : e * GAS_EPOCH_LEN + 1;
            uint64 hi = _last < (e + 1) * GAS_EPOCH_LEN ? _last : (e + 1) * GAS_EPOCH_LEN;
            uint32 heights = uint32(hi - lo + 1);
            uint32[] memory counts = new uint32[](MAX_MEMBERS);
            uint32[] memory scores = new uint32[](MAX_MEMBERS);
            for (uint256 i; _signed && i < MAX_MEMBERS; ++i) {
                counts[i] = heights;
                scores[i] = uint32(uint256(heights) * 10_000 / MAX_MEMBERS);
            }
            parts_[k] = IEtnaInbox.EpochParticipation({
                epoch: e,
                committeeHash: _committeeHash,
                signedCounts: counts,
                proposerScores: scores
            });
        }
    }

    /// @dev The standard calldata gas of `_data`: 4 per zero byte and 16 per other byte. At these
    /// execution costs it is above the EIP-7623 floor.
    function _calldataGas(bytes memory _data) internal pure returns (uint256 gas_) {
        for (uint256 i; i < _data.length; ++i) {
            gas_ += _data[i] == 0 ? 4 : 16;
        }
    }

    /// @dev Marks a proxy, its implementation and their storage cold.
    function _coolProxy(address _proxy) internal {
        IVmCoolGas(address(vm)).cool(_proxy);
        IVmCoolGas(address(vm)).cool(EssentialContract(_proxy).impl());
    }
}

/// @notice A freezing landing that settles a whole epoch in one part.
contract EtnaInboxSinglePartSettlementGasTest is EtnaInboxSettlementGasTestBase {
    /// @dev (0, 201] carries the commits of heights 1 to 200, exactly epoch 0, and freezes it in
    /// one part, writing the epoch's committee hash, counts and scores for the first time: an
    /// upper bound for the one-part freezing landings the lander builds. No production landing
    /// writes that much, since back-pressure keeps every batch shorter than an epoch, so earlier
    /// landings of the epoch have already written its hash and most of its counts. Measured
    /// 12,487,285 gas, 4.29M (25.6%) under the cap; about 40.3k more per member (5,510,080 at 128
    /// members, 14,894,536 at 360, 16,515,694 at 400), so it stops fitting at about 406 members.
    function test_land_SinglePartFreezingLandingOf300MembersFitsTheCap() external {
        uint256 gas = _measureLanding(0, GAS_EPOCH_LEN + 1);
        console2.log("freezing landing, one part, 300 members:", gas);
        assertLt(gas, TX_GAS_CAP);
    }
}

/// @notice A freezing landing that also carries the next epoch's first commits.
contract EtnaInboxTwoPartSettlementGasTest is EtnaInboxSettlementGasTestBase {
    function setUp() public override {
        super.setUp();
        _land(_landCalldata(0, 125, false));
    }

    /// @dev The 150-block batch (125, 275] carries the commits of heights 125 to 274: the last 76
    /// heights of epoch 0, which it freezes, and the first 74 of epoch 1. The setUp's landing
    /// (0, 125] reported epoch 0's committee but no signed count or proposer score, so this
    /// landing writes every count and score word of epoch 0 and epoch 1's committee hash, counts
    /// and scores for the first time, and credits every owner for the first time: a strict upper
    /// bound, since the members holding 2/3 of the stake have signed by then in production. The
    /// lander no longer builds a two-part freezing landing, but one must stay landable:
    /// 15,000,000 leaves at least 1.77M under the cap for a real verifier and consumed forced
    /// inclusions. Measured 14,963,393 gas, 36,607 under that bound and 1.81M (10.8%) under the
    /// cap; about 48k more per member (6,548,717 at 128 members, 16,449,168 at 330, 16,914,260 at
    /// 340, 17,844,824 at 360), so it stops fitting at about 337 members.
    function test_land_TwoPartFreezingLandingOf300MembersStaysBelow15M() external {
        uint256 gas = _measureLanding(125, 275);
        console2.log("freezing landing, two parts, 300 members:", gas);
        assertLt(gas, 15_000_000);
    }
}
