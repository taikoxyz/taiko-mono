// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./LibFasterReentryLock.sol";
import "src/shared/governance/Controller.sol";

/// @title MainnetDAOController
/// @notice This contract maintains ownership of all contracts and assets, and is itself owned by
/// the TaikoDAO. This architecture allows the TaikoDAO to seamlessly transition from one DAO to
/// another by simply changing the owner of this contract. In essence, the TaikoDAO does not
/// directly own contracts or any assets.
/// @custom:security-contact security@taiko.xyz
contract MainnetDAOController is Controller {
    bytes32[50] private __gap;

    function init(address _taikoDAO) external initializer {
        __Essential_init(_taikoDAO);
    }

    /// @notice Execute a list of actions.
    /// @param _actions The actions to execute
    /// @return results_ The raw returned data from the action
    function execute(bytes calldata _actions)
        external
        nonReentrant
        onlyOwner
        returns (bytes[] memory results_)
    {
        return _executeActions(_actions);
    }

    // ---------------------------------------------------------------
    // Internal Functions
    // ---------------------------------------------------------------

    function _storeReentryLock(uint8 _reentry) internal override {
        LibFasterReentryLock.storeReentryLock(_reentry);
    }

    function _loadReentryLock() internal view override returns (uint8) {
        return LibFasterReentryLock.loadReentryLock();
    }
}

// Storage Layout ---------------------------------------------------------------
// solhint-disable max-line-length
//
//   _initialized                   | uint8                                              | Slot: 0    | Offset: 0    | Bytes: 1
//   _initializing                  | bool                                               | Slot: 0    | Offset: 1    | Bytes: 1
//   __gap                          | uint256[50]                                        | Slot: 1    | Offset: 0    | Bytes: 1600
//   _owner                         | address                                            | Slot: 51   | Offset: 0    | Bytes: 20
//   __gap                          | uint256[49]                                        | Slot: 52   | Offset: 0    | Bytes: 1568
//   _pendingOwner                  | address                                            | Slot: 101  | Offset: 0    | Bytes: 20
//   __gap                          | uint256[49]                                        | Slot: 102  | Offset: 0    | Bytes: 1568
//   __gapFromOldAddressResolver    | uint256[50]                                        | Slot: 151  | Offset: 0    | Bytes: 1600
//   __reentry                      | uint8                                              | Slot: 201  | Offset: 0    | Bytes: 1
//   __paused                       | uint8                                              | Slot: 201  | Offset: 1    | Bytes: 1
//   __gap                          | uint256[49]                                        | Slot: 202  | Offset: 0    | Bytes: 1568
//   __reserved0                    | uint256                                            | Slot: 251  | Offset: 0    | Bytes: 32
//   lastExecutionId                | uint64                                             | Slot: 252  | Offset: 0    | Bytes: 8
//   __reserved1                    | address                                            | Slot: 252  | Offset: 8    | Bytes: 20
//   __gap                          | uint256[48]                                        | Slot: 253  | Offset: 0    | Bytes: 1536
//   __gap                          | bytes32[50]                                        | Slot: 301  | Offset: 0    | Bytes: 1600
// solhint-enable max-line-length
