// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./TrailblazersBadges.sol";

contract TrailblazersBadgesV3 is TrailblazersBadges {
    function version() external pure returns (string memory) {
        return "V3";
    }

    function _update(
        address to,
        uint256 tokenId,
        address auth
    )
        internal
        virtual
        override
        returns (address)
    {
        if (blacklist.isBlacklisted(_msgSender())) revert ADDRESS_BLACKLISTED();
        return super._update(to, tokenId, auth);
    }
}
