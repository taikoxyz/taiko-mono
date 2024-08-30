// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract RegisterProfilePicture {

    error InvalidERC721Contract(address nftContract);
    error NotTokenOwner(address nftContract, uint256 tokenId, address caller);

    // Mapping from user address to the selected NFT (Collection address and token ID)
    struct ProfilePicture {
        address nftContract;
        uint256 tokenId;
    }

    mapping(address user => ProfilePicture profilePicture) public profilePictures;

    event ProfilePictureSet(address indexed user, address indexed nftContract, uint256 indexed tokenId);

    // Function to set the PFP by providing the NFT contract address and token ID
    function setPFP(address nftContract, uint256 tokenId) external {
        // Check if the provided contract address is a valid ERC721 contract
        if (!IERC721(nftContract).supportsInterface(type(IERC721).interfaceId)) {
            revert InvalidERC721Contract(nftContract);
        }

        // Check if the caller owns the token they are trying to set as their PFP
        if (IERC721(nftContract).ownerOf(tokenId) != msg.sender) {
            revert NotTokenOwner(nftContract, tokenId, msg.sender);
        }

        // Set the PFP
        profilePictures[msg.sender] = ProfilePicture(nftContract, tokenId);

        emit ProfilePictureSet(msg.sender, nftContract, tokenId);
    }
}

