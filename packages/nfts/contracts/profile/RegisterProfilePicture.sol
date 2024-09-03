// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from
    "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { Ownable2StepUpgradeable } from
    "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";

/// @title A store for trailblazer profile pictures
/// @author Bennett Yogn
/// @dev All function calls are currently implemented without side effects
contract RegisterProfilePicture is Initializable, UUPSUpgradeable, Ownable2StepUpgradeable {
    error InvalidNFTContract(address nftContract);
    error NotTokenOwner(address nftContract, uint256 tokenId, address caller);

    /// @notice struct of nft contract address and token id
    struct ProfilePicture {
        address nftContract;
        uint256 tokenId;
    }

    /// @notice mapping of user id to profile picture
    mapping(address user => ProfilePicture pfp) public profilePicture;

    event ProfilePictureSet(
        address indexed user, address indexed nftContract, uint256 indexed tokenId
    );

    /// @notice Contract initializer
    function initialize() public initializer {
        _transferOwnership(_msgSender());
    }

    /// @notice Set the profile picture
    /// @param nftContract The address of the nft to set as the profile picture
    /// @param tokenId The tokenId of the nft to set as the profile picture
    function setPFP(address nftContract, uint256 tokenId) external {
        if (IERC721(nftContract).supportsInterface(type(IERC721).interfaceId)) {
            // Check if the provided contract address is a valid ERC721 contract
            if (IERC721(nftContract).ownerOf(tokenId) != _msgSender()) {
                revert NotTokenOwner(nftContract, tokenId, _msgSender());
            }
        } else if (IERC1155(nftContract).supportsInterface(type(IERC1155).interfaceId)) {
            // Check if the provided contract address is a valid ERC1155 contract
            if (IERC1155(nftContract).balanceOf(_msgSender(), tokenId) == 0) {
                revert NotTokenOwner(nftContract, tokenId, _msgSender());
            }
        } else {
            // If the contract does not support ERC721 or ERC1155 interfaces
            revert InvalidNFTContract(nftContract);
        }

        // Set the PFP
        profilePicture[_msgSender()] = ProfilePicture(nftContract, tokenId);

        emit ProfilePictureSet(_msgSender(), nftContract, tokenId);
    }

    /// @notice Get the profile picture of a user
    /// @param user The address of user
    function getProfilePicture(address user) external view returns (string memory) {
        ProfilePicture memory profilePicture = profilePicture[user];

        if (IERC721(profilePicture.nftContract).supportsInterface(type(IERC721).interfaceId)) {
            // ERC721 case: Check ownership before returning the URI
            if (IERC721(profilePicture.nftContract).ownerOf(profilePicture.tokenId) != user) {
                revert NotTokenOwner(profilePicture.nftContract, profilePicture.tokenId, user);
            }
            return ERC721(profilePicture.nftContract).tokenURI(profilePicture.tokenId);
        } else if (
            IERC1155(profilePicture.nftContract).supportsInterface(type(IERC1155).interfaceId)
        ) {
            // ERC1155 case: Check ownership before returning the URI
            if (IERC1155(profilePicture.nftContract).balanceOf(user, profilePicture.tokenId) == 0) {
                revert NotTokenOwner(profilePicture.nftContract, profilePicture.tokenId, user);
            }
            return ERC1155(profilePicture.nftContract).uri(profilePicture.tokenId);
        } else {
            // If the contract does not support ERC721 or ERC1155 interfaces
            revert InvalidNFTContract(profilePicture.nftContract);
        }
    }

    /// @notice Internal method to authorize an upgrade
    function _authorizeUpgrade(address) internal virtual override onlyOwner { }
}
