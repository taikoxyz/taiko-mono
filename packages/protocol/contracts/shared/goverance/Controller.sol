// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/common/EssentialContract.sol";

/// @title Controller
/// @notice The base contract for controllers, which act as owners of other contracts and can hold
/// Ether and tokens.
/// @custom:security-contact security@taiko.xyz
abstract contract Controller is EssentialContract {
    error ActionFailed();
    error DryrunSucceeded();

    struct Action {
        address target;
        uint256 value;
        bytes data;
    }

    // For backward compatibility reasons, this contract reserves no storage slots.
    // bytes32[50] private __gap;

    event ActionExecuted(address indexed target, uint256 value, bytes data);

    constructor() EssentialContract() { }

    receive() external payable { }

    /// @notice Accept ownership of the given contract.
    /// @dev This function is callable by anyone to accept ownership without going through
    /// the TaikoDAO.
    /// @param _contractToOwn The contract to accept ownership of.
    function acceptOwnershipOf(address _contractToOwn) external nonReentrant {
        Ownable2StepUpgradeable(_contractToOwn).acceptOwnership();
    }

    function dryrun(Action[] calldata _actions) external payable {
        _executeActions(_actions);
        revert DryrunSucceeded();
    }

    /// @notice Execute a list of actions.
    /// @param _actions The actions to execute
    /// @return results_ The raw returned data from the action
    function _executeActions(Action[] memory _actions) internal returns (bytes[] memory results_) {
        results_ = new bytes[](_actions.length);
        for (uint256 i; i < _actions.length; ++i) {
            results_[i] = _executeAction(_actions[i]);
        }
    }

    /// @notice Execute a single action.
    /// @param _action The action to execute
    /// @return result_ The raw returned data from the action
    function _executeAction(Action memory _action) internal returns (bytes memory result_) {
        bool success;
        (success, result_) = _action.target.call{ value: _action.value }(_action.data);
        require(success, ActionFailed());
        emit ActionExecuted(_action.target, _action.value, _action.data);
    }
}
