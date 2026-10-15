// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IEtnaInbox } from "../iface/IEtnaInbox.sol";
import { IEtnaRewardPool } from "../iface/IEtnaRewardPool.sol";
import { IEtnaStakingRegistry } from "../iface/IEtnaStakingRegistry.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IBridge, IMessageInvocable } from "src/shared/bridge/IBridge.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { LibAddress } from "src/shared/libs/LibAddress.sol";

import "./EtnaRewardPool_Layout.sol"; // DO NOT DELETE

/// @title EtnaRewardPool
/// @notice The L1 pool of the Etna chain's fee revenue. Fee sweeps from the L2 fee vault arrive
/// through the L1 Bridge; the Inbox reports each landing's validator participation, and the
/// landing that carries an epoch's last commit freezes the epoch and settles it inline.
/// @dev Freezing an epoch splits fixed shares off the free balance (`balance - reservedTotal`):
/// the validator share is credited to the owners of the committee's registrations and reserved
/// until they withdraw, and the proving share goes to the Inbox's prover reward ledger. What a
/// settlement does not credit (rounding remainders, shares without an owner) never leaves the free
/// balance. Each epoch freezes once, in the landing whose commit range reaches its last height, so
/// sweeps and donations that arrive later only raise later epochs' allocations.
///
/// Nothing is pausable: the Bridge must always be able to deliver or retry a sweep, a landing must
/// never fail on the pool, and owners withdraw their credits themselves. No privileged role can
/// move the pool's Ether; only an upgrade can.
/// @custom:security-contact security@taiko.xyz
contract EtnaRewardPool is IEtnaRewardPool, IMessageInvocable, EssentialContract {
    using LibAddress for address;

    // ---------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------

    /// @dev The parts-per-million denominator of the allocation shares.
    uint256 private constant _PPM = 1_000_000;

    // ---------------------------------------------------------------
    // Immutable Variables
    // ---------------------------------------------------------------

    /// @inheritdoc IEtnaRewardPool
    address public immutable inbox;

    /// @inheritdoc IEtnaRewardPool
    address public immutable stakingRegistry;

    /// @inheritdoc IEtnaRewardPool
    address public immutable l1Bridge;

    /// @inheritdoc IEtnaRewardPool
    address public immutable l2FeeVault;

    /// @inheritdoc IEtnaRewardPool
    uint64 public immutable l2ChainId;

    /// @inheritdoc IEtnaRewardPool
    uint32 public immutable allocValidatorPpm;

    /// @inheritdoc IEtnaRewardPool
    uint32 public immutable allocProverPpm;

    // ---------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------

    /// @inheritdoc IEtnaRewardPool
    uint256 public reservedTotal;

    /// @inheritdoc IEtnaRewardPool
    uint256 public arrivedTotal;

    /// @dev The settlement record of each epoch.
    mapping(uint64 epoch => EpochRecord record) private _epochs;

    /// @dev Each epoch's signed-height counts, eight uint32 counts per word: member `i` occupies
    /// bits `32 * (i % 8)` to `32 * (i % 8) + 31` of word `i / 8`.
    mapping(uint64 epoch => mapping(uint256 word => uint256 counts)) private _signedCounts;

    /// @dev The credits of each registration owner, reserved until withdrawn.
    mapping(address owner => uint256 amount) private _credits;

    uint256[45] private __gap;

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    /// @notice Sets the pool's immutable configuration.
    /// @param _inbox The Etna Inbox proxy; must be non-zero.
    /// @param _stakingRegistry The Etna staking registry proxy; must be non-zero.
    /// @param _l1Bridge The L1 Bridge that delivers the sweeps; must be non-zero.
    /// @param _l2FeeVault The L2 fee vault; must be non-zero.
    /// @param _l2ChainId The chain id of the Etna L2; must be non-zero.
    /// @param _allocValidatorPpm The validator share of the free balance at each freeze.
    /// @param _allocProverPpm The proving share; the two shares may sum to at most 1,000,000.
    constructor(
        address _inbox,
        address _stakingRegistry,
        address _l1Bridge,
        address _l2FeeVault,
        uint64 _l2ChainId,
        uint32 _allocValidatorPpm,
        uint32 _allocProverPpm
    ) {
        require(_inbox != address(0), ZERO_ADDRESS());
        require(_stakingRegistry != address(0), ZERO_ADDRESS());
        require(_l1Bridge != address(0), ZERO_ADDRESS());
        require(_l2FeeVault != address(0), ZERO_ADDRESS());
        require(_l2ChainId != 0, ZERO_VALUE());
        require(uint256(_allocValidatorPpm) + _allocProverPpm <= _PPM, InvalidAllocation());

        inbox = _inbox;
        stakingRegistry = _stakingRegistry;
        l1Bridge = _l1Bridge;
        l2FeeVault = _l2FeeVault;
        l2ChainId = _l2ChainId;
        allocValidatorPpm = _allocValidatorPpm;
        allocProverPpm = _allocProverPpm;
    }

    // ---------------------------------------------------------------
    // External & Public Functions
    // ---------------------------------------------------------------

    /// @notice Initializes the pool.
    /// @param _owner The owner, who can upgrade the pool, pause and unpause it (no pool flow
    /// checks the pause) and transfer ownership; `msg.sender` if zero.
    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    /// @notice Accepts any Ether as free balance, such as donations and Bridge fee refunds.
    receive() external payable {
        emit Donation(msg.sender, msg.value);
    }

    /// @notice Receives a fee sweep from the L2 fee vault through the L1 Bridge.
    /// @dev Requires the L1 Bridge as caller and a Bridge context naming the fee vault on the
    /// Etna L2 as sender; reverts `UnauthorizedSender` otherwise. `_data` is the vault's
    /// `abi.encode(uint64 sweepNonce)`. The value joins the free balance. Not pausable and kept
    /// cheap, so the Bridge can always deliver or retry a sweep within the vault's gas limit.
    /// @param _data The ABI-encoded sweep nonce.
    function onMessageInvocation(bytes calldata _data) external payable {
        require(msg.sender == l1Bridge, UnauthorizedSender());
        IBridge.Context memory context = IBridge(l1Bridge).context();
        require(context.from == l2FeeVault && context.srcChainId == l2ChainId, UnauthorizedSender());
        uint64 sweepNonce = abi.decode(_data, (uint64));

        arrivedTotal += msg.value;
        emit FeesArrived(context.msgHash, sweepNonce, msg.value);
    }

    /// @inheritdoc IEtnaRewardPool
    function recordLanding(
        uint64 _lastHeight,
        uint64 _epochLenL2,
        IEtnaInbox.EpochParticipation[] calldata _parts,
        IEtnaInbox.CommitteeMember[][] calldata _settlements
    )
        external
        nonReentrant
    {
        require(msg.sender == inbox, UnauthorizedSender());

        uint256 settled;
        for (uint256 k; k < _parts.length; ++k) {
            IEtnaInbox.EpochParticipation calldata part = _parts[k];
            EpochRecord storage record = _epochs[part.epoch];
            _recordParticipation(record, part);

            // The commit of the epoch's last height rides in the next block, so the batch carries
            // it iff `_lastHeight - 1 >= lastHeightOfEpoch`; written without the subtraction.
            if (uint256(_lastHeight) > (uint256(part.epoch) + 1) * _epochLenL2) {
                require(settled < _settlements.length, SettlementCountMismatch());
                _freezeAndSettle(part.epoch, record, _settlements[settled]);
                ++settled;
            }
        }
        require(settled == _settlements.length, SettlementCountMismatch());
    }

    /// @inheritdoc IEtnaRewardPool
    function withdrawRewards(address _to)
        external
        nonReentrant
        nonZeroAddr(_to)
        returns (uint256 amount_)
    {
        amount_ = _credits[msg.sender];
        if (amount_ == 0) return 0;

        delete _credits[msg.sender];
        reservedTotal -= amount_;
        _to.sendEtherAndVerify(amount_);
        emit RewardsWithdrawn(msg.sender, _to, amount_);
    }

    /// @inheritdoc IEtnaRewardPool
    function freeBalance() external view returns (uint256) {
        return address(this).balance - reservedTotal;
    }

    /// @inheritdoc IEtnaRewardPool
    function epochRecord(uint64 _epoch) external view returns (EpochRecord memory) {
        return _epochs[_epoch];
    }

    /// @inheritdoc IEtnaRewardPool
    function signedCountOf(uint64 _epoch, uint256 _index) external view returns (uint32) {
        return uint32(_signedCounts[_epoch][_index >> 3] >> ((_index & 7) << 5));
    }

    /// @inheritdoc IEtnaRewardPool
    function creditsOf(address _account) external view returns (uint256) {
        return _credits[_account];
    }

    /// @inheritdoc IEtnaRewardPool
    function checkInvariants() external view returns (bool) {
        return address(this).balance >= reservedTotal;
    }

    // ---------------------------------------------------------------
    // Private Functions
    // ---------------------------------------------------------------

    /// @dev Binds a part's committee hash to its epoch and adds its signed counts.
    /// @param _record The epoch's record.
    /// @param _part The participation of one epoch.
    function _recordParticipation(
        EpochRecord storage _record,
        IEtnaInbox.EpochParticipation calldata _part
    )
        private
    {
        bytes32 committeeHash = _part.committeeHash;
        require(committeeHash != 0, ZeroCommitteeHash());
        // Each height's commit lands once, so a frozen epoch is never reported again.
        require(_record.frozenAtL1 == 0, EpochAlreadyFrozen());

        bytes32 stored = _record.committeeHash;
        if (stored == 0) {
            _record.committeeHash = committeeHash;
        } else {
            require(stored == committeeHash, CommitteeMismatch());
        }

        mapping(uint256 => uint256) storage words = _signedCounts[_part.epoch];
        uint32[] calldata counts = _part.signedCounts;
        uint256 n = counts.length;
        for (uint256 w; w << 3 < n; ++w) {
            uint256 word = words[w];
            uint256 updated = word;
            uint256 end = Math.min((w + 1) << 3, n);
            for (uint256 i = w << 3; i < end; ++i) {
                uint32 count = counts[i];
                if (count == 0) continue;
                uint256 shift = (i & 7) << 5;
                // Checked uint32 addition: an overflowing total reverts.
                uint256 total = uint32(updated >> shift) + count;
                updated = (updated & ~(uint256(type(uint32).max) << shift)) | (total << shift);
            }
            if (updated != word) words[w] = updated;
        }
    }

    /// @dev Freezes a complete epoch: fixes its shares of the current free balance, credits the
    /// validator share, reserves what it credits and sends the proving share to the Inbox.
    /// @param _epoch The epoch.
    /// @param _record The epoch's record.
    /// @param _committee The epoch's committee in MEM-08 order.
    function _freezeAndSettle(
        uint64 _epoch,
        EpochRecord storage _record,
        IEtnaInbox.CommitteeMember[] calldata _committee
    )
        private
    {
        require(keccak256(abi.encode(_committee)) == _record.committeeHash, CommitteeMismatch());

        uint256 reserved = reservedTotal;
        uint256 free = address(this).balance - reserved;
        uint256 alloc = free * allocValidatorPpm / _PPM;
        uint256 provingShare = free * allocProverPpm / _PPM;
        uint256 paid = _settle(_epoch, alloc, _committee);

        reservedTotal = reserved + paid;
        _record.alloc = alloc;
        _record.paid = paid;
        _record.provingShare = provingShare;
        _record.frozenAtL1 = uint64(block.number);

        // Sends nothing for a zero share.
        inbox.sendEtherAndVerify(provingShare);
        emit EpochFrozen(_epoch, alloc, paid, provingShare);
    }

    /// @dev Credits `_alloc` to the committee's registration owners by effective stake times
    /// signed heights, rounding each amount down. Counts at indices past the committee are
    /// ignored; members without a registration owner or with a zero amount are skipped.
    /// @param _epoch The epoch.
    /// @param _alloc The validator share to distribute.
    /// @param _committee The epoch's committee in MEM-08 order.
    /// @return paid_ The total credited.
    function _settle(
        uint64 _epoch,
        uint256 _alloc,
        IEtnaInbox.CommitteeMember[] calldata _committee
    )
        private
        returns (uint256 paid_)
    {
        if (_alloc == 0) return 0;

        (uint256[] memory weights, uint256 totalWeight) = _weights(_epoch, _committee);
        if (totalWeight == 0) return 0;

        for (uint256 i; i < weights.length; ++i) {
            if (weights[i] == 0) continue;
            uint256 amount = Math.mulDiv(_alloc, weights[i], totalWeight);
            if (amount != 0) paid_ += _credit(_epoch, i, _committee[i], amount);
        }
    }

    /// @dev Returns each member's weight, `effStake * count`, and their sum.
    /// @param _epoch The epoch.
    /// @param _committee The epoch's committee in MEM-08 order.
    /// @return weights_ The weight per member index.
    /// @return total_ The total weight.
    function _weights(
        uint64 _epoch,
        IEtnaInbox.CommitteeMember[] calldata _committee
    )
        private
        view
        returns (uint256[] memory weights_, uint256 total_)
    {
        mapping(uint256 => uint256) storage words = _signedCounts[_epoch];
        uint256 n = _committee.length;
        weights_ = new uint256[](n);
        uint256 word;
        for (uint256 i; i < n; ++i) {
            if (i & 7 == 0) word = words[i >> 3];
            uint256 count = uint32(word >> ((i & 7) << 5));
            if (count == 0) continue;
            uint256 weight = _committee[i].effStake * count;
            weights_[i] = weight;
            total_ += weight;
        }
    }

    /// @dev Credits one member's amount to the owner of its registration, if it has one.
    /// @param _epoch The epoch.
    /// @param _index The member's MEM-08 index.
    /// @param _member The member.
    /// @param _amount The member's amount.
    /// @return credited_ `_amount`, or zero if the registration has no owner.
    function _credit(
        uint64 _epoch,
        uint256 _index,
        IEtnaInbox.CommitteeMember calldata _member,
        uint256 _amount
    )
        private
        returns (uint256 credited_)
    {
        address registrationOwner = IEtnaStakingRegistry(stakingRegistry)
            .registrationOwnerOf(_member.bondId, _member.activeFromL1);
        if (registrationOwner == address(0)) return 0;

        _credits[registrationOwner] += _amount;
        emit ValidatorRewarded(_epoch, _index, _member.bondId, registrationOwner, _amount);
        return _amount;
    }

    // ---------------------------------------------------------------
    // Custom Errors
    // ---------------------------------------------------------------

    error CommitteeMismatch();
    error EpochAlreadyFrozen();
    error InvalidAllocation();
    error SettlementCountMismatch();
    error UnauthorizedSender();
    error ZeroCommitteeHash();
}
