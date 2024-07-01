// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import { ERC721EnumerableUpgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";

import { MerkleWhitelist } from "./MerkleWhitelist.sol";
import { IMinimalBlacklist } from "@taiko/blacklist/IMinimalBlacklist.sol";

/// @title TaikoonToken
/// @dev The Taikoons ERC-721 token
/// @custom:security-contact security@taiko.xyz
contract TaikoonToken is ERC721EnumerableUpgradeable, MerkleWhitelist {
    /// @notice The current supply
    uint256 private _totalSupply;
    /// @notice Base URI required to interact with IPFS
    string private _baseURIExtended;
    /// @notice Gap for upgrade safety
    uint256[47] private __gap;

    error MAX_MINTS_EXCEEDED();
    error MAX_SUPPLY_REACHED();
    error MINTER_NOT_WHITELISTED();
    error TOKEN_NOT_MINTED();

    /// @notice Contract initializer
    /// @param _rootURI Base URI for the token metadata
    /// @param _merkleRoot Merkle tree root for the whitelist
    function initialize(
        address _owner,
        string memory _rootURI,
        bytes32 _merkleRoot,
        IMinimalBlacklist _blacklistAddress
    )
        external
        initializer
    {
        __ERC721_init("Taikoon", "TKOON");
        __MerkleWhitelist_init(_owner, _merkleRoot, _blacklistAddress);
        _baseURIExtended = _rootURI;
    }

    /// @notice Update the whitelist's merkle root
    /// @param _root New merkle root
    function updateRoot(bytes32 _root) external onlyOwner {
        _updateRoot(_root);
    }

    /// @notice Mint a token, handling the free vs paid internally
    /// @param _proof Merkle proof validating the minter
    /// @param _maxMints The amount of tokens to mint
    /// @return tokenIds The minted token ids
    function mint(
        bytes32[] calldata _proof,
        uint256 _maxMints
    )
        external
        returns (uint256[] memory)
    {
        if (!canMint(_msgSender(), _maxMints)) revert MINTER_NOT_WHITELISTED();

        _consumeMint(_proof, _maxMints);
        return _batchMint(_msgSender(), _maxMints);
    }

    /// @notice Mint method for the owner
    /// @param _to The address to mint to
    /// @param _amount The amount of tokens to mint
    /// @return tokenIds The minted token ids
    function mint(address _to, uint256 _amount) external onlyOwner returns (uint256[] memory) {
        return _batchMint(_to, _amount);
    }

    /// @notice Get the tokenURI of a particular tokenId
    /// @param _tokenId The token ID
    /// @return The token URI
    function tokenURI(uint256 _tokenId) public view override returns (string memory) {
        if (_tokenId > _totalSupply) revert TOKEN_NOT_MINTED();
        return string.concat(_baseURI(), "/", Strings.toString(_tokenId), ".json");
    }

    /// @notice Get the current total supply
    /// @return The total supply
    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    /// @notice Get the max supply of Taikoons
    /// @return The max supply
    function maxSupply() public pure returns (uint256) {
        return 888;
    }
    /// @notice Calculate the amount of free and paid mints
    /// @return The base URI for the token metadata

    function _baseURI() internal view override returns (string memory) {
        return _baseURIExtended;
    }

    /// @notice Internal method to batch mint tokens
    /// @param _to The address to mint to
    /// @param _amount The amount of tokens to mint
    /// @return tokenIds The minted token ids
    function _batchMint(address _to, uint256 _amount) private returns (uint256[] memory tokenIds) {
        if (_totalSupply + _amount > maxSupply()) revert MAX_SUPPLY_REACHED();
        tokenIds = new uint256[](_amount);

        for (uint256 i; i < _amount; ++i) {
            tokenIds[i] = ++_totalSupply;
            _mint(_to, tokenIds[i]);
        }
    }

    /// @dev V2 code additions

    /// @notice Update the base URI
    /// @param _rootURI The new base URI
    /// @dev Only the owner can update the base URI
    function updateBaseURI(string memory _rootURI) public onlyOwner {
        _baseURIExtended = _rootURI;
    }

    /// @notice Get the base URI
    /// @return The base URI
    function baseURI() public view returns (string memory) {
        return _baseURIExtended;
    }
}
