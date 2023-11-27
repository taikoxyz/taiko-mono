// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import "lib/openzeppelin-contracts-upgradeable/contracts/token/ERC721/ERC721Upgradeable.sol";
import "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import "../common/EssentialContract.sol";

/// @title TaikoRunesNFT
contract TaikoRunesNFT is EssentialContract, ERC721Upgradeable {
    using StringsUpgradeable for uint256;

    struct Property {
        uint64 id;
        bool isRare;
        bytes32 name;
        bytes32[] valueLabels;
    }

    uint256 public constant MAX_PROPERTIES = 64;
    uint256 public constant MAX_PROPERTY_VALUES = 32;
    uint256 public constant MIN_UPDATE_DELAY = 90 days;

    uint64 public lastUpdated; // slot 1
    uint64 public version;
    string private baseURI; // slot 2
    string private previousBaseURL; // slot 3
    Property[] public properties; // slot 4

    uint256[46] private __gap;

    event MetadataUpdated(uint256 version, string newBaseURI, Property newProperty);

    error INVALID_URI();
    error INVALID_PROPERTY();
    error PROPERTY_NOT_FOUND();
    error TOO_EARLY();

    function init() external initializer {
        _Essential_init();
        __ERC721_init("Taiko Runes NFT", "TRUNE");
        lastUpdated = uint64(block.timestamp);
        previousBaseURL = "";
    }

    function updateMetadata(
        string memory newBaseURI,
        Property memory newProperty,
        address rewardTo
    )
        external
        onlyOwner
    {
        if (bytes(newBaseURI).length == 0) revert INVALID_URI();
        if (keccak256(bytes(newBaseURI)) == keccak256(bytes(baseURI))) revert INVALID_URI();

        if (newProperty.id == 0) return;
        if (newProperty.id != properties.length) revert INVALID_PROPERTY();
        if (newProperty.valueLabels.length == 0) revert INVALID_PROPERTY();
        if (newProperty.valueLabels.length > MAX_PROPERTY_VALUES) revert INVALID_PROPERTY();

        if (block.timestamp <= lastUpdated + MIN_UPDATE_DELAY) revert TOO_EARLY();

        lastUpdated = uint64(block.timestamp);
        version++;
        previousBaseURL = baseURI;
        baseURI = newBaseURI;
        properties.push(newProperty);

        emit MetadataUpdated(version, newBaseURI, newProperty);

        // _mint(rewardTo, uint256 tokenId)
    }

    function getProperty(uint256 pid) public view returns (Property memory) {
        return _getProperty(pid);
    }

    function getPropertyValue(uint256 nftId, uint256 pid) public view returns (uint256) {
        Property storage property = _getProperty(pid);
        uint256 n = property.valueLabels.length;
        uint256 r = _randSeed(nftId, pid);

        if (!property.isRare) return r % n;

        // Each value has an odd of 4x of the value precending it, so if a property has 3 values,
        // the odds are 1, 4, 16
        unchecked {
            uint256 totalWeight = ((1 << (n << 1)) - 1) / 3;
            r = r % totalWeight;

            uint256 c;
            uint256 w = 1;

            // Determine which segment that `r` falls into
            for (uint256 i; i < n; ++i) {
                c += w;
                if (r < c) return i;
                w <<= 2;
            }

            return n - 1; // fallback but not reachable
        }
    }

    function previousTokenURI(uint256 tokenId) public view returns (string memory) {
        _requireMinted(tokenId);
        return bytes(previousBaseURL).length > 0
            ? string(abi.encodePacked(previousBaseURL, tokenId.toString()))
            : "";
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    function _getProperty(uint256 pid) internal view returns (Property storage property) {
        property = properties[pid];
        if (property.id != pid) revert PROPERTY_NOT_FOUND();
    }

    function _randSeed(uint256 nftId, uint256 pid) internal pure virtual returns (uint256) {
        return uint256(keccak256(abi.encode("TAIKO RUNES NFT", nftId, pid)));
    }
}
