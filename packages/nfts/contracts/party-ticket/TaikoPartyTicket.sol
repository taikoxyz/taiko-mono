// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

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

contract TaikoPartyTicket is
    ERC721EnumerableUpgradeable,
    PausableUpgradeable,
    AccessControlUpgradeable
{
    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");

    uint256 public mintFee;
    bool public mintActive;
    uint256 private _nextTokenId;
    mapping(uint256 => bool) public winners;
    string public baseURI;
    string public winnerBaseURI;

    address public payoutAddress;

    function initialize(
        address _payoutAddress,
        uint256 _mintFee,
        string memory _baseURI,
        string memory _winnerBaseURI
    )
        external
        initializer
    {
        __ERC721_init("TaikoPartyTicket", "TPT");

        mintFee = _mintFee;
        baseURI = _baseURI;
        winnerBaseURI = _winnerBaseURI;
        payoutAddress = _payoutAddress;

        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(OWNER_ROLE, _payoutAddress);
    }

    function mint() external payable whenNotPaused {
        require(msg.value >= mintFee, "Insufficient mint fee");

        uint256 tokenId = _nextTokenId++;
        _safeMint(msg.sender, tokenId);
    }

    function mint(address to) public whenNotPaused onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
    }

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

    function revokeAndReplaceWinner(
        uint256 revokeId,
        uint256 newWinnerId
    )
        external
        whenPaused
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(winners[revokeId], "Revoke ID not a winner");
        winners[revokeId] = false;
        winners[newWinnerId] = true;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        if (winners[tokenId]) {
            return string(abi.encodePacked(winnerBaseURI, Strings.toString(tokenId)));
        }
        return string(abi.encodePacked(baseURI, Strings.toString(tokenId)));
    }

    function pause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    function withdraw() external whenPaused onlyRole(DEFAULT_ADMIN_ROLE) {
        payable(payoutAddress).transfer(address(this).balance);
    }

    function isWinner(uint256 tokenId) public view returns (bool) {
        return winners[tokenId];
    }

    function isWinner(address minter) public view returns (bool) {
        for (uint256 i = 0; i < balanceOf(minter); i++) {
            if (winners[tokenOfOwnerByIndex(minter, i)]) {
                return true;
            }
        }
        return false;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721EnumerableUpgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
