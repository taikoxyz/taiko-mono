// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title PermissionlessExecutor
/// @notice This contract is used to execute L1->L2 DAO messages as ` message.destOwner`.
/// @custom:security-contact security@taiko.xyz
contract PermissionlessExecutor {
    function execute(address _target, bytes calldata _data) external payable {
        (bool success, bytes memory result) = _target.call{ value: msg.value }(_data);
        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }
}
