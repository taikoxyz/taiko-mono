// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title ERC20Airdrop
/// @notice Contract for managing Taiko token airdrop for eligible users.
/// @custom:security-contact security@taiko.xyz
contract AirdropVault is Ownable {
    using SafeERC20 for IERC20;

    /// @notice The address of the Taiko token contract.
    IERC20 public token;

    /// @notice Initializes the contract.
    /// @param _token The address of the TKO token contract.
    constructor(IERC20 _token) Ownable(_msgSender()) {
        token = _token;
        transferOwnership(_msgSender());
    }

    /// @notice Withdraw ERC20 tokens from the Vault
    /// @param _token The ERC20 token address to withdraw
    /// @dev Only the owner can execute this function
    function withdrawERC20(IERC20 _token) external onlyOwner {
        // If token address is address(0), use token
        if (address(_token) == address(0)) {
            _token = token;
        }
        // Transfer the tokens to owner
        token.transfer(owner(), token.balanceOf(address(this)));
    }

    /// @notice Approves the airdrop contract to spend a certain amount of tokens
    /// @param amount The amount of tokens to approve, should equals airdrop amount
    /// @dev Only the owner can execute this function
    function approveAirdropContractAsSpender(
        address airdropContract,
        uint256 amount
    )
        external
        onlyOwner
    {
        token.approve(airdropContract, amount);
    }
}
