// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/
//
//   Email: security@taiko.xyz
//   Website: https://taiko.xyz
//   GitHub: https://github.com/taikoxyz
//   Discord: https://discord.gg/taikoxyz
//   Twitter: https://twitter.com/taikoxyz
//   Blog: https://mirror.xyz/labs.taiko.eth
//   Youtube: https://www.youtube.com/@taikoxyz

pragma solidity 0.8.24;

import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
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
        __Essential_init(_owner);
        __MerkleClaimable_init(_claimStart, _claimEnd, _merkleRoot);

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
            IERC721Upgradeable(token).safeTransferFrom(vault, user, tokenIds[i]);
        }
    }
}
