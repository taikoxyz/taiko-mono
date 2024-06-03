// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { ERC1155Upgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import { ECDSAWhitelist } from "./ECDSAWhitelist.sol";
import { IMinimalBlacklist } from "@taiko/blacklist/IMinimalBlacklist.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

contract TrailblazersBadges is ERC1155Upgradeable, ECDSAWhitelist {
    uint256[48] private __gap;
/// @notice Base URI required to interact with IPFS
    string private _baseURIExtended;

    function initialize(
        address _owner,
        string memory _rootURI,
        address _mintSigner,
        IMinimalBlacklist _blacklistAddress
    )
        external
        initializer
    {
        __ERC1155_init(_rootURI);
        _baseURIExtended = _rootURI;
        __ECDSAWhitelist_init(_owner, _mintSigner, _blacklistAddress);
    }

    function uri(uint256 _badgeId) public view override returns (string memory) {
        return string(abi.encodePacked(_baseURIExtended, Strings.toString(_badgeId)));
    }


}
