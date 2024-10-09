// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "forge-std/src/Test.sol";

import { TrailblazersBadges } from "../../contracts/trailblazers-badges/TrailblazersBadges.sol";

contract TrailblazerBadgesS1MintTo is TrailblazersBadges {
    function mintTo(address _minter, uint256 _badgeId) public onlyOwner {
        if (_badgeId > BADGE_SHINTO) revert INVALID_BADGE_ID();

        uint256 tokenId = totalSupply() + 1;
        badges[tokenId] = _badgeId;

        _mint(_minter, tokenId);

        emit BadgeCreated(tokenId, _minter, _badgeId);
    }

    function version() public pure returns (string memory) {
        return "mock";
    }
}
