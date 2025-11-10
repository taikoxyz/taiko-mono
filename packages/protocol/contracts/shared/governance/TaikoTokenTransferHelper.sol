// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title TaikoTokenTransferHelper
/// @notice Helper contract to transfer all TAIKO tokens from Controller to Treasury
/// @dev This contract ensures the transfer amount is determined at execution time, not proposal
/// build time. The Controller must first approve this contract to spend its tokens.
/// @custom:security-contact security@taiko.xyz
contract TaikoTokenTransferHelper {
    /// @notice Transfers the entire TAIKO token balance from a source to a recipient
    /// @param _token The TAIKO token address
    /// @param _from The source address (controller.taiko.eth) - must have approved this contract
    /// @param _to The recipient address (treasury.taiko.eth)
    function transferAllFrom(address _token, address _from, address _to) external {
        uint256 balance = IERC20(_token).balanceOf(_from);
        require(balance > 0, "TaikoTokenTransferHelper: zero balance");
        require(
            IERC20(_token).transferFrom(_from, _to, balance),
            "TaikoTokenTransferHelper: transfer failed"
        );
    }
}
