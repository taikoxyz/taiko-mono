// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.24;

import { TaikoPartyTicket } from "./TaikoPartyTicket.sol";

/// @title TaikoPartyTicketV2
/// @dev Upgrade to support Golden Ticket (winner of winners, singular) ticket
/// @custom:security-contact security@taiko.xyz
contract TaikoPartyTicketV2 is TaikoPartyTicket {
    /// @notice Get the version of the contract
    /// @return The version of the contract
    function version() public pure returns (string memory) {
        return "v2";
    }

    /// @notice Get individual token's URI
    /// @param tokenId The token ID
    /// @return The token URI
    /// @dev re-implemented to support golden winner
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        if (winnerIds.length == 0) {
            return string(abi.encodePacked(baseURI, "/raffle.json"));
        } else if (winners[tokenId] && winnerIds[0] == tokenId) {
            return string(abi.encodePacked(baseURI, "/golden-winner.json"));
        } else if (winners[tokenId]) {
            return string(abi.encodePacked(baseURI, "/winner.json"));
        } else {
            return string(abi.encodePacked(baseURI, "/loser.json"));
        }
    }

    /// @notice Checks if a tokenId is the golden winner
    /// @param tokenId The token ID
    /// @return True if the token is the golden winner
    function isGoldenWinner(uint256 tokenId) public view returns (bool) {
        return winners[tokenId] && winnerIds[0] == tokenId;
    }

    /// @notice Checks if an account has a golden winner token
    /// @param account The account address
    /// @return True if the account has a golden winner
    function isGoldenWinner(address account) public view returns (bool) {
        for (uint256 i = 0; i < balanceOf(account); i++) {
            if (isGoldenWinner(tokenOfOwnerByIndex(account, i))) {
                return true;
            }
        }
        return false;
    }
}
