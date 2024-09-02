// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { Ownable2StepUpgradeable } from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";

contract RegisterProfilePicture is Initializable, UUPSUpgradeable, Ownable2StepUpgradeable {

    error InvalidNFTContract(address nftContract);
    error NotTokenOwner(address nftContract, uint256 tokenId, address caller);

    // Mapping from user address to the selected NFT (Collection address and token ID)
    struct ProfilePicture {
        address nftContract;
        uint256 tokenId;
    }

    mapping(address => ProfilePicture) public profilePictures;

    event ProfilePictureSet(address indexed user, address indexed nftContract, uint256 indexed tokenId);

    function initialize() public initializer {}

    // Function to set the PFP by providing the NFT contract address and token ID
    function setPFP(address nftContract, uint256 tokenId) external {
        if (ERC721Upgradeable(nftContract).supportsInterface(type(IERC721).interfaceId)) {
            // Check if the provided contract address is a valid ERC721 contract
            if (ERC721Upgradeable(nftContract).ownerOf(tokenId) != msg.sender) {
                revert NotTokenOwner(nftContract, tokenId, msg.sender);
            }
        } else if (ERC1155Upgradeable(nftContract).supportsInterface(type(IERC1155).interfaceId)) {
            // Check if the provided contract address is a valid ERC1155 contract
            if (ERC1155Upgradeable(nftContract).balanceOf(msg.sender, tokenId) == 0) {
                revert NotTokenOwner(nftContract, tokenId, msg.sender);
            }
        } else {
            // If the contract does not support ERC721 or ERC1155 interfaces
            revert InvalidNFTContract(nftContract);
        }

        // Set the PFP
        profilePictures[msg.sender] = ProfilePicture(nftContract, tokenId);

        emit ProfilePictureSet(msg.sender, nftContract, tokenId);
    }

    // Function to get the image URI of the NFT set as the user's PFP
    function getProfilePicture(address user) external view returns (string memory) {
        ProfilePicture memory profilePicture = profilePictures[user];

        if (ERC165Upgradeable(profilePicture.nftContract).supportsInterface(type(IERC721).interfaceId)) {
            // ERC721 case: Check ownership before returning the URI
            if (ERC721Upgradeable(profilePicture.nftContract).ownerOf(profilePicture.tokenId) != user) {
                revert NotTokenOwner(profilePicture.nftContract, profilePicture.tokenId, user);
            }
            return ERC721Upgradeable(profilePicture.nftContract).tokenURI(profilePicture.tokenId);
        } else if (ERC165Upgradeable(profilePicture.nftContract).supportsInterface(type(IERC1155).interfaceId)) {
            // ERC1155 case: Check ownership before returning the URI
            if (ERC1155Upgradeable(profilePicture.nftContract).balanceOf(user, profilePicture.tokenId) == 0) {
                revert NotTokenOwner(profilePicture.nftContract, profilePicture.tokenId, user);
            }
            return ERC1155Upgradeable(profilePicture.nftContract).uri(profilePicture.tokenId);
        } else {
            // If the contract does not support ERC721 or ERC1155 interfaces
            revert InvalidNFTContract(profilePicture.nftContract);
        }
    }

    /// @notice Internal method to authorize an upgrade
    function _authorizeUpgrade(address) internal virtual override onlyOwner { }
}
