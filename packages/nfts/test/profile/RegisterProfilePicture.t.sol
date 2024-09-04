// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Test, console } from "forge-std/src/Test.sol";
import { RegisterProfilePicture } from "../../contracts/profile/RegisterProfilePicture.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { ERC721Mock, ERC1155Mock, MockInvalidNFT } from "../util/MockTokens.sol";

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

    event ProfilePictureSet(
        address indexed user, address indexed nftContract, uint256 indexed tokenId
    );

    function setUp() public {
        owner = vm.addr(0x1);
        user = vm.addr(0x2);
        otherUser = vm.addr(0x3);

        vm.startBroadcast(owner);

        RegisterProfilePicture impl = new RegisterProfilePicture();
        ERC1967Proxy proxy =
            new ERC1967Proxy(address(impl), abi.encodeCall(RegisterProfilePicture.initialize, ()));
        registerProfilePicture = RegisterProfilePicture(address(proxy));

        erc721Mock = new ERC721Mock();
        erc721Mock.initialize("MockERC721", "M721");
        erc721Mock.mint(user, ERC721_TOKEN_ID);

        erc1155Mock = new ERC1155Mock();
        erc1155Mock.initialize("https://token-cdn-domain/{id}.json");
        erc1155Mock.mint(user, ERC1155_TOKEN_ID, 1, "");

        invalidNFT = new MockInvalidNFT();

        vm.stopBroadcast();
    }

    function test_SetPFPWithERC721() public {
        vm.startPrank(user);

        registerProfilePicture.setPFP(address(erc721Mock), ERC721_TOKEN_ID);

        (address nftContract, uint256 tokenId) = registerProfilePicture.profilePicture(user);
        assertEq(nftContract, address(erc721Mock));
        assertEq(tokenId, ERC721_TOKEN_ID);

        vm.stopPrank();
    }

    function test_SetPFPWithERC1155() public {
        vm.startPrank(user);

        registerProfilePicture.setPFP(address(erc1155Mock), ERC1155_TOKEN_ID);

        (address nftContract, uint256 tokenId) = registerProfilePicture.profilePicture(user);
        assertEq(nftContract, address(erc1155Mock));
        assertEq(tokenId, ERC1155_TOKEN_ID);

        vm.stopPrank();
    }

    function test_GetProfilePictureERC721() public {
        vm.startPrank(user);
        registerProfilePicture.setPFP(address(erc721Mock), ERC721_TOKEN_ID);
        string memory uri = registerProfilePicture.getProfilePicture(user);
        assertEq(uri, erc721Mock.tokenURI(ERC721_TOKEN_ID));
        vm.stopPrank();
    }

    function test_GetProfilePictureERC1155() public {
        vm.startPrank(user);
        registerProfilePicture.setPFP(address(erc1155Mock), ERC1155_TOKEN_ID);
        string memory uri = registerProfilePicture.getProfilePicture(user);
        assertEq(uri, erc1155Mock.uri(ERC1155_TOKEN_ID));
        vm.stopPrank();
    }

    function test_CannotSetPFPWithInvalidNFTContract() public {
        vm.startPrank(user);

        // Expect any kind of revert when trying to set PFP with invalid NFT contract
        vm.expectRevert();
        registerProfilePicture.setPFP(address(invalidNFT), 1);

        vm.stopPrank();
    }

    function test_CannotSetPFPWithNonOwnedERC721() public {
        vm.startPrank(otherUser);

        vm.expectRevert(
            abi.encodeWithSignature(
                "NotTokenOwner(address,uint256,address)",
                address(erc721Mock),
                ERC721_TOKEN_ID,
                otherUser
            )
        );
        registerProfilePicture.setPFP(address(erc721Mock), ERC721_TOKEN_ID);

        vm.stopPrank();
    }

    function test_CannotSetPFPWithNonOwnedERC1155() public {
        vm.startPrank(otherUser);

        vm.expectRevert(
            abi.encodeWithSignature(
                "NotTokenOwner(address,uint256,address)",
                address(erc1155Mock),
                ERC1155_TOKEN_ID,
                otherUser
            )
        );
        registerProfilePicture.setPFP(address(erc1155Mock), ERC1155_TOKEN_ID);

        vm.stopPrank();
    }

    function test_CannotGetProfilePictureAfterTransferERC721() public {
        vm.startPrank(user);

        registerProfilePicture.setPFP(address(erc721Mock), ERC721_TOKEN_ID);
        erc721Mock.transferFrom(user, otherUser, ERC721_TOKEN_ID);

        vm.expectRevert(
            abi.encodeWithSignature(
                "NotTokenOwner(address,uint256,address)", address(erc721Mock), ERC721_TOKEN_ID, user
            )
        );
        registerProfilePicture.getProfilePicture(user);

        vm.stopPrank();
    }

    function test_CannotGetProfilePictureAfterTransferERC1155() public {
        vm.startPrank(user);

        registerProfilePicture.setPFP(address(erc1155Mock), ERC1155_TOKEN_ID);
        erc1155Mock.safeTransferFrom(user, otherUser, ERC1155_TOKEN_ID, 1, "");

        vm.expectRevert(
            abi.encodeWithSignature(
                "NotTokenOwner(address,uint256,address)",
                address(erc1155Mock),
                ERC1155_TOKEN_ID,
                user
            )
        );
        registerProfilePicture.getProfilePicture(user);

        vm.stopPrank();
    }

    function test_ChangeProfilePicture() public {
        vm.startPrank(user);

        registerProfilePicture.setPFP(address(erc721Mock), ERC721_TOKEN_ID);

        registerProfilePicture.setPFP(address(erc1155Mock), ERC1155_TOKEN_ID);

        (address nftContract, uint256 tokenId) = registerProfilePicture.profilePicture(user);
        assertEq(nftContract, address(erc1155Mock));
        assertEq(tokenId, ERC1155_TOKEN_ID);

        vm.stopPrank();
    }

    function test_upgrade() public {
        // Step 1: Deploy the initial implementation (v1) using the proxy
        vm.startPrank(owner);

        // Deploy v1 implementation and proxy pointing to v1
        address implV1 = address(new RegisterProfilePicture());
        ERC1967Proxy proxy = new ERC1967Proxy(implV1, abi.encodeWithSignature("initialize()"));
        RegisterProfilePicture tokenV1 = RegisterProfilePicture(address(proxy));

        vm.stopPrank();

        // Step 2: Interact with v1
        vm.startPrank(user);
        tokenV1.setPFP(address(erc721Mock), ERC721_TOKEN_ID);

        // Verify that the PFP was set correctly
        string memory uri = tokenV1.getProfilePicture(user);
        assertEq(uri, erc721Mock.tokenURI(ERC721_TOKEN_ID));
        vm.stopPrank();

        // Step 3: Upgrade to v2
        vm.startPrank(owner);
        address implV2 = address(new RegisterProfilePicture());
        tokenV1.upgradeToAndCall(implV2, "");

        // Verify that the previous state is still relevant after the upgrade
        RegisterProfilePicture tokenV2 = RegisterProfilePicture(address(proxy));
        uri = tokenV2.getProfilePicture(user);
        assertEq(uri, erc721Mock.tokenURI(ERC721_TOKEN_ID));
        vm.stopPrank();

        // Step 4: Test setting and retrieving PFP with ERC1155 after the upgrade
        vm.startPrank(user);
        tokenV2.setPFP(address(erc1155Mock), ERC1155_TOKEN_ID);

        uri = tokenV2.getProfilePicture(user);
        assertEq(uri, erc1155Mock.uri(ERC1155_TOKEN_ID));
        vm.stopPrank();
    }

    function test_upgrade_throw() public {
        // Step 1: Deploy the initial implementation (v1) using the proxy
        vm.startPrank(owner);

        // Deploy v1 implementation and proxy pointing to v1
        address implV1 = address(new RegisterProfilePicture());
        ERC1967Proxy proxy = new ERC1967Proxy(implV1, abi.encodeWithSignature("initialize()"));
        RegisterProfilePicture tokenV1 = RegisterProfilePicture(address(proxy));

        vm.stopPrank();

        // Step 2: Interact with v1
        vm.startPrank(user);
        tokenV1.setPFP(address(erc721Mock), ERC721_TOKEN_ID);

        // Verify that the PFP was set correctly
        string memory uri = tokenV1.getProfilePicture(user);
        assertEq(uri, erc721Mock.tokenURI(ERC721_TOKEN_ID));

        // Attempt to upgrade as a non-owner and expect a revert
        address implV2 = address(new RegisterProfilePicture());
        vm.expectRevert();
        tokenV1.upgradeToAndCall(implV2, "");
        vm.stopPrank();

        // Step 3: Upgrade to v2 by the owner
        vm.startPrank(owner);
        implV2 = address(new RegisterProfilePicture());
        tokenV1.upgradeToAndCall(implV2, "");

        // Verify that the previous state is still relevant after the upgrade
        RegisterProfilePicture tokenV2 = RegisterProfilePicture(address(proxy));
        uri = tokenV2.getProfilePicture(user);
        assertEq(uri, erc721Mock.tokenURI(ERC721_TOKEN_ID));
        vm.stopPrank();

        // Step 4: Test setting and retrieving PFP with ERC1155 after the upgrade
        vm.startPrank(user);
        tokenV2.setPFP(address(erc1155Mock), ERC1155_TOKEN_ID);

        uri = tokenV2.getProfilePicture(user);
        assertEq(uri, erc1155Mock.uri(ERC1155_TOKEN_ID));
        vm.stopPrank();
    }
}
