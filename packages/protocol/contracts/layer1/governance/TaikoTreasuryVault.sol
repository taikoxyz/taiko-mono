// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/common/EssentialContract.sol";

/// @title TaikoTreasuryVault
/// @notice A contract for managing the Taiko treasury assets. This contract shall be owned by the
/// Taiko DAO.
/// @custom:security-contact security@taiko.xyz
contract TaikoTreasuryVault is EssentialContract {
    error CallFailed();
    error InvalidTarget();

    constructor() EssentialContract(address(0)) { }

    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    // Accept Ether transfers
    receive() external payable { }
    fallback() external payable { }

    /// @notice Executes a low-level call to any target with supplied calldata
    /// @param target Address of the contract to call
    /// @param value  Value to send with the call
    /// @param data   Calldata (function selector + arguments)
    function forwardCall(
        address target,
        uint256 value,
        bytes calldata data
    )
        external
        nonReentrant
        onlyOwner
        returns (bytes memory)
    {
        require(target != address(this), InvalidTarget());
        (bool success, bytes memory result) = payable(target).call{ value: value }(data);
        require(success, CallFailed());
        return result;
    }
}
