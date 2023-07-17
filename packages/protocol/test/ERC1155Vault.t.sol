// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { console2 } from "forge-std/console2.sol";
import { Test } from "forge-std/Test.sol";
import { AddressResolver } from "../contracts/common/AddressResolver.sol";
import { AddressManager } from "../contracts/common/AddressManager.sol";
import { IBridge, Bridge } from "../contracts/bridge/Bridge.sol";
import { LibBridgeData } from "../contracts/bridge/libs/LibBridgeData.sol";
import { BridgeErrors } from "../contracts/bridge/BridgeErrors.sol";
import { BaseNFTVault } from "../contracts/tokenvault/BaseNFTVault.sol";
import { ERC1155Vault } from "../contracts/tokenvault/ERC1155Vault.sol";
import { EtherVault } from "../contracts/bridge/EtherVault.sol";
import { LibBridgeStatus } from "../contracts/bridge/libs/LibBridgeStatus.sol";
import { SignalService } from "../contracts/signal/SignalService.sol";
import { ICrossChainSync } from "../contracts/common/ICrossChainSync.sol";
import { BaseVault } from "../contracts/tokenvault/BaseVault.sol";
import { ERC1155 } from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract TestTokenERC1155 is ERC1155 {
    constructor(string memory baseURI) ERC1155(baseURI) { }

    function mint(uint256 tokenId, uint256 amount) public {
        _mint(msg.sender, tokenId, amount, "");
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

    struct BridgeContext {
        bytes32 msgHash;
        address sender;
        uint256 srcChainId;
    }

    BridgeContext ctx;

    constructor(ERC1155Vault _erc1155Vault) {
        destERC1155Vault = _erc1155Vault;
    }

    function setERC1155Vault(address addr) public {
        destERC1155Vault = ERC1155Vault(addr);
    }

    function context() public view returns (BridgeContext memory) {
        return ctx;
    }

    function sendReceiveERC1155ToERC1155Vault(
        BaseNFTVault.CanonicalNFT calldata ctoken,
        address from,
        address to,
        uint256[] memory tokenIds,
        uint256[] memory amounts,
        bytes32 msgHash,
        address srcChainERC1155Vault,
        uint256 srcChainId
    )
        public
    {
        ctx.sender = srcChainERC1155Vault;
        ctx.msgHash = msgHash;
        ctx.srcChainId = srcChainId;

        destERC1155Vault.receiveToken(ctoken, from, to, tokenIds, amounts);

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
        return
        hex"2605fc9100000000000000000000000000000000000000000000000000000000000000a000000000000000000000000010020fcb72e27650651b05ed2ceca493bc807ba400000000000000000000000010020fcb72e27650651b05ed2ceca493bc807ba400000000000000000000000000000000000000000000000000000000000001c000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000007a69000000000000000000000000266fa2526b3d68a1bd9685b87b4d14ae6079f70600000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000000000e0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000018687474703a2f2f6578616d706c652e686f73742e636f6d2f00000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000002";
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
    TestTokenERC1155 ctoken1155;
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

        addressManager.setAddress(block.chainid, "bridge", address(bridge));

        addressManager.setAddress(
            destChainId, "bridge", address(destChainIdBridge)
        );

        addressManager.setAddress(
            block.chainid, "erc1155_vault", address(erc1155Vault)
        );

        addressManager.setAddress(
            destChainId, "erc1155_vault", address(destChainErc1155Vault)
        );

        ctoken1155 = new TestTokenERC1155("http://example.host.com/");
        ctoken1155.mint(1, 10);
        ctoken1155.mint(2, 10);

        vm.stopPrank();
    }

    function test_sendToken_1155() public {
        vm.prank(Alice, Alice);
        ctoken1155.setApprovalForAll(address(erc1155Vault), true);

        assertEq(ctoken1155.balanceOf(Alice, 1), 10);
        assertEq(ctoken1155.balanceOf(address(erc1155Vault), 1), 0);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 2;

        BaseNFTVault.BridgeTransferOp memory sendOpts = BaseNFTVault
            .BridgeTransferOp(
            destChainId,
            Alice,
            address(ctoken1155),
            "http://example.host.com/",
            tokenIds,
            amounts,
            140_000,
            140_000,
            Alice,
            ""
        );
        vm.prank(Alice, Alice);
        erc1155Vault.sendToken{ value: 140_000 }(sendOpts);

        assertEq(ctoken1155.balanceOf(Alice, 1), 8);
        assertEq(ctoken1155.balanceOf(address(erc1155Vault), 1), 2);
    }

    function test_decode_message_calldata_1155() public {
        BaseNFTVault.CanonicalNFT memory ctoken = BaseNFTVault.CanonicalNFT({
            chainId: 31_337,
            addr: 0x579FBFF1A9b1502688169DA761DcF262b73BB64A,
            symbol: "",
            name: "",
            uri: "http://example.host.com/"
        });

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 2;

        bytes memory dataToDecode = abi.encodeWithSelector(
            0xafdef9d6, ctoken, Alice, Alice, tokenIds, amounts
        );

        BaseNFTVault.CanonicalNFT memory nftRetVal;
        address ownerRetVal;
        uint256[] memory tokenIdsRetVal;
        uint256[] memory tokenAmountsRetVal;
        (nftRetVal, ownerRetVal,, tokenIdsRetVal, tokenAmountsRetVal) =
            erc1155Vault.decodeTokenData(dataToDecode);

        assertEq(Alice, ownerRetVal);
        assertEq(1, tokenIdsRetVal[0]);
        assertEq(2, tokenAmountsRetVal[0]);
        assertEq(31_337, nftRetVal.chainId);
        assertEq(0x579FBFF1A9b1502688169DA761DcF262b73BB64A, nftRetVal.addr);

        assertEq("", nftRetVal.symbol);
        assertEq("", nftRetVal.name);
        assertEq("http://example.host.com/", nftRetVal.uri);
    }

    function test_sendToken_with_invalid_to_address_1155() public {
        vm.prank(Alice, Alice);
        ctoken1155.setApprovalForAll(address(erc1155Vault), true);

        assertEq(ctoken1155.balanceOf(Alice, 1), 10);
        assertEq(ctoken1155.balanceOf(address(erc1155Vault), 1), 0);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 2;

        BaseNFTVault.BridgeTransferOp memory sendOpts = BaseNFTVault
            .BridgeTransferOp(
            destChainId,
            address(0),
            address(ctoken1155),
            "http://example.host.com/",
            tokenIds,
            amounts,
            140_000,
            140_000,
            Alice,
            ""
        );
        vm.prank(Alice, Alice);
        vm.expectRevert(BaseVault.VAULT_INVALID_TO.selector);
        erc1155Vault.sendToken{ value: 140_000 }(sendOpts);
    }

    function test_sendToken_with_invalid_token_address_1155() public {
        vm.prank(Alice, Alice);
        ctoken1155.setApprovalForAll(address(erc1155Vault), true);

        assertEq(ctoken1155.balanceOf(Alice, 1), 10);
        assertEq(ctoken1155.balanceOf(address(erc1155Vault), 1), 0);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 2;

        BaseNFTVault.BridgeTransferOp memory sendOpts = BaseNFTVault
            .BridgeTransferOp(
            destChainId,
            Alice,
            address(0),
            "http://example.host.com/",
            tokenIds,
            amounts,
            140_000,
            140_000,
            Alice,
            ""
        );
        vm.prank(Alice, Alice);
        vm.expectRevert(BaseVault.VAULT_INVALID_TOKEN.selector);
        erc1155Vault.sendToken{ value: 140_000 }(sendOpts);
    }

    function test_sendToken_with_0_tokens_1155() public {
        vm.prank(Alice, Alice);
        ctoken1155.setApprovalForAll(address(erc1155Vault), true);

        assertEq(ctoken1155.balanceOf(Alice, 1), 10);
        assertEq(ctoken1155.balanceOf(address(erc1155Vault), 1), 0);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 0;

        BaseNFTVault.BridgeTransferOp memory sendOpts = BaseNFTVault
            .BridgeTransferOp(
            destChainId,
            Alice,
            address(ctoken1155),
            "http://example.host.com/",
            tokenIds,
            amounts,
            140_000,
            140_000,
            Alice,
            ""
        );
        vm.prank(Alice, Alice);
        vm.expectRevert(BaseVault.VAULT_INVALID_AMOUNT.selector);
        erc1155Vault.sendToken{ value: 140_000 }(sendOpts);
    }

    function test_receiveTokens_from_newly_deployed_bridged_contract_on_destination_chain_1155(
    )
        public
    {
        vm.prank(Alice, Alice);
        ctoken1155.setApprovalForAll(address(erc1155Vault), true);

        assertEq(ctoken1155.balanceOf(Alice, 1), 10);
        assertEq(ctoken1155.balanceOf(address(erc1155Vault), 1), 0);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 2;

        BaseNFTVault.BridgeTransferOp memory sendOpts = BaseNFTVault
            .BridgeTransferOp(
            destChainId,
            Alice,
            address(ctoken1155),
            "http://example.host.com/",
            tokenIds,
            amounts,
            140_000,
            140_000,
            Alice,
            ""
        );
        vm.prank(Alice, Alice);
        erc1155Vault.sendToken{ value: 140_000 }(sendOpts);

        assertEq(ctoken1155.balanceOf(Alice, 1), 8);
        assertEq(ctoken1155.balanceOf(address(erc1155Vault), 1), 2);

        amounts[0] = 2;
        BaseNFTVault.CanonicalNFT memory ctoken = BaseNFTVault.CanonicalNFT({
            chainId: 31_337,
            addr: address(ctoken1155),
            symbol: "",
            name: "",
            uri: "http://example.host.com/"
        });

        uint256 srcChainId = block.chainid;
        vm.chainId(destChainId);

        destChainIdBridge.sendReceiveERC1155ToERC1155Vault(
            ctoken,
            Alice,
            Alice,
            tokenIds,
            amounts,
            bytes32(0),
            address(erc1155Vault),
            srcChainId
        );

        // Query canonicalToBridged
        address deployedContract = destChainErc1155Vault.canonicalToBridged(
            srcChainId, address(ctoken1155)
        );

        // Alice bridged over 2 items
        assertEq(ERC1155(deployedContract).balanceOf(Alice, 1), 2);
    }

    function test_receiveTokens_but_mint_not_deploy_if_bridged_second_time_1155(
    )
        public
    {
        vm.prank(Alice, Alice);
        ctoken1155.setApprovalForAll(address(erc1155Vault), true);

        assertEq(ctoken1155.balanceOf(Alice, 1), 10);
        assertEq(ctoken1155.balanceOf(address(erc1155Vault), 1), 0);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 2;

        BaseNFTVault.BridgeTransferOp memory sendOpts = BaseNFTVault
            .BridgeTransferOp(
            destChainId,
            Alice,
            address(ctoken1155),
            "http://example.host.com/",
            tokenIds,
            amounts,
            140_000,
            140_000,
            Alice,
            ""
        );
        vm.prank(Alice, Alice);
        erc1155Vault.sendToken{ value: 140_000 }(sendOpts);

        assertEq(ctoken1155.balanceOf(Alice, 1), 8);
        assertEq(ctoken1155.balanceOf(address(erc1155Vault), 1), 2);

        BaseNFTVault.CanonicalNFT memory ctoken = BaseNFTVault.CanonicalNFT({
            chainId: 31_337,
            addr: address(ctoken1155),
            symbol: "",
            name: "",
            uri: "http://example.host.com/"
        });

        uint256 srcChainId = block.chainid;
        vm.chainId(destChainId);

        destChainIdBridge.sendReceiveERC1155ToERC1155Vault(
            ctoken,
            Alice,
            Alice,
            tokenIds,
            amounts,
            bytes32(0),
            address(erc1155Vault),
            srcChainId
        );

        // Query canonicalToBridged
        address deployedContract = destChainErc1155Vault.canonicalToBridged(
            srcChainId, address(ctoken1155)
        );

        // Alice bridged over 2 items
        assertEq(ERC1155(deployedContract).balanceOf(Alice, 1), 2);

        // Change back to 'L1'
        vm.chainId(srcChainId);

        tokenIds[0] = 1;
        amounts[0] = 1;

        sendOpts = BaseNFTVault.BridgeTransferOp(
            destChainId,
            Alice,
            address(ctoken1155),
            "http://example.host.com/",
            tokenIds,
            amounts,
            140_000,
            140_000,
            Alice,
            ""
        );
        vm.prank(Alice, Alice);
        erc1155Vault.sendToken{ value: 140_000 }(sendOpts);

        assertEq(ctoken1155.balanceOf(Alice, 1), 7);
        assertEq(ctoken1155.balanceOf(address(erc1155Vault), 1), 3);

        vm.chainId(destChainId);

        destChainIdBridge.sendReceiveERC1155ToERC1155Vault(
            ctoken,
            Alice,
            Alice,
            tokenIds,
            amounts,
            bytes32(0),
            address(erc1155Vault),
            srcChainId
        );

        // Query canonicalToBridged
        address bridgedContract = destChainErc1155Vault.canonicalToBridged(
            srcChainId, address(ctoken1155)
        );

        assertEq(bridgedContract, deployedContract);
    }

    function test_releaseToken_1155() public {
        vm.prank(Alice, Alice);
        ctoken1155.setApprovalForAll(address(erc1155Vault), true);

        assertEq(ctoken1155.balanceOf(Alice, 1), 10);
        assertEq(ctoken1155.balanceOf(address(erc1155Vault), 1), 0);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 2;

        BaseNFTVault.BridgeTransferOp memory sendOpts = BaseNFTVault
            .BridgeTransferOp(
            destChainId,
            Alice,
            address(ctoken1155),
            "http://example.host.com/",
            tokenIds,
            amounts,
            140_000,
            140_000,
            Alice,
            ""
        );
        vm.prank(Alice, Alice);
        erc1155Vault.sendToken{ value: 140_000 }(sendOpts);

        assertEq(ctoken1155.balanceOf(Alice, 1), 8);
        assertEq(ctoken1155.balanceOf(address(erc1155Vault), 1), 2);

        // Let's test that message is failed and we want to release it back to
        // the owner
        vm.prank(Alice, Alice);
        addressManager.setAddress(
            block.chainid, "bridge", address(srcPrankBridge)
        );

        // Reconstruct the message.
        // Actually the only 2 things absolute necessary to fill are the owner
        // and
        // srcChain, because we mock the bridge functions, but good to have data
        // here so that it could have been hashed back to the exact same bytes32
        // value - if we were not mocking.
        IBridge.Message memory message;
        message.srcChainId = 31_337;
        message.destChainId = destChainId;
        message.owner = Alice;
        message.to = address(destChainErc1155Vault);
        message.data = srcPrankBridge.getPreDeterminedDataBytes();
        message.gasLimit = 140_000;
        message.processingFee = 140_000;
        message.depositValue = 0;
        message.refundAddress = Alice;
        message.memo = "";

        bytes memory proof = bytes("");
        erc1155Vault.releaseToken(message, proof);

        // Alice got back her NFTs, and vault has 0
        assertEq(ctoken1155.balanceOf(Alice, 1), 10);
        assertEq(ctoken1155.balanceOf(address(erc1155Vault), 1), 0);
    }

    function test_receiveTokens_multiple_1155() public {
        vm.prank(Alice, Alice);
        ctoken1155.setApprovalForAll(address(erc1155Vault), true);

        assertEq(ctoken1155.balanceOf(Alice, 1), 10);
        assertEq(ctoken1155.balanceOf(address(erc1155Vault), 1), 0);

        assertEq(ctoken1155.balanceOf(Alice, 2), 10);
        assertEq(ctoken1155.balanceOf(address(erc1155Vault), 2), 0);

        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 1;
        tokenIds[1] = 2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 2;
        amounts[1] = 5;

        BaseNFTVault.BridgeTransferOp memory sendOpts = BaseNFTVault
            .BridgeTransferOp(
            destChainId,
            Alice,
            address(ctoken1155),
            "http://example.host.com/",
            tokenIds,
            amounts,
            140_000,
            140_000,
            Alice,
            ""
        );
        vm.prank(Alice, Alice);
        erc1155Vault.sendToken{ value: 140_000 }(sendOpts);

        assertEq(ctoken1155.balanceOf(Alice, 1), 8);
        assertEq(ctoken1155.balanceOf(address(erc1155Vault), 1), 2);

        assertEq(ctoken1155.balanceOf(Alice, 2), 5);
        assertEq(ctoken1155.balanceOf(address(erc1155Vault), 2), 5);

        BaseNFTVault.CanonicalNFT memory ctoken = BaseNFTVault.CanonicalNFT({
            chainId: 31_337,
            addr: address(ctoken1155),
            symbol: "",
            name: "",
            uri: "http://example.host.com/"
        });

        uint256 srcChainId = block.chainid;
        vm.chainId(destChainId);

        destChainIdBridge.sendReceiveERC1155ToERC1155Vault(
            ctoken,
            Alice,
            Alice,
            tokenIds,
            amounts,
            bytes32(0),
            address(erc1155Vault),
            srcChainId
        );

        // Query canonicalToBridged
        address deployedContract = destChainErc1155Vault.canonicalToBridged(
            srcChainId, address(ctoken1155)
        );

        // Alice bridged over 2 items
        assertEq(ERC1155(deployedContract).balanceOf(Alice, 1), 2);
        assertEq(ERC1155(deployedContract).balanceOf(Alice, 2), 5);
    }
}
