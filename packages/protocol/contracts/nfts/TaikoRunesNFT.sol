// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import "lib/openzeppelin-contracts-upgradeable/contracts/token/ERC721/ERC721Upgradeable.sol";
import "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import "../common/EssentialContract.sol";
import "../libs/LibMath.sol";

/// @title TaikoRunesNFT
/// @notice The Taiko Runes NFT is a component of the Taiko blockchain ecosystem, focusing on
/// community-driven NFT designs and unique on-chain properties. Key features include:
/// 1. Community-Driven Designs: NFT artworks are selected through community voting via Taiko DAO
/// by TKO holders, encouraging diverse artistic contributions.
/// 2. Incentives for Designers: Winning designers are rewarded with 1% of the NFTs minted in their
/// design series, fostering continuous community engagement and creativity.
/// 3. Determinstic On-Chain Properties: Each NFT possesses distinct, deterministically calculated
/// properties based on its ID, adding rarity and uniqueness.
/// 4. Ecosystem Integration: These NFTs are designed for use within the Taiko ecosystem, enhancing
/// user interaction and experience.
contract TaikoRunesNFT is EssentialContract, ERC721Upgradeable {
    using StringsUpgradeable for uint256;
    using LibMath for uint256;

    struct Property {
        uint64 id;
        bool isRare;
        bytes32 name;
        bytes32[] valueLabels;
    }

    uint256 public constant MAX_PROPERTIES = 64;
    uint256 public constant MAX_PROPERTY_VALUES = 32;
    uint256 public constant MIN_UPDATE_DELAY = 90 days;
    uint256 public constant FIRST_BATCH_SIZE = 10_000;
    uint256 public constant MAX_REWARDS = 100;

    uint64 public lastUpdated; // slot 1
    uint64 public version;
    uint64 public numTokens;

    string private baseURI; // slot 2
    Property[] public properties; // slot 3

    uint256[47] private __gap;

    event MetadataUpdated(
        uint256 indexed version, uint256 numTokens, string newBaseURI, Property newProperty
    );

    error INVALID_ADDRESS();
    error INVALID_URI();
    error INVALID_PROPERTY();
    error PROPERTY_NOT_FOUND();
    error TOO_EARLY();

    function init() external initializer {
        _Essential_init();
        __ERC721_init("Taiko Runes NFT", "TRUNE");
        lastUpdated = uint64(block.timestamp);
    }

    function updateMetadata(
        address mintTo,
        string memory newBaseURI,
        Property memory newProperty
    )
        external
        nonReentrant
        whenNotPaused
        onlyOwner
    {
        if (mintTo == address(0)) revert INVALID_ADDRESS();
        if (bytes(newBaseURI).length != 46) revert INVALID_URI();
        if (keccak256(bytes(newBaseURI)) == keccak256(bytes(baseURI))) revert INVALID_URI();

        if (newProperty.id == 0) return;
        if (newProperty.id != properties.length) revert INVALID_PROPERTY();
        if (newProperty.valueLabels.length == 0) revert INVALID_PROPERTY();
        if (newProperty.valueLabels.length > MAX_PROPERTY_VALUES) revert INVALID_PROPERTY();

        if (block.timestamp <= lastUpdated + MIN_UPDATE_DELAY) revert TOO_EARLY();

        lastUpdated = uint64(block.timestamp);
        version += 1;
        baseURI = newBaseURI;
        properties.push(newProperty);

        uint256 mints = numTokens == 0 ? FIRST_BATCH_SIZE : MAX_REWARDS.max(numTokens / 100);
        for (uint256 i; i < mints; ++i) {
            _mint(mintTo);
        }

        emit MetadataUpdated(version, numTokens, newBaseURI, newProperty);
    }

    function mint(address to) external nonReentrant whenNotPaused onlyOwner {
        _mint(to);
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

    function designerURI() public view returns (string memory) {
        return _buildURI(_baseURI(), "designer");
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        return _buildURI(_baseURI(), tokenId.toString());
    }

    function _mint(address to) internal {
        super._mint(to, ++numTokens);
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

    function _buildURI(
        string memory uri,
        string memory file
    )
        internal
        pure
        returns (string memory)
    {
        return string.concat("ipfs://", uri, "/", file);
    }

    function _mint(address, uint256) internal pure override {
        assert(false); // disabled
    }
}
