// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { ERC1155Upgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import { MerkleWhitelist } from "../common/MerkleWhitelist.sol";
import { IMinimalBlacklist } from "@taiko/blacklist/IMinimalBlacklist.sol";

contract TrailblazersBadges is ERC1155Upgradeable, MerkleWhitelist {
    // badgeId => ipfsBadgeURI

    uint256[48] private __gap;

    function initialize(
        address _owner,
        string memory _rootURI,
        bytes32 _merkleRoot,
        IMinimalBlacklist _blacklistAddress
    )
        external
        initializer
    {
        __ERC1155_init(_rootURI);
        __MerkleWhitelist_init(_owner, _merkleRoot, _blacklistAddress);
    }
}
