// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "forge-std/src/Test.sol";

import { TrailblazersBadgesV4 } from
    "../../contracts/trailblazers-season-2/TrailblazersS1BadgesV4.sol";

contract TrailblazerBadgesS1MintTo is TrailblazersBadgesV4 {
    function mintTo(address _minter, uint256 _badgeId) public onlyOwner {
        if (_badgeId > BADGE_SHINTO) revert INVALID_BADGE_ID();

        uint256 tokenId = totalSupply() + 1;
        badges[tokenId] = _badgeId;

        _mint(_minter, tokenId);

        emit BadgeCreated(tokenId, _minter, _badgeId);
    }

    function call() public view returns (bool) {
        return true;
    }
}
