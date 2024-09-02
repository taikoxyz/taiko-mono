// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test } from "forge-std/src/Test.sol";
import { RegisterProfilePicture } from "../../contracts/profile/RegisterProfilePicture.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { ERC721Mock, ERC1155Mock, MockInvalidNFT } from "../util/MockToken.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

contract RegisterProfilePictureTest is Test {
    RegisterProfilePicture public registerProfilePicture;
    ERC721Mock public erc721Mock;
    ERC1155Mock public erc1155Mock;
    MockInvalidNFT public invalidNFT;

    address public owner;
    address public user;
    address public otherUser;

    uint256 public constant ERC721_TOKEN_ID = 1;
    uint256 public constant ERC1155_TOKEN_ID = 2;

    event ProfilePictureSet(address indexed user, address indexed nftContract, uint256 indexed tokenId);

    function setUp() public {
        owner = vm.addr(0x1);
        user = vm.addr(0x2);
        otherUser = vm.addr(0x3);

        vm.startBroadcast(owner);
        
        RegisterProfilePicture impl = new RegisterProfilePicture();
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(impl),
            abi.encodeCall(RegisterProfilePicture.initialize, ())
        );
        registerProfilePicture = RegisterProfilePicture(address(proxy));

        erc721Mock = new ERC721Mock("MockERC721", "M721");
        erc721Mock.mint(user, ERC721_TOKEN_ID);

        erc1155Mock = new ERC1155Mock("https://token-cdn-domain/{id}.json");
        erc1155Mock.mint(user, ERC1155_TOKEN_ID, 1, "");

        invalidNFT = new MockInvalidNFT();

        vm.stopBroadcast();
    }

    function testSetPFPWithERC721() public {
        vm.startPrank(user);

        vm.expectEmit(true, true, true, true);
        emit ProfilePictureSet(user, address(erc721Mock), ERC721_TOKEN_ID);
        registerProfilePicture.setPFP(address(erc721Mock), ERC721_TOKEN_ID);

        (address nftContract, uint256 tokenId) = registerProfilePicture.profilePictures(user);
        assertEq(nftContract, address(erc721Mock));
        assertEq(tokenId, ERC721_TOKEN_ID);

        vm.stopPrank();
    }

    function testSetPFPWithERC1155() public {
        vm.startPrank(user);

        vm.expectEmit(true, true, true, true);
        emit ProfilePictureSet(user, address(erc1155Mock), ERC1155_TOKEN_ID);
        registerProfilePicture.setPFP(address(erc1155Mock), ERC1155_TOKEN_ID);

        (address nftContract, uint256 tokenId) = registerProfilePicture.profilePictures(user);
        assertEq(nftContract, address(erc1155Mock));
        assertEq(tokenId, ERC1155_TOKEN_ID);

        vm.stopPrank();
    }

    function testGetProfilePicture() public {
        vm.startPrank(user);

        registerProfilePicture.setPFP(address(erc721Mock), ERC721_TOKEN_ID);
        assertEq(registerProfilePicture.getProfilePicture(user), erc721Mock.tokenURI(ERC721_TOKEN_ID));

        registerProfilePicture.setPFP(address(erc1155Mock), ERC1155_TOKEN_ID);
        assertEq(registerProfilePicture.getProfilePicture(user), erc1155Mock.uri(ERC1155_TOKEN_ID));

        vm.stopPrank();
    }

    function testCannotSetPFPWithInvalidNFTContract() public {
        vm.startPrank(user);

        vm.expectRevert(abi.encodeWithSignature("InvalidNFTContract(address)", address(invalidNFT)));
        registerProfilePicture.setPFP(address(invalidNFT), 1);

        vm.stopPrank();
    }

    function testCannotSetPFPWithNonOwnedToken() public {
        vm.startPrank(otherUser);

        vm.expectRevert(abi.encodeWithSignature("NotTokenOwner(address,uint256,address)", address(erc721Mock), ERC721_TOKEN_ID, otherUser));
        registerProfilePicture.setPFP(address(erc721Mock), ERC721_TOKEN_ID);

        vm.expectRevert(abi.encodeWithSignature("NotTokenOwner(address,uint256,address)", address(erc1155Mock), ERC1155_TOKEN_ID, otherUser));
        registerProfilePicture.setPFP(address(erc1155Mock), ERC1155_TOKEN_ID);

        vm.stopPrank();
    }

    function testCannotGetProfilePictureAfterTransfer() public {
        vm.startPrank(user);

        registerProfilePicture.setPFP(address(erc721Mock), ERC721_TOKEN_ID);
        erc721Mock.transferFrom(user, otherUser, ERC721_TOKEN_ID);
        vm.expectRevert(abi.encodeWithSignature("NotTokenOwner(address,uint256,address)", address(erc721Mock), ERC721_TOKEN_ID, user));
        registerProfilePicture.getProfilePicture(user);

        registerProfilePicture.setPFP(address(erc1155Mock), ERC1155_TOKEN_ID);
        erc1155Mock.safeTransferFrom(user, otherUser, ERC1155_TOKEN_ID, 1, "");
        vm.expectRevert(abi.encodeWithSignature("NotTokenOwner(address,uint256,address)", address(erc1155Mock), ERC1155_TOKEN_ID, user));
        registerProfilePicture.getProfilePicture(user);

        vm.stopPrank();
    }
}