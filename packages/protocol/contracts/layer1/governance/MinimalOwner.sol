// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title MinimalOwner
/// @notice
///   A minimal contract that can:
///   1) Own other contracts (receive ownership transfers),
///   2) Transfer ownership (for example, to Taiko DAO),
///   3) Forward arbitrary calls (execute) to any address, restricted by onlyOwner.
/// @custom:security-contact security@taiko.xyz
contract MinimalOwner {
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error NotOwner();
    error ZeroAddress();
    error SameAddress();
    error CallFailed();

    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, NotOwner());
        _;
    }

    constructor(address _owner) {
        require(_owner != address(0), ZeroAddress());
        owner = _owner;
    }

    /// @notice Transfer ownership of this contract to a new address
    ///         (e.g. from an EOA to B, or from B to another address).
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), ZeroAddress());
        require(newOwner != owner, SameAddress());
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    /// @notice Forward arbitrary calls to another contract.
    ///         This lets MinimalOwner directly interact with contracts it owns.
    ///
    /// @param target The contract to call
    /// @param data   Encoded function call + arguments
    /// @return result The raw returned data from the call
    function forwardCall(
        address target,
        bytes calldata data
    )
        external
        payable
        onlyOwner
        returns (bytes memory result)
    {
        (bool success, bytes memory returnData) = target.call{ value: msg.value }(data);
        require(success, CallFailed());
        return returnData;
    }
}
