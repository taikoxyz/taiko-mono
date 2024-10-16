// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../trailblazers-badges/TrailblazersBadgesV3.sol";

contract TrailblazersBadgesV4 is TrailblazersBadgesV3 {
    function version() external pure virtual override returns (string memory) {
        return "V4";
    }

    // disable blacklist block
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
        return super._update(to, tokenId, auth);
    }

    address public season2BadgeContract;

    error INVALID_S2_CONTRACT();

    function setSeason2BadgeContract(address _season2BadgeContract) public onlyOwner {
        season2BadgeContract = _season2BadgeContract;
    }

    modifier onlySeason2BadgeContract() {
        if (msg.sender != season2BadgeContract) revert INVALID_S2_CONTRACT();
        _;
    }

    function burn(uint256 _tokenId) public onlySeason2BadgeContract {
        _burn(_tokenId);
    }
}
