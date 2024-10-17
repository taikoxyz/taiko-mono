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

    address public migrationContract;

    error INVALID_S2_CONTRACT();

    function setMigrationContract(address _migrationContract) public onlyOwner {
        migrationContract = _migrationContract;
    }

    modifier onlyMigrationContract() {
        if (msg.sender != migrationContract) revert INVALID_S2_CONTRACT();
        _;
    }

    function burn(uint256 _tokenId) public onlyMigrationContract {
        _burn(_tokenId);
    }
}
