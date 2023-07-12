// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { console2 } from "forge-std/console2.sol";
import { Test } from "forge-std/Test.sol";
import { AddressResolver } from "../contracts/common/AddressResolver.sol";
import { AddressManager } from "../contracts/common/AddressManager.sol";
import { IBridge, Bridge } from "../contracts/bridge/Bridge.sol";
import { LibBridgeData } from "../contracts/bridge/libs/LibBridgeData.sol";
import { BridgeErrors } from "../contracts/bridge/BridgeErrors.sol";
import { NFTVaultParent } from "../contracts/bridge/NFTVaultParent.sol";
import { ERC1155Vault } from "../contracts/bridge/erc1155/ERC1155Vault.sol";
import { LibERC1155 } from "../contracts/bridge/erc1155/libs/LibERC1155.sol";
import { EtherVault } from "../contracts/bridge/EtherVault.sol";
import { LibBridgeStatus } from "../contracts/bridge/libs/LibBridgeStatus.sol";
import { SignalService } from "../contracts/signal/SignalService.sol";
import { ICrossChainSync } from "../contracts/common/ICrossChainSync.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

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

// PrankDestBridge lets us simulate a transaction to the ERC1155Vault
// from a named Bridge, without having to test/run through the real Bridge code,
// outside the scope of the unit tests in the ERC1155Vault.
contract PrankDestBridge {
    ERC1155Vault destERC1155Vault;

    struct Context {
        bytes32 msgHash; // messageHash
        address sender;
        uint256 srcChainId;
    }

    PrankDestBridge.Context ctx;

    constructor(ERC1155Vault _erc1155Vault) {
        destERC1155Vault = _erc1155Vault;
    }

    function setERC1155Vault(address addr) public {
        destERC1155Vault = ERC1155Vault(addr);
    }

    function context() public view returns (PrankDestBridge.Context memory) {
        return ctx;
    }

    function sendReceiveERC1155ToERC1155Vault(
        NFTVaultParent.CanonicalNFT calldata canonicalToken,
        address from,
        address to,
        uint256 tokenId,
        uint256 amount,
        bytes32 msgHash,
        address srcChainERC1155Vault,
        uint256 srcChainId
    )
        public
    {
        ctx.sender = srcChainERC1155Vault;
        ctx.msgHash = msgHash;
        ctx.srcChainId = srcChainId;

        destERC1155Vault.receiveToken(canonicalToken, from, to, tokenId, amount);

        ctx.sender = address(0);
        ctx.msgHash = bytes32(0);
        ctx.srcChainId = 0;
    }
}


// PrankSrcBridge lets us mock Bridge/SignalService to return true when called
// isMessageFailed()
contract PrankSrcBridge {

    function isMessageFailed(
        bytes32,
        uint256,
        bytes calldata
    )
        public
        view
        virtual
        returns (bool)
    {
        return true;
    }

    function getPreDeterminedDataBytes() external pure returns (bytes memory) {
        return hex"afdef9d600000000000000000000000000000000000000000000000000000000000000a000000000000000000000000010020fcb72e27650651b05ed2ceca493bc807ba400000000000000000000000010020fcb72e27650651b05ed2ceca493bc807ba4000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000007a69000000000000000000000000266fa2526b3d68a1bd9685b87b4d14ae6079f70600000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000000000e0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000018687474703a2f2f6578616d706c652e686f73742e636f6d2f0000000000000000";
    }

    function hashMessage(IBridge.Message calldata message)
        public
        pure
        returns (bytes32)
    {
        return LibBridgeData.hashMessage(message);
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

contract ERC1155VaultTest is Test {
    AddressManager addressManager;
    BadReceiver badReceiver;
    Bridge bridge;
    Bridge destChainBridge;
    PrankDestBridge destChainIdBridge;
    PrankSrcBridge srcPrankBridge;
    ERC1155Vault erc1155Vault;
    ERC1155Vault destChainErc1155Vault;
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

        erc1155Vault = new ERC1155Vault();
        erc1155Vault.init(address(addressManager));

        destChainErc1155Vault = new ERC1155Vault();
        destChainErc1155Vault.init(address(addressManager));

        destChainIdBridge = new PrankDestBridge(destChainErc1155Vault);
        srcPrankBridge = new PrankSrcBridge();

        crossChainSync = new PrankCrossChainSync();

        addressManager.setAddress(
            block.chainid, "signal_service", address(signalService)
        );

        addressManager.setAddress(
            block.chainid, "bridge", address(bridge)
        );

        addressManager.setAddress(
            destChainId, "bridge", address(destChainIdBridge)
        );

        addressManager.setAddress(
            block.chainid, "erc1155_vault", address(erc1155Vault)
        );

        addressManager.setAddress(
            destChainId, "erc1155_vault", address(destChainErc1155Vault)
        );

        canonicalToken1155 = new TestTokenERC1155("http://example.host.com/");
        canonicalToken1155.mint(1, 10);

        vm.stopPrank();
    }

    function test_sendToken_ERC1155()
        public
    {
        vm.prank(Alice, Alice);
        canonicalToken1155.setApprovalForAll(address(erc1155Vault),true);

        assertEq(canonicalToken1155.balanceOf(Alice, 1), 10);
        assertEq(canonicalToken1155.balanceOf(address(erc1155Vault), 1), 0);

        NFTVaultParent.BridgeTransferOp memory sendOpts = NFTVaultParent.BridgeTransferOp(
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
        erc1155Vault.sendToken{ value: 140000 }(sendOpts);

        assertEq(canonicalToken1155.balanceOf(Alice, 1), 8);
        assertEq(canonicalToken1155.balanceOf(address(erc1155Vault), 1), 2);
    }

    function test_decode_message_calldata_1155()
        public
    {

        NFTVaultParent.CanonicalNFT memory canonicalToken = NFTVaultParent.CanonicalNFT({
            srcChainId: 31337,
            tokenAddr: 0x579FBFF1A9b1502688169DA761DcF262b73BB64A,
            symbol: "",
            name: "",
            uri: "http://example.host.com/"
        });

        bytes memory dataToDecode =  abi.encodeWithSelector(
                0xafdef9d6,
                canonicalToken,
                Alice,
                Alice,
                1,
                2
        );

        NFTVaultParent.CanonicalNFT memory nftRetVal;
        address ownerRetVal;
        uint256 tokenIdRetVal;
        uint256 tokenAmountRetVal;
        (nftRetVal, ownerRetVal,,tokenIdRetVal,tokenAmountRetVal) = 
            LibERC1155.decodeTokenData(dataToDecode);

        assertEq(Alice, ownerRetVal);
        assertEq(1, tokenIdRetVal);
        assertEq(2, tokenAmountRetVal);
        assertEq(31337, nftRetVal.srcChainId);
        assertEq(0x579FBFF1A9b1502688169DA761DcF262b73BB64A, nftRetVal.tokenAddr);
        assertEq("", nftRetVal.symbol);
        assertEq("", nftRetVal.name);
        assertEq("http://example.host.com/", nftRetVal.uri);
    }


    function test_sendToken_with_invalid_to_address()
        public
    {
        vm.prank(Alice, Alice);
        canonicalToken1155.setApprovalForAll(address(erc1155Vault),true);

        assertEq(canonicalToken1155.balanceOf(Alice, 1), 10);
        assertEq(canonicalToken1155.balanceOf(address(erc1155Vault), 1), 0);

        NFTVaultParent.BridgeTransferOp memory sendOpts = NFTVaultParent.BridgeTransferOp(
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
        erc1155Vault.sendToken{ value: 140000 }(sendOpts);
    }

    function test_sendToken_with_invalid_token_address()
        public
    {
        vm.prank(Alice, Alice);
        canonicalToken1155.setApprovalForAll(address(erc1155Vault),true);

        assertEq(canonicalToken1155.balanceOf(Alice, 1), 10);
        assertEq(canonicalToken1155.balanceOf(address(erc1155Vault), 1), 0);

        NFTVaultParent.BridgeTransferOp memory sendOpts = NFTVaultParent.BridgeTransferOp(
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
        erc1155Vault.sendToken{ value: 140000 }(sendOpts);
    }

    function test_sendToken_with_0_tokens()
        public
    {
        vm.prank(Alice, Alice);
        canonicalToken1155.setApprovalForAll(address(erc1155Vault),true);

        assertEq(canonicalToken1155.balanceOf(Alice, 1), 10);
        assertEq(canonicalToken1155.balanceOf(address(erc1155Vault), 1), 0);

        NFTVaultParent.BridgeTransferOp memory sendOpts = NFTVaultParent.BridgeTransferOp(
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
        erc1155Vault.sendToken{ value: 140000 }(sendOpts);
    }

    function test_receiveTokens_from_newly_deployed_bridged_contract_on_destination_chain_1155()
        public
    {
        vm.prank(Alice, Alice);
        canonicalToken1155.setApprovalForAll(address(erc1155Vault),true);

        assertEq(canonicalToken1155.balanceOf(Alice, 1), 10);
        assertEq(canonicalToken1155.balanceOf(address(erc1155Vault), 1), 0);

        NFTVaultParent.BridgeTransferOp memory sendOpts = NFTVaultParent.BridgeTransferOp(
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
        erc1155Vault.sendToken{ value: 140000 }(sendOpts);

        assertEq(canonicalToken1155.balanceOf(Alice, 1), 8);
        assertEq(canonicalToken1155.balanceOf(address(erc1155Vault), 1), 2);

        NFTVaultParent.CanonicalNFT memory canonicalToken = NFTVaultParent.CanonicalNFT({
            srcChainId: 31337,
            tokenAddr: address(canonicalToken1155),
            symbol: "",
            name: "",
            uri: "http://example.host.com/"
        });

        uint256 srcChainId = block.chainid;
        vm.chainId(destChainId);

        destChainIdBridge.sendReceiveERC1155ToERC1155Vault(
            canonicalToken,
            Alice,
            Alice,
            1,
            2,
            bytes32(0),
            address(erc1155Vault),
            srcChainId
        );

        // Query canonicalToBridged
        address deployedContract = 
            destChainErc1155Vault.canonicalToBridged(srcChainId, address(canonicalToken1155));

        // Alice bridged over 2 items
        assertEq(ERC1155(deployedContract).balanceOf(Alice, 1), 2);
    }

    function test_receiveTokens_but_mint_not_deploy_if_bridged_second_time_1155()
        public
    {
        vm.prank(Alice, Alice);
        canonicalToken1155.setApprovalForAll(address(erc1155Vault),true);

        assertEq(canonicalToken1155.balanceOf(Alice, 1), 10);
        assertEq(canonicalToken1155.balanceOf(address(erc1155Vault), 1), 0);

        NFTVaultParent.BridgeTransferOp memory sendOpts = NFTVaultParent.BridgeTransferOp(
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
        erc1155Vault.sendToken{ value: 140000 }(sendOpts);

        assertEq(canonicalToken1155.balanceOf(Alice, 1), 8);
        assertEq(canonicalToken1155.balanceOf(address(erc1155Vault), 1), 2);

        NFTVaultParent.CanonicalNFT memory canonicalToken = NFTVaultParent.CanonicalNFT({
            srcChainId: 31337,
            tokenAddr: address(canonicalToken1155),
            symbol: "",
            name: "",
            uri: "http://example.host.com/"
        });

        uint256 srcChainId = block.chainid;
        vm.chainId(destChainId);

        destChainIdBridge.sendReceiveERC1155ToERC1155Vault(
            canonicalToken,
            Alice,
            Alice,
            1,
            2,
            bytes32(0),
            address(erc1155Vault),
            srcChainId
        );

        // Query canonicalToBridged
        address deployedContract = 
            destChainErc1155Vault.canonicalToBridged(srcChainId, address(canonicalToken1155));

        // Alice bridged over 2 items
        assertEq(ERC1155(deployedContract).balanceOf(Alice, 1), 2);

        // Change back to 'L1'
        vm.chainId(srcChainId);

        sendOpts = NFTVaultParent.BridgeTransferOp(
            destChainId,
            Alice,
            address(canonicalToken1155),
            "http://example.host.com/",
            1,
            1,
            140000,
            140000,
            Alice,
            ""
        );
        vm.prank(Alice,Alice);
        erc1155Vault.sendToken{ value: 140000 }(sendOpts);

        assertEq(canonicalToken1155.balanceOf(Alice, 1), 7);
        assertEq(canonicalToken1155.balanceOf(address(erc1155Vault), 1), 3);

        vm.chainId(destChainId);

        destChainIdBridge.sendReceiveERC1155ToERC1155Vault(
            canonicalToken,
            Alice,
            Alice,
            1,
            1,
            bytes32(0),
            address(erc1155Vault),
            srcChainId
        );

        // Query canonicalToBridged
        address bridgedContract = 
            destChainErc1155Vault.canonicalToBridged(srcChainId, address(canonicalToken1155));

        assertEq(bridgedContract, deployedContract);
    }

    function test_releaseToken_1155()
        public
    {
        vm.prank(Alice, Alice);
        canonicalToken1155.setApprovalForAll(address(erc1155Vault),true);

        assertEq(canonicalToken1155.balanceOf(Alice, 1), 10);
        assertEq(canonicalToken1155.balanceOf(address(erc1155Vault), 1), 0);

        NFTVaultParent.BridgeTransferOp memory sendOpts = NFTVaultParent.BridgeTransferOp(
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
        erc1155Vault.sendToken{ value: 140000 }(sendOpts);

        assertEq(canonicalToken1155.balanceOf(Alice, 1), 8);
        assertEq(canonicalToken1155.balanceOf(address(erc1155Vault), 1), 2);

        // Let's test that message is failed and we want to release it back to the owner
        vm.prank(Alice,Alice);
        addressManager.setAddress(
            block.chainid, "bridge", address(srcPrankBridge)
        );

        // Reconstruct the message.
        // Actually the only 2 things absolute necessary to fill are the owner and 
        // srcChain, because we mock the bridge functions, but good to have data 
        // here so that it could have been hashed back to the exact same bytes32 
        // value - if we were not mocking.
        IBridge.Message memory message;
        message.srcChainId = 31337;
        message.destChainId = destChainId;
        message.owner = Alice;
        message.to = address(destChainErc1155Vault);
        message.data = srcPrankBridge.getPreDeterminedDataBytes();
        message.gasLimit = 140000;
        message.processingFee = 140000;
        message.depositValue = 0;
        message.refundAddress = Alice;
        message.memo = "";

        bytes memory proof = bytes("");
        erc1155Vault.releaseToken(message, proof);

        // Alice got back her NFTs, and vault has 0
        assertEq(canonicalToken1155.balanceOf(Alice, 1), 10);
        assertEq(canonicalToken1155.balanceOf(address(erc1155Vault), 1), 0);
    }
}
