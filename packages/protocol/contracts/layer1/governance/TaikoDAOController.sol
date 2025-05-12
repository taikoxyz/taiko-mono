// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/common/EssentialContract.sol";

/// @title TaikoDAOController
/// @notice This contract maintains ownership of all contracts and assets, and is itself owned by
/// the TaikoDAO. This architecture allows the TaikoDAO to seamlessly transition from one DAO to
/// another by simply changing the owner of this contract. In essence, the TaikoDAO does not
/// directly own contracts or any assets.
/// @custom:security-contact security@taiko.xyz
contract TaikoDAOController is EssentialContract {
    error CallFailed();
    error InvalidTarget();
    error NoCallToExecute();

    struct Call {
        address target;
        uint256 value;
        bytes data;
    }

    bytes32[50] private __gap;

    function init(address _taikoDAO) external initializer {
        __Essential_init(_taikoDAO);
    }

    receive() external payable { }

    /// @notice Forward arbitrary calls to another contract.
    ///         This lets TaikoDAOController directly interact with contracts it owns.
    /// @param _calls The calls to execute
    /// @return results_ The raw returned data from the call
    function execute(Call[] calldata _calls)
        external
        nonReentrant
        onlyOwner
        returns (bytes[] memory results_)
    {
        require(_calls.length != 0, NoCallToExecute());
        results_ = new bytes[](_calls.length);
        for (uint256 i; i < _calls.length; ++i) {
            results_[i] = _executeCall(_calls[i]);
        }
    }

    /// @notice Accept ownership of the given contract.
    /// @dev This function is callable by anyone to accept ownership without going through
    /// the TaikoDAO.
    /// @param _contractToOwn The contract to accept ownership of.
    function acceptOwnershipOf(address _contractToOwn) external {
        Ownable2StepUpgradeable(_contractToOwn).acceptOwnership();
    }

    function _executeCall(Call calldata _call) internal returns (bytes memory result_) {
        require(_call.target != owner(), InvalidTarget());
        require(_call.target != address(this), InvalidTarget());

        bool success;
        (success, result_) = _call.target.call{ value: _call.value }(_call.data);
        require(success, CallFailed());
    }
}
