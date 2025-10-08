// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/governance/Controller.sol";
/// @title TaikoDAOController
/// @notice This contract maintains ownership of all contracts and assets, and is itself owned by
/// the TaikoDAO. This architecture allows the TaikoDAO to seamlessly transition from one DAO to
/// another by simply changing the owner of this contract. In essence, the TaikoDAO does not
/// directly own contracts or any assets.
/// @custom:deprecated This contract is deprecated. Only security-related bugs should be fixed.
/// No other changes should be made to this code.
/// @custom:security-contact security@taiko.xyz

contract TaikoDAOController is Controller {
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
}
