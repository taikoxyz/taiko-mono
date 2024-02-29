// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/governance/utils/IVotes.sol";
import "./MerkleClaimable.sol";

/// @title ERC20Airdrop
/// @notice Contract for managing Taiko token airdrop for eligible users.
/// @custom:security-contact security@taiko.xyz
contract ERC20Airdrop is MerkleClaimable {
    /// @notice The address of the token contract.
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

    /// @notice Claims the airdrop for the user and delegates the voting power to the delegatee.
    /// @param user The address of the user.
    /// @param amount The amount of tokens to claim.
    /// @param proof The merkle proof.
    /// @param delegationData The data for delegating the voting power.
    function claimAndDelegate(
        address user,
        uint256 amount,
        bytes32[] calldata proof,
        bytes calldata delegationData
    )
        external
        nonReentrant
    {
        // Check if this can be claimed
        _verifyClaim(abi.encode(user, amount), proof);

        // Transfer the tokens
        IERC20(token).transferFrom(vault, user, amount);

        // Delegate the voting power to delegatee.
        // Note that the signature (v,r,s) may not correspond to the user address,
        // but since the data is provided by Taiko backend, it's not an issue even if
        // client can change the data to call delegateBySig for another user.
        (address delegatee, uint256 nonce, uint256 expiry, uint8 v, bytes32 r, bytes32 s) =
            abi.decode(delegationData, (address, uint256, uint256, uint8, bytes32, bytes32));
        IVotes(token).delegateBySig(delegatee, nonce, expiry, v, r, s);
    }
}
