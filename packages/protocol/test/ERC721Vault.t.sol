// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { console2 } from "forge-std/console2.sol";
import { Test } from "forge-std/Test.sol";
import { AddressManager } from "../contracts/common/AddressManager.sol";
import { IBridge, Bridge } from "../contracts/bridge/Bridge.sol";
import { LibBridgeData } from "../contracts/bridge/libs/LibBridgeData.sol";
import { BridgeErrors } from "../contracts/bridge/BridgeErrors.sol";
import { BaseNFTVault } from "../contracts/tokenvault/BaseNFTVault.sol";
import { ERC721Vault } from "../contracts/tokenvault/ERC721Vault.sol";
import { EtherVault } from "../contracts/bridge/EtherVault.sol";
import { LibBridgeStatus } from "../contracts/bridge/libs/LibBridgeStatus.sol";
import { SignalService } from "../contracts/signal/SignalService.sol";
import { ICrossChainSync } from "../contracts/common/ICrossChainSync.sol";
import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { BaseVault } from "../contracts/tokenvault/BaseVault.sol";

contract TestTokenERC721 is ERC721 {
    string _baseTokenURI;
    uint256 minted;

    constructor(string memory baseURI) ERC721("TT", "TT") {
        setBaseURI(baseURI);
    }

    function setBaseURI(string memory baseURI) internal {
        _baseTokenURI = baseURI;
    }

    function _baseURI()
        internal
        view
        virtual
        override
        returns (string memory)
    {
        return _baseTokenURI;
    }

    function mint(uint256 amount) public {
        for (uint256 i; i < amount; i++) {
            _safeMint(msg.sender, minted + i);
        }
        minted += amount;
    }
}

// NonNftContract
contract NonNftContract {
    uint256 dummyData;

    constructor(uint256 _dummyData) {
        dummyData = _dummyData;
    }
}

// PrankDestBridge lets us simulate a transaction to the erc721Vault
// from a named Bridge, without having to test/run through the real Bridge code,
// outside the scope of the unit tests in the erc721Vault.
contract PrankDestBridge {
    ERC721Vault destERC721Vault;

    struct BridgeContext {
        bytes32 msgHash;
        address sender;
        uint256 chainId;
    }

    BridgeContext ctx;

    constructor(ERC721Vault _erc721Vault) {
        destERC721Vault = _erc721Vault;
    }

    function setERC721Vault(address addr) public {
        destERC721Vault = ERC721Vault(addr);
    }

    function context() public view returns (BridgeContext memory) {
        return ctx;
    }

    function sendReceiveERC721ToERC721Vault(
        BaseNFTVault.CanonicalNFT calldata canonicalToken,
        address from,
        address to,
        uint256[] memory tokenIds,
        bytes32 msgHash,
        address srcChainerc721Vault,
        uint256 chainId
    )
        public
    {
        ctx.sender = srcChainerc721Vault;
        ctx.msgHash = msgHash;
        ctx.chainId = chainId;

        destERC721Vault.receiveToken(canonicalToken, from, to, tokenIds);

        ctx.sender = address(0);
        ctx.msgHash = bytes32(0);
        ctx.chainId = 0;
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
        hex"1d7b460b000000000000000000000000000000000000000000000000000000000000008000000000000000000000000010020fcb72e27650651b05ed2ceca493bc807ba400000000000000000000000010020fcb72e27650651b05ed2ceca493bc807ba400000000000000000000000000000000000000000000000000000000000001e00000000000000000000000000000000000000000000000000000000000007a69000000000000000000000000266fa2526b3d68a1bd9685b87b4d14ae6079f70600000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000e0000000000000000000000000000000000000000000000000000000000000012000000000000000000000000000000000000000000000000000000000000000025454000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000254540000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000018687474703a2f2f6578616d706c652e686f73742e636f6d2f000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001";
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

contract ERC721VaultTest is Test {
    AddressManager addressManager;
    BadReceiver badReceiver;
    Bridge bridge;
    Bridge destChainBridge;
    PrankDestBridge destChainIdBridge;
    PrankSrcBridge srcPrankBridge;
    ERC721Vault erc721Vault;
    ERC721Vault destChainErc721Vault;
    TestTokenERC721 canonicalToken721;
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

        erc721Vault = new ERC721Vault();
        erc721Vault.init(address(addressManager));

        destChainErc721Vault = new ERC721Vault();
        destChainErc721Vault.init(address(addressManager));

        destChainIdBridge = new PrankDestBridge(destChainErc721Vault);
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
            block.chainid, "erc721_vault", address(erc721Vault)
        );

        addressManager.setAddress(
            destChainId, "erc721_vault", address(destChainErc721Vault)
        );

        canonicalToken721 = new TestTokenERC721("http://example.host.com/");
        canonicalToken721.mint(10);

        vm.stopPrank();
    }

    function test_sendToken_721() public {
        vm.prank(Alice, Alice);
        canonicalToken721.approve(address(erc721Vault), 1);

        assertEq(canonicalToken721.ownerOf(1), Alice);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 0;

        BaseNFTVault.BridgeTransferOp memory sendOpts = BaseNFTVault
            .BridgeTransferOp(
            destChainId,
            Alice,
            address(canonicalToken721),
            "http://example.host.com/",
            tokenIds,
            amounts, // With ERC721 still need to specify 1
            140_000,
            140_000,
            Alice,
            ""
        );
        vm.prank(Alice, Alice);
        erc721Vault.sendToken{ value: 140_000 }(sendOpts);

        assertEq(ERC721(canonicalToken721).ownerOf(1), address(erc721Vault));
    }

    function test_decode_message_calldata_721() public {
        BaseNFTVault.CanonicalNFT memory canonicalToken = BaseNFTVault
            .CanonicalNFT({
            chainId: 31_337,
            addr: 0x579FBFF1A9b1502688169DA761DcF262b73BB64A,
            symbol: "TT",
            name: "TT",
            uri: "http://example.host.com/"
        });

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        bytes memory dataToDecode = abi.encodeWithSelector(
            0x2c349adf, canonicalToken, Alice, Alice, tokenIds
        );

        BaseNFTVault.CanonicalNFT memory nftRetVal;
        address ownerRetVal;
        uint256[] memory tokenIdsRetVal;
        (nftRetVal, ownerRetVal,, tokenIdsRetVal) =
            erc721Vault.decodeTokenData(dataToDecode);

        assertEq(Alice, ownerRetVal);
        assertEq(1, tokenIdsRetVal[0]);
        assertEq(31_337, nftRetVal.chainId);
        assertEq(0x579FBFF1A9b1502688169DA761DcF262b73BB64A, nftRetVal.addr);

        assertEq("TT", nftRetVal.symbol);
        assertEq("TT", nftRetVal.name);
        assertEq("http://example.host.com/", nftRetVal.uri);
    }

    function test_sendToken_with_invalid_to_address_721() public {
        vm.prank(Alice, Alice);
        canonicalToken721.approve(address(erc721Vault), 1);

        assertEq(canonicalToken721.ownerOf(1), Alice);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 0;

        BaseNFTVault.BridgeTransferOp memory sendOpts = BaseNFTVault
            .BridgeTransferOp(
            destChainId,
            address(0),
            address(canonicalToken721),
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
        erc721Vault.sendToken{ value: 140_000 }(sendOpts);
    }

    function test_sendToken_with_invalid_token_address() public {
        vm.prank(Alice, Alice);
        canonicalToken721.approve(address(erc721Vault), 1);

        assertEq(canonicalToken721.ownerOf(1), Alice);

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
        erc721Vault.sendToken{ value: 140_000 }(sendOpts);
    }

    function test_sendToken_with_1_tokens_but_erc721_amount_1_invalid()
        public
    {
        vm.prank(Alice, Alice);
        canonicalToken721.approve(address(erc721Vault), 1);

        assertEq(canonicalToken721.ownerOf(1), Alice);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;
        BaseNFTVault.BridgeTransferOp memory sendOpts = BaseNFTVault
            .BridgeTransferOp(
            destChainId,
            Alice,
            address(canonicalToken721),
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
        erc721Vault.sendToken{ value: 140_000 }(sendOpts);
    }

    function test_receiveTokens_from_newly_deployed_bridged_contract_on_destination_chain_721(
    )
        public
    {
        vm.prank(Alice, Alice);
        canonicalToken721.approve(address(erc721Vault), 1);

        assertEq(canonicalToken721.ownerOf(1), Alice);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 0;

        BaseNFTVault.BridgeTransferOp memory sendOpts = BaseNFTVault
            .BridgeTransferOp(
            destChainId,
            Alice,
            address(canonicalToken721),
            "http://example.host.com/",
            tokenIds,
            amounts,
            140_000,
            140_000,
            Alice,
            ""
        );
        vm.prank(Alice, Alice);
        erc721Vault.sendToken{ value: 140_000 }(sendOpts);

        assertEq(canonicalToken721.ownerOf(1), address(erc721Vault));

        BaseNFTVault.CanonicalNFT memory canonicalToken = BaseNFTVault
            .CanonicalNFT({
            chainId: 31_337,
            addr: address(canonicalToken721),
            symbol: "TT",
            name: "TT",
            uri: "http://example.host.com/"
        });

        uint256 chainId = block.chainid;
        vm.chainId(destChainId);

        destChainIdBridge.sendReceiveERC721ToERC721Vault(
            canonicalToken,
            Alice,
            Alice,
            tokenIds,
            bytes32(0),
            address(erc721Vault),
            chainId
        );

        // Query canonicalToBridged
        address deployedContract = destChainErc721Vault.canonicalToBridged(
            chainId, address(canonicalToken721)
        );

        // Alice bridged over tokenId 1
        assertEq(ERC721(deployedContract).ownerOf(1), Alice);
    }

    function test_receiveTokens_but_mint_not_deploy_if_bridged_second_time_721()
        public
    {
        vm.prank(Alice, Alice);
        canonicalToken721.approve(address(erc721Vault), 1);
        vm.prank(Alice, Alice);
        canonicalToken721.approve(address(erc721Vault), 2);

        assertEq(canonicalToken721.ownerOf(1), Alice);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 0;

        BaseNFTVault.BridgeTransferOp memory sendOpts = BaseNFTVault
            .BridgeTransferOp(
            destChainId,
            Alice,
            address(canonicalToken721),
            "http://example.host.com/",
            tokenIds,
            amounts,
            140_000,
            140_000,
            Alice,
            ""
        );
        vm.prank(Alice, Alice);
        erc721Vault.sendToken{ value: 140_000 }(sendOpts);

        assertEq(canonicalToken721.ownerOf(1), address(erc721Vault));

        // This canonicalToken is basically need to be exact same as the
        // sendToken() puts together
        // - here is just mocking putting it together.
        BaseNFTVault.CanonicalNFT memory canonicalToken = BaseNFTVault
            .CanonicalNFT({
            chainId: 31_337,
            addr: address(canonicalToken721),
            symbol: "TT",
            name: "TT",
            uri: "http://example.host.com/"
        });

        uint256 chainId = block.chainid;
        vm.chainId(destChainId);

        destChainIdBridge.sendReceiveERC721ToERC721Vault(
            canonicalToken,
            Alice,
            Alice,
            tokenIds,
            bytes32(0),
            address(erc721Vault),
            chainId
        );

        // Query canonicalToBridged
        address deployedContract = destChainErc721Vault.canonicalToBridged(
            chainId, address(canonicalToken721)
        );

        // Alice bridged over tokenId 1
        assertEq(ERC721(deployedContract).ownerOf(1), Alice);

        // Change back to 'L1'
        vm.chainId(chainId);

        tokenIds[0] = 2;

        amounts[0] = 0;

        sendOpts = BaseNFTVault.BridgeTransferOp(
            destChainId,
            Alice,
            address(canonicalToken721),
            "http://example.host.com/",
            tokenIds,
            amounts,
            140_000,
            140_000,
            Alice,
            ""
        );
        vm.prank(Alice, Alice);
        erc721Vault.sendToken{ value: 140_000 }(sendOpts);

        assertEq(canonicalToken721.ownerOf(2), address(erc721Vault));

        vm.chainId(destChainId);

        destChainIdBridge.sendReceiveERC721ToERC721Vault(
            canonicalToken,
            Alice,
            Alice,
            tokenIds,
            bytes32(0),
            address(erc721Vault),
            chainId
        );

        // Query canonicalToBridged
        address bridgedContract = destChainErc721Vault.canonicalToBridged(
            chainId, address(canonicalToken721)
        );

        assertEq(bridgedContract, deployedContract);
    }

    function test_releaseToken_721() public {
        vm.prank(Alice, Alice);
        canonicalToken721.approve(address(erc721Vault), 1);

        assertEq(canonicalToken721.ownerOf(1), Alice);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 0;

        BaseNFTVault.BridgeTransferOp memory sendOpts = BaseNFTVault
            .BridgeTransferOp(
            destChainId,
            Alice,
            address(canonicalToken721),
            "http://example.host.com/",
            tokenIds,
            amounts,
            140_000,
            140_000,
            Alice,
            ""
        );
        vm.prank(Alice, Alice);
        erc721Vault.sendToken{ value: 140_000 }(sendOpts);

        assertEq(canonicalToken721.ownerOf(1), address(erc721Vault));

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
        message.to = address(destChainErc721Vault);
        message.data = srcPrankBridge.getPreDeterminedDataBytes();
        message.gasLimit = 140_000;
        message.processingFee = 140_000;
        message.depositValue = 0;
        message.refundAddress = Alice;
        message.memo = "";

        bytes memory proof = bytes("");
        erc721Vault.releaseToken(message, proof);

        // Alice got back her NFT
        assertEq(canonicalToken721.ownerOf(1), Alice);
    }

    function test_receiveTokens_multiple_721() public {
        vm.prank(Alice, Alice);
        canonicalToken721.approve(address(erc721Vault), 1);
        vm.prank(Alice, Alice);
        canonicalToken721.approve(address(erc721Vault), 2);

        assertEq(canonicalToken721.ownerOf(1), Alice);
        assertEq(canonicalToken721.ownerOf(2), Alice);

        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 1;
        tokenIds[1] = 2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 0;
        amounts[1] = 0;

        BaseNFTVault.BridgeTransferOp memory sendOpts = BaseNFTVault
            .BridgeTransferOp(
            destChainId,
            Alice,
            address(canonicalToken721),
            "http://example.host.com/",
            tokenIds,
            amounts,
            140_000,
            140_000,
            Alice,
            ""
        );
        vm.prank(Alice, Alice);
        erc721Vault.sendToken{ value: 140_000 }(sendOpts);

        assertEq(canonicalToken721.ownerOf(1), address(erc721Vault));
        assertEq(canonicalToken721.ownerOf(2), address(erc721Vault));

        BaseNFTVault.CanonicalNFT memory canonicalToken = BaseNFTVault
            .CanonicalNFT({
            chainId: 31_337,
            addr: address(canonicalToken721),
            symbol: "TT",
            name: "TT",
            uri: "http://example.host.com/"
        });

        uint256 srcChainId = block.chainid;
        vm.chainId(destChainId);

        destChainIdBridge.sendReceiveERC721ToERC721Vault(
            canonicalToken,
            Alice,
            Alice,
            tokenIds,
            bytes32(0),
            address(erc721Vault),
            srcChainId
        );

        // Query canonicalToBridged
        address deployedContract = destChainErc721Vault.canonicalToBridged(
            srcChainId, address(canonicalToken721)
        );

        // Alice bridged over tokenId 1
        assertEq(ERC721(deployedContract).ownerOf(1), Alice);
        assertEq(ERC721(deployedContract).ownerOf(2), Alice);
    }
}
