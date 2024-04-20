// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/governance/utils/IVotes.sol";
import "./MerkleClaimable.sol";

/// @title ERC20Airdrop
/// @notice Contract for managing Taiko token airdrop for eligible users.
/// @custom:security-contact security@taiko.xyz
contract ERC20Airdrop is MerkleClaimable {
    using SafeERC20 for IERC20;

    /// @notice The address of the Taiko token contract.
    address public token;

    /// @notice The address of the vault contract.
    address public vault;

    uint256[48] private __gap;

    /// @notice Initializes the contract.
    /// @param _owner The owner of this contract.
    /// @param _claimStart The start time of the claim period.
    /// @param _claimEnd The end time of the claim period.
    /// @param _merkleRoot The merkle root.
    /// @param _token The address of the token contract.
    /// @param _vault The address of the vault contract.
    function init(
        address _owner,
        uint64 _claimStart,
        uint64 _claimEnd,
        bytes32 _merkleRoot,
        address _token,
        address _vault
    )
        external
        initializer
    {
        __Essential_init(_owner);
        __MerkleClaimable_init(_claimStart, _claimEnd, _merkleRoot);

        token = _token;
        vault = _vault;
    }

    /// @notice Claims the airdrop for the user.
    /// @param user The address of the user.
    /// @param amount The amount of tokens to claim.
    /// @param proof The merkle proof.
    function claim(address user, uint256 amount, bytes32[] calldata proof) external nonReentrant {
        // Check if this can be claimed
        _verifyClaim(abi.encode(user, amount), proof);

        // Transfer the tokens
        IERC20(token).safeTransferFrom(vault, user, amount);
    }
}
