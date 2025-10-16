// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/common/EssentialContract.sol";
import "src/shared/libs/LibBytes.sol";

/// @title Controller
/// @notice The base contract for controllers, which act as owners of other contracts and can hold
/// Ether and tokens.
/// @custom:security-contact security@taiko.xyz
abstract contract Controller is EssentialContract {
    event DryrunGasCost(uint256 gasUsed);

    error DryrunSucceeded();

    struct Action {
        address target;
        uint256 value;
        bytes data;
    }

    // __reserved0 and __reserved1 are preserved for storage layout compatibility.

    // solhint-disable var-name-mixedcase
    uint256 private __reserved0;

    /// @notice The last processed execution ID.
    uint64 public lastExecutionId; // slot 2

    // solhint-disable var-name-mixedcase
    address private __reserved1;
    uint256[48] private __gap;

    event ActionExecuted(address indexed target, uint256 value, bytes data);

    receive() external payable { }

    /// @notice Accept ownership of the given contract.
    /// @dev This function is callable by anyone to accept ownership without going through
    /// the TaikoDAO.
    /// @param _contractToOwn The contract to accept ownership of.
    function acceptOwnershipOf(address _contractToOwn) external nonReentrant {
        Ownable2StepUpgradeable(_contractToOwn).acceptOwnership();
    }

    function dryrun(bytes calldata _actions) external payable {
        uint256 gas = gasleft();
        _executeActions(_actions);
        emit DryrunGasCost(gas - gasleft());

        // Always revert!
        revert DryrunSucceeded();
    }

    /// @notice Execute a list of actions.
    /// @param _actions The actions to execute
    /// @return results_ The raw returned data from the action
    function _executeActions(bytes calldata _actions) internal returns (bytes[] memory results_) {
        Action[] memory actions = abi.decode(_actions, (Action[]));
        results_ = new bytes[](actions.length);
        for (uint256 i; i < actions.length; ++i) {
            results_[i] = _executeAction(actions[i]);
        }
    }

    /// @notice Execute a single action.
    /// @param _action The action to execute
    /// @return result_ The raw returned data from the action
    function _executeAction(Action memory _action) internal returns (bytes memory result_) {
        bool success;
        (success, result_) = _action.target.call{ value: _action.value }(_action.data);
        if (!success) LibBytes.revertWithExtractedError(result_);

        emit ActionExecuted(_action.target, _action.value, _action.data);
    }
}
