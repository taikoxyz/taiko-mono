// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../../../shared/common/EssentialContract.sol";
import "../iface/ILookahead.sol";
import "../iface/IPreconfRegistry.sol";
import "../iface/IPreconfServiceManager.sol";
import "../libs/LibNames.sol";
import "../libs/LibEpoch.sol";

/// @title PreconfTaskManager
/// @custom:security-contact security@taiko.xyz
contract Lookahead is ILookahead, EssentialContract {
    using LibEpoch for uint256;

    uint256 private constant DISPUTE_PERIOD = 1 days;

    // Maps the epoch timestamp to the lookahead poster.
    // If the lookahead poster has been slashed, it maps to the 0-address.
    // Note: This may be optimised to re-use existing slots and reduce gas cost.
    mapping(uint256 epochTimestamp => address poster) internal posters;
    uint64 internal lookaheadTail;

    uint256[49] private __gap;

    bytes32 public immutable DOMAIN_SEPARATOR;

    error PreconferNotRegistered();
    error LookaheadIsNotRequired();

    uint256 public immutable beaconGenesisTimestamp;

    modifier onlyFromPreconfer() {
        address registry = resolve(LibNames.B_PRECONF_REGISTRY, false);
        require(
            IPreconfRegistry(registry).getPreconferIndex(msg.sender) != 0, PreconferNotRegistered()
        );
        _;
    }

    modifier lockPreconferStake() {
        _;
        IPreconfServiceManager(resolve(LibNames.B_PRECONF_SERVICE_MANAGER, false)).lockStakeUntil(
            msg.sender, block.timestamp + DISPUTE_PERIOD
        );
    }

    constructor(uint256 _beaconGenesisTimestamp) {
        beaconGenesisTimestamp = _beaconGenesisTimestamp;
    }

    /// @notice Initializes the contract.
    function init(address _owner, address _rollupAddressManager) external initializer {
        __Essential_init(_owner, _rollupAddressManager);
    }

    /// @inheritdoc ILookahead
    function forcePostLookahead(LookaheadParam[] calldata _lookaheadParams)
        external
        onlyFromPreconfer
        nonReentrant
    {
        // Lookahead must be missing
        uint256 epochTimestamp = block.timestamp.getEpochTimestamp(beaconGenesisTimestamp);

        if (_isLookaheadRequired(epochTimestamp)) {
            _postLookahead(epochTimestamp, _lookaheadParams);
        } else {
            revert LookaheadIsNotRequired();
        }
    }

    /// @inheritdoc ILookahead
    function postLookahead(LookaheadParam[] calldata _lookaheadParams)
        external
        onlyFromNamed(LibNames.B_PRECONF_SERVICE_MANAGER)
        nonReentrant
    {
        uint256 epochTimestamp = block.timestamp.getEpochTimestamp(beaconGenesisTimestamp);

        if (_isLookaheadRequired(epochTimestamp)) {
            _postLookahead(epochTimestamp, _lookaheadParams);
        } else {
            require(_lookaheadParams.length == 0, LookaheadIsNotRequired());
        }
    }

    /// @inheritdoc ILookahead
    function isCurrentPreconfer(address addr) external view returns (bool) {
        //
    }

    function _postLookahead(
        uint256 _currentEpochTimestamp,
        LookaheadParam[] calldata _lookaheadParams
    )
        internal
        lockPreconferStake
    {
        uint256 nextEpochTimestamp;
        uint256 nextEpochEndTimestamp;

        unchecked {
            nextEpochTimestamp = _currentEpochTimestamp + LibEpoch.SECONDS_IN_EPOCH;
            nextEpochEndTimestamp = nextEpochTimestamp + LibEpoch.SECONDS_IN_EPOCH;
        }

        // The tail of the lookahead is tracked and connected to the first new lookahead entry so
        // that when no more preconfers are present in the remaining slots of the current epoch,
        // the next epoch's preconfer may start preconfing in advanced.
        //
        // --[]--[]--[p1]--[]--[]---|---[]--[]--[P2]--[]--[]
        //   1   2    3    4   5        6    7    8   9   10
        //         Epoch 1                     Epoch 2
        //
        // Here, P2 may start preconfing and proposing blocks from slot 4 itself
        //
    }

    function _isLookaheadRequired(uint256 _epochTimestamp) internal view returns (bool) {
        // If it's the first slot of current epoch, we don't need the lookahead since the offchain
        // node may not have access to it yet.
        unchecked {
            return block.timestamp != _epochTimestamp
                && posters[_epochTimestamp + LibEpoch.SECONDS_IN_EPOCH] == address(0);
        }
    }
}
