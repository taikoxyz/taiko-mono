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

    error MINTER_NOT_WHITELISTED();
    error INVALID_INPUT();

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

    function mint(bytes memory _signature, uint256 _badgeId) public {
        if (!canMint(_signature, _msgSender(), _badgeId)) revert MINTER_NOT_WHITELISTED();
        _mintBadgeTo(_msgSender(), _badgeId);
    }

    function mint(bytes memory _signature, address _minter, uint256 _badgeId) public onlyOwner {
        if (!canMint(_signature, _minter, _badgeId)) revert MINTER_NOT_WHITELISTED();

        _mintBadgeTo(_minter, _badgeId);
    }

    function _mintBadgeTo(address _to, uint256 _id) internal {
        _mint(
            _to,
            _id,
            1, // amount
            "" // empty data
        );
    }
}
