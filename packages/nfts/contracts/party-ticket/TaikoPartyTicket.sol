// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import { ERC721EnumerableUpgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import { AccessControlUpgradeable } from
    "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { PausableUpgradeable } from
    "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { IMinimalBlacklist } from "@taiko/blacklist/IMinimalBlacklist.sol";

/// @title TaikoPartyTicket
/// @dev ERC-721 KBW Raffle & Party Tickets
/// @custom:security-contact security@taiko.xyz
contract TaikoPartyTicket is
    ERC721EnumerableUpgradeable,
    PausableUpgradeable,
    AccessControlUpgradeable
{
    event BlacklistUpdated(address _blacklist);

    /// @notice Owner role
    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");
    /// @notice Mint fee
    uint256 public mintFee;
    /// @notice Mint active flag
    bool public mintActive;
    /// @notice Token ID to winner mapping
    mapping(uint256 tokenId => bool isWinner) public winners;
    /// @notice Base URI required to interact with IPFS
    string public baseURI;
    /// @notice Winner base URI required to interact with IPFS
    string public winnerBaseURI;
    /// @notice Payout address
    address public payoutAddress;
    /// @notice Internal counter for token IDs
    uint256 private _nextTokenId;
    /// @notice Blackist address
    IMinimalBlacklist public blacklist;
    /// @notice Gap for upgrade safety
    uint256[47] private __gap;

    error INSUFFICIENT_MINT_FEE();
    error CANNOT_REVOKE_NON_WINNER();
    error ADDRESS_BLACKLISTED();

    /// @notice Contract initializer
    /// @param _payoutAddress The address to receive mint fees
    /// @param _mintFee The fee to mint a ticket
    /// @param _baseURI Base URI for the token metadata pre-raffle
    /// @param _blacklistAddress The address of the blacklist contract
    function initialize(
        address _payoutAddress,
        uint256 _mintFee,
        string memory _baseURI,
        IMinimalBlacklist _blacklistAddress
    )
        external
        initializer
    {
        __ERC721_init("TaikoPartyTicket", "TPT");

        mintFee = _mintFee;
        baseURI = _baseURI;
        payoutAddress = _payoutAddress;
        blacklist = _blacklistAddress;

        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(OWNER_ROLE, _payoutAddress);
    }

    /// @notice Update the blacklist address
    /// @param _blacklist The new blacklist address
    function updateBlacklist(IMinimalBlacklist _blacklist) external onlyRole(DEFAULT_ADMIN_ROLE) {
        blacklist = _blacklist;
        emit BlacklistUpdated(address(_blacklist));
    }

    /// @notice Get individual token's URI
    /// @param tokenId The token ID
    /// @return The token URI
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        if (winners[tokenId]) {
            return string(abi.encodePacked(baseURI, "/winner.json"));
        } else if (paused()) {
            return string(abi.encodePacked(baseURI, "/loser.json"));
        }
        return string(abi.encodePacked(baseURI, "/raffle.json"));
    }

    /// @notice Checks if a tokenId is a winner
    /// @param tokenId The token ID
    /// @return Whether the token is a winner
    function isWinner(uint256 tokenId) public view returns (bool) {
        return winners[tokenId];
    }

    /// @notice Checks if an address is a winner
    /// @param minter The address to check
    /// @return Whether the address is a winner
    function isWinner(address minter) public view returns (bool) {
        for (uint256 i = 0; i < balanceOf(minter); i++) {
            if (winners[tokenOfOwnerByIndex(minter, i)]) {
                return true;
            }
        }
        return false;
    }

    /// @notice Set the winners
    /// @param _winners The list of winning token ids
    function setWinners(uint256[] calldata _winners)
        external
        whenNotPaused
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        for (uint256 i = 0; i < _winners.length; i++) {
            winners[_winners[i]] = true;
        }
        pause();
    }

    /// @notice Set the base URI
    /// @param _baseURI The new base URI
    function setBaseURI(string memory _baseURI) external onlyRole(DEFAULT_ADMIN_ROLE) {
        baseURI = _baseURI;
    }

    /// @notice Set the winner base URI
    /// @param _winnerBaseURI The new winner base URI
    function setWinnerURI(string memory _winnerBaseURI) external onlyRole(DEFAULT_ADMIN_ROLE) {
        winnerBaseURI = _winnerBaseURI;
    }

    /// @notice Mint a raffle ticket
    /// @dev Requires a fee to mint
    /// @dev Requires the contract to not be paused
    function mint() external payable whenNotPaused {
        //if (blacklist.isBlacklisted(_msgSender())) revert ADDRESS_BLACKLISTED();
        if (msg.value < mintFee) revert INSUFFICIENT_MINT_FEE();
        uint256 tokenId = _nextTokenId++;
        _safeMint(msg.sender, tokenId);
    }

    /// @notice Mint multiple raffle tickets
    /// @param amount The number of tickets to mint
    /// @dev Requires a fee to mint
    /// @dev Requires the contract to not be paused
    function mint(uint256 amount) external payable whenNotPaused {
        //if (blacklist.isBlacklisted(_msgSender())) revert ADDRESS_BLACKLISTED();
        if (msg.value < mintFee * amount) revert INSUFFICIENT_MINT_FEE();
        for (uint256 i = 0; i < amount; i++) {
            uint256 tokenId = _nextTokenId++;
            _safeMint(msg.sender, tokenId);
        }
    }

    /// @notice Mint a raffle ticket
    /// @param to The address to mint to
    /// @dev Requires the contract to not be paused
    /// @dev Can only be called by the admin
    function mint(address to) public whenNotPaused onlyRole(DEFAULT_ADMIN_ROLE) {
        //if (blacklist.isBlacklisted(to)) revert ADDRESS_BLACKLISTED();
        uint256 tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
    }

    /// @notice Mint a winner ticket
    /// @param to The address to mint to
    /// @dev Requires calling as an admin
    function mintWinner(address to) public onlyRole(DEFAULT_ADMIN_ROLE) {
        //if (blacklist.isBlacklisted(to)) revert ADDRESS_BLACKLISTED();
        uint256 tokenId = _nextTokenId++;
        winners[tokenId] = true;
        _safeMint(to, tokenId);
    }

    /// @notice Revoke a winner and replace with a new winner
    /// @param revokeId The ID of the winner to revoke
    /// @param newWinnerId The ID of the new winner
    function revokeAndReplaceWinner(
        uint256 revokeId,
        uint256 newWinnerId
    )
        external
        whenPaused
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (!winners[newWinnerId]) revert CANNOT_REVOKE_NON_WINNER();
        winners[revokeId] = false;
        winners[newWinnerId] = true;
    }

    /// @notice Pause the contract
    /// @dev Can only be called by the admin
    function pause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    /// @notice Unpause the contract
    /// @dev Can only be called by the admin
    function unpause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    /// @notice Withdraw the contract balance
    /// @dev Can only be called by the admin
    /// @dev Requires the contract to be paused
    function withdraw() external whenPaused onlyRole(DEFAULT_ADMIN_ROLE) {
        payable(payoutAddress).transfer(address(this).balance);
    }

    /// @notice supportsInterface implementation
    /// @param interfaceId The interface ID
    /// @return Whether the interface is supported
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721EnumerableUpgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
