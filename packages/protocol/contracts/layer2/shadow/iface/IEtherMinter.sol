// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

/// @custom:security-contact security@taiko.xyz

interface IEtherMinter {
    /// @notice Mints canonical ETH to the specified recipient.
    function mintEther(address _recipient, uint256 _amount) external;
}
