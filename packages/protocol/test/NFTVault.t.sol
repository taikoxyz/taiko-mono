// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { console2 } from "forge-std/console2.sol";
import { Test } from "forge-std/Test.sol";
import { AddressManager } from "../contracts/common/AddressManager.sol";
import { IBridge, Bridge } from "../contracts/bridge/Bridge.sol";
import { BridgeErrors } from "../contracts/bridge/BridgeErrors.sol";
import { NFTVault } from "../contracts/bridge/NFTVault.sol";
import { EtherVault } from "../contracts/bridge/EtherVault.sol";
import { LibBridgeStatus } from "../contracts/bridge/libs/LibBridgeStatus.sol";
import { SignalService } from "../contracts/signal/SignalService.sol";
import { ICrossChainSync } from "../contracts/common/ICrossChainSync.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

// Template canonical erc721 token
contract TestTokenERC721 is ERC721 {
    string _baseTokenURI;
    uint256 minted;

    constructor(string memory baseURI) ERC721("TT", "TT"){
        setBaseURI(baseURI);
    }
    
    function setBaseURI(string memory baseURI) internal {
        _baseTokenURI = baseURI;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }
    
    function mint(uint256 amount) public {
        for (uint256 i; i < amount; i++) {
            _safeMint(msg.sender, minted + i);
        }
        minted+= amount;
    }
}

// Template canonical erc1155 token
contract TestTokenERC1155 is ERC1155 {

    constructor(string memory baseURI) ERC1155(baseURI){}
    
    function mint(uint256 tokenId, uint256 amount) public {
        _mint(msg.sender, tokenId, amount, '');
    }
}

// NonNftContract
contract NonNftContract {
    uint256 dummyData;

    constructor(uint256 _dummyData) {
        dummyData = _dummyData;
    }
}

contract BadReceiver {
    receive() external payable {
        revert("can not send to this contract");
    }

    fallback() external payable {
        revert("can not send to this contract");
    }

    function transfer() public pure {
        revert("this fails");
    }
}

contract PrankCrossChainSync is ICrossChainSync {
    bytes32 private _blockHash;
    bytes32 private _signalRoot;

    function setCrossChainBlockHeader(bytes32 blockHash) external {
        _blockHash = blockHash;
    }

    function setCrossChainSignalRoot(bytes32 signalRoot) external {
        _signalRoot = signalRoot;
    }

    function getCrossChainBlockHash(uint256) external view returns (bytes32) {
        return _blockHash;
    }

    function getCrossChainSignalRoot(uint256) external view returns (bytes32) {
        return _signalRoot;
    }
}

contract NFTVaultTest is Test {
    AddressManager addressManager;
    BadReceiver badReceiver;
    Bridge bridge;
    Bridge destChainBridge;
    NFTVault nftVault;
    NFTVault destChainNftVault;
    TestTokenERC721 canonicalToken721;
    TestTokenERC1155 canonicalToken1155;
    EtherVault etherVault;
    SignalService signalService;
    PrankCrossChainSync crossChainSync;
    uint256 destChainId = 19_389;

    address public constant Alice = 0x10020FCb72e27650651B05eD2CEcA493bC807Ba4;

    address public constant Bob = 0x50081b12838240B1bA02b3177153Bca678a86078;

    function setUp() public {
        vm.startPrank(Alice);
        vm.deal(Alice, 100 ether);
        addressManager = new AddressManager();
        addressManager.init();

        bridge = new Bridge();
        bridge.init(address(addressManager));

        destChainBridge = new Bridge();
        destChainBridge.init(address(addressManager));

        signalService = new SignalService();
        signalService.init(address(addressManager));

        etherVault = new EtherVault();
        etherVault.init(address(addressManager));

        nftVault = new NFTVault();
        nftVault.init(address(addressManager));

        destChainNftVault = new NFTVault();
        destChainNftVault.init(address(addressManager));

        crossChainSync = new PrankCrossChainSync();

        addressManager.setAddress(
            block.chainid, "signal_service", address(signalService)
        );

        addressManager.setAddress(
            block.chainid, "bridge", address(bridge)
        );

        addressManager.setAddress(
            destChainId, "bridge", address(destChainBridge)
        );

        addressManager.setAddress(
            block.chainid, "nft_vault", address(nftVault)
        );

        addressManager.setAddress(
            destChainId, "nft_vault", address(destChainNftVault)
        );

        canonicalToken721 = new TestTokenERC721("http://example.host.com/");
        canonicalToken721.mint(10);

        canonicalToken1155 = new TestTokenERC1155("http://example.host.com/");
        canonicalToken1155.mint(1, 10);

        vm.stopPrank();
    }

    function test_sendNFT_ERC721()
        public
    {
        vm.prank(Alice,Alice);
        canonicalToken721.approve(address(nftVault),1);

        assertEq(canonicalToken721.ownerOf(1), Alice);

        NFTVault.SendNFTOpts memory sendOpts = NFTVault.SendNFTOpts(
            destChainId,
            Alice,
            address(canonicalToken721),
            "http://example.host.com/",
            1,
            1,// With ERC721 still need to specify 1
            140000,
            140000,
            Alice,
            ""
        );
        vm.prank(Alice,Alice);
        nftVault.sendNFT{ value: 140000 }(sendOpts);

        assertEq(ERC721(canonicalToken721).ownerOf(1), address(nftVault));
    }

    function test_sendNFT_ERC1155()
        public
    {
        vm.prank(Alice, Alice);
        canonicalToken1155.setApprovalForAll(address(nftVault),true);

        assertEq(canonicalToken1155.balanceOf(Alice, 1), 10);
        assertEq(canonicalToken1155.balanceOf(address(nftVault), 1), 0);

        NFTVault.SendNFTOpts memory sendOpts = NFTVault.SendNFTOpts(
            destChainId,
            Alice,
            address(canonicalToken1155),
            "http://example.host.com/",
            1,
            2,
            140000,
            140000,
            Alice,
            ""
        );
        vm.prank(Alice,Alice);
        nftVault.sendNFT{ value: 140000 }(sendOpts);

        assertEq(canonicalToken1155.balanceOf(Alice, 1), 8);
        assertEq(canonicalToken1155.balanceOf(address(nftVault), 1), 2);
    }

    function test_sendNFT_with_invalid_to_address()
        public
    {
        vm.prank(Alice, Alice);
        canonicalToken1155.setApprovalForAll(address(nftVault),true);

        assertEq(canonicalToken1155.balanceOf(Alice, 1), 10);
        assertEq(canonicalToken1155.balanceOf(address(nftVault), 1), 0);

        NFTVault.SendNFTOpts memory sendOpts = NFTVault.SendNFTOpts(
            destChainId,
            address(0),
            address(canonicalToken1155),
            "http://example.host.com/",
            1,
            2,
            140000,
            140000,
            Alice,
            ""
        );
        vm.prank(Alice,Alice);
        vm.expectRevert(BridgeErrors.NFTVAULT_INVALID_TO.selector);
        nftVault.sendNFT{ value: 140000 }(sendOpts);
    }

    function test_sendNFT_with_invalid_token_address()
        public
    {
        vm.prank(Alice, Alice);
        canonicalToken1155.setApprovalForAll(address(nftVault),true);

        assertEq(canonicalToken1155.balanceOf(Alice, 1), 10);
        assertEq(canonicalToken1155.balanceOf(address(nftVault), 1), 0);

        NFTVault.SendNFTOpts memory sendOpts = NFTVault.SendNFTOpts(
            destChainId,
            Alice,
            address(0),
            "http://example.host.com/",
            1,
            2,
            140000,
            140000,
            Alice,
            ""
        );
        vm.prank(Alice,Alice);
        vm.expectRevert(BridgeErrors.NFTVAULT_INVALID_TOKEN.selector);
        nftVault.sendNFT{ value: 140000 }(sendOpts);
    }

    function test_sendNFT_with_0_tokens()
        public
    {
        vm.prank(Alice, Alice);
        canonicalToken1155.setApprovalForAll(address(nftVault),true);

        assertEq(canonicalToken1155.balanceOf(Alice, 1), 10);
        assertEq(canonicalToken1155.balanceOf(address(nftVault), 1), 0);

        NFTVault.SendNFTOpts memory sendOpts = NFTVault.SendNFTOpts(
            destChainId,
            Alice,
            address(canonicalToken1155),
            "http://example.host.com/",
            1,
            0,
            140000,
            140000,
            Alice,
            ""
        );
        vm.prank(Alice,Alice);
        vm.expectRevert(BridgeErrors.NFTVAULT_INVALID_AMOUNT.selector);
        nftVault.sendNFT{ value: 140000 }(sendOpts);
    }


    function test_sendNFT_with_invalid_type()
        public
    {
        NonNftContract nonNftContract = new NonNftContract(1);

        vm.prank(Alice, Alice);
        canonicalToken1155.setApprovalForAll(address(nftVault),true);

        assertEq(canonicalToken1155.balanceOf(Alice, 1), 10);
        assertEq(canonicalToken1155.balanceOf(address(nftVault), 1), 0);

        NFTVault.SendNFTOpts memory sendOpts = NFTVault.SendNFTOpts(
            destChainId,
            Alice,
            address(nonNftContract),
            "http://example.host.com/",
            1,
            1,
            140000,
            140000,
            Alice,
            ""
        );
        vm.prank(Alice,Alice);
        vm.expectRevert(BridgeErrors.NFT_VAULT_INVALID_CONTRACT.selector);
        nftVault.sendNFT{ value: 140000 }(sendOpts);
    }
}
