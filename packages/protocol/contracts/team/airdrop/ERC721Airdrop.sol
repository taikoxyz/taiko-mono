// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./MerkleClaimable.sol";

/// @title ERC721Airdrop
/// @custom:security-contact security@taiko.xyz
contract ERC721Airdrop is MerkleClaimable {
    address public token;
    address public vault;
    uint256[48] private __gap;

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
        _Essential_init(_owner);
        _MerkleClaimable_init(_claimStart, _claimEnd, _merkleRoot);

        token = _token;
        vault = _vault;
    }

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
