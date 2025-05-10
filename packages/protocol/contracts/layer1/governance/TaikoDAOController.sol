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

    bytes32[50] private __gap;

    constructor() EssentialContract(address(0)) { }

    function init(address _taikoDAO) external initializer {
        __Essential_init(_taikoDAO);
    }

    receive() external payable { }

    /// @notice Forward arbitrary calls to another contract.
    ///         This lets TaikoDAOController directly interact with contracts it owns.
    /// @param _target The contract to call
    /// @param _value The value to send with the call
    /// @param _data   Encoded function call + arguments
    /// @return result_ The raw returned data from the call
    function execute(
        address _target,
        uint256 _value,
        bytes calldata _data
    )
        external
        nonReentrant
        onlyOwner
        returns (bytes memory result_)
    {
        require(_target != owner(), InvalidTarget());
        require(_target != address(this), InvalidTarget());

        bool success;
        (success, result_) = _target.call{ value: _value }(_data);
        require(success, CallFailed());
    }

    /// @notice Accept ownership of the given contract.
    /// @dev This function is callable by anyone to accept ownership without going through
    /// the TaikoDAO.
    /// @param _contractToOwn The contract to accept ownership of.
    function acceptOwnershipOf(address _contractToOwn) external {
        Ownable2StepUpgradeable(_contractToOwn).acceptOwnership();
    }
}
