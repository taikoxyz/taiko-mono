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

    constructor(uint256 _beaconGenesisTimestamp) {
        beaconGenesisTimestamp = _beaconGenesisTimestamp;
    }

    function forceUpdateLookahead(LookaheadSetParam[] calldata _lookaheadSetParams)
        external
        onlyFromPreconfer
        nonReentrant
    {
        // Lookahead must be missing
        (uint256 currentEpochTimestamp, uint256 nextEpochTimestamp) =
            block.timestamp.getEpochTimestamp(beaconGenesisTimestamp);

        if (!_isLookaheadRequired(currentEpochTimestamp, nextEpochTimestamp)) {
            revert LookaheadIsNotRequired();
        }

        // Update the lookahead for next epoch
        _updateLookahead(nextEpochTimestamp, _lookaheadSetParams);

        // Block the preconfer from withdrawing stake from Eigenlayer during the dispute window
        unchecked {
            IPreconfServiceManager(resolve(LibNames.B_PRECONF_SERVICE_MANAGER, false))
                .lockStakeUntil(msg.sender, block.timestamp + DISPUTE_PERIOD);
        }
    }

    function updateLookahead(LookaheadSetParam calldata _lookaheadSetParams)
        external
        onlyFromNamed(LibNames.B_PRECONF_SERVICE_MANAGER)
        nonReentrant
    { }

    function isCurrentPreconfer(address addr) external view returns (bool) {
        //
    }

    function isLookaheadRequired() external view returns (bool) {
        (uint256 currentEpochTimestamp, uint256 nextEpochTimestamp) =
            block.timestamp.getEpochTimestamp(beaconGenesisTimestamp);

        return _isLookaheadRequired(currentEpochTimestamp, nextEpochTimestamp);
    }

    function _updateLookahead(
        uint256 _epochTimestamp,
        LookaheadSetParam[] calldata _lookaheadSetParams
    )
        private
    {
        // TODO
    }

    function _isLookaheadRequired(
        uint256 _currentEpochTimestamp,
        uint256 _nextEpochTimestamp
    )
        private
        view
        returns (bool)
    {
        // TODO
    }
}
