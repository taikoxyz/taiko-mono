// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./MerkleClaimable.sol";

/// @title ERC721Airdrop
/// @custom:security-contact security@taiko.xyz
contract ERC721Airdrop is MerkleClaimable {
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

    /// @notice Claims the airdrop for the user.
    /// @param user The address of the user.
    /// @param tokenIds The token IDs to claim.
    /// @param proof The merkle proof.
    function claim(
        address user,
        uint256[] calldata tokenIds,
        bytes32[] calldata proof
    )
        external
        nonReentrant
    {
        // Check if this can be claimed
        _verifyClaim(abi.encode(user, tokenIds), proof);

        // Transfer the tokens
        for (uint256 i; i < tokenIds.length; ++i) {
            IERC721(token).safeTransferFrom(vault, user, tokenIds[i]);
        }
    }
}
