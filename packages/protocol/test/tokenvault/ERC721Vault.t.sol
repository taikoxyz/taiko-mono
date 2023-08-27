// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { console2 } from "forge-std/console2.sol";
import {
    TestBase,
    SkipProofCheckBridge,
    DummyCrossChainSync,
    NonNftContract,
    BadReceiver
} from "../TestBase.sol";
import { AddressManager } from "../../contracts/common/AddressManager.sol";
import { IBridge, Bridge } from "../../contracts/bridge/Bridge.sol";
import { LibBridgeData } from "../../contracts/bridge/libs/LibBridgeData.sol";
import { BridgeErrors } from "../../contracts/bridge/BridgeErrors.sol";
import { BaseNFTVault } from "../../contracts/tokenvault/BaseNFTVault.sol";
import { ERC721Vault } from "../../contracts/tokenvault/ERC721Vault.sol";
import { BridgedERC721 } from "../../contracts/tokenvault/BridgedERC721.sol";
import { EtherVault } from "../../contracts/bridge/EtherVault.sol";
import { LibBridgeStatus } from
    "../../contracts/bridge/libs/LibBridgeStatus.sol";
import { SignalService } from "../../contracts/signal/SignalService.sol";
import { ICrossChainSync } from "../../contracts/common/ICrossChainSync.sol";
import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import
    "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

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

    function sendMessage(IBridge.Message memory message)
        external
        payable
        returns (bytes32 msgHash)
    {
        // Dummy return value
        return keccak256(abi.encode(message.id));
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
        uint256 chainId,
        uint256 mockLibInvokeMsgValue
    )
        public
    {
        ctx.sender = srcChainerc721Vault;
        ctx.msgHash = msgHash;
        ctx.chainId = chainId;

        // We need this in order to 'mock' the LibBridgeInvoke's
        //  (success,retVal) =
        //     message.to.call{ value: message.value, gas: gasLimit
        // }(message.data);
        // The problem (with foundry) is that this way it is not able to deploy
        // a contract
        // most probably due to some deployment address nonce issue. (Seems a
        // known issue).
        destERC721Vault.receiveToken{ value: mockLibInvokeMsgValue }(
            canonicalToken, from, to, tokenIds
        );

        ctx.sender = address(0);
        ctx.msgHash = bytes32(0);
        ctx.chainId = 0;
    }
}

// PrankSrcBridge lets us mock Bridge/SignalService to return true when called
// isMessageFailed()
contract PrankSrcBridge is SkipProofCheckBridge {
    function getPreDeterminedDataBytes() external pure returns (bytes memory) {
        return
        hex"a9976baf000000000000000000000000000000000000000000000000000000000000008000000000000000000000000010020fcb72e27650651b05ed2ceca493bc807ba400000000000000000000000010020fcb72e27650651b05ed2ceca493bc807ba400000000000000000000000000000000000000000000000000000000000001800000000000000000000000000000000000000000000000000000000000007a69000000000000000000000000f349eda7118cad7972b7401c1f5d71e9ea218ef8000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000c0000000000000000000000000000000000000000000000000000000000000000254540000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002545400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001";
    }
}

contract UpdatedBridgedERC721 is BridgedERC721 {
    function helloWorld() public pure returns (string memory) {
        return "helloworld";
    }
}

contract ERC721VaultTest is TestBase {
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
    DummyCrossChainSync crossChainSync;
    uint256 destChainId = 19_389;

    //Need +1 bc. and Amelia is the proxied bridge contracts owner
    address public constant Amelia = 0x60081B12838240B1BA02b3177153BCa678A86080;

    function setUp() public {
        // TODO(dani): we have to overwrite Alice address, otherise
        // test_onMessageRecalled_721 will fail. Do you know why?
        Alice = 0x10020FCb72e27650651B05eD2CEcA493bC807Ba4;

        vm.startPrank(Amelia);
        vm.deal(Alice, 100 ether);
        vm.deal(Amelia, 100 ether);
        vm.deal(Bob, 100 ether);
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
        vm.deal(address(destChainIdBridge), 100 ether);

        srcPrankBridge = new PrankSrcBridge();
        srcPrankBridge.init(address(addressManager));

        crossChainSync = new DummyCrossChainSync();

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
        // Below 2-2 registrations (mock) are needed bc of
        // LibBridgeRecall.sol's
        // resolve address
        addressManager.setAddress(
            destChainId, "erc1155_vault", address(srcPrankBridge)
        );
        addressManager.setAddress(
            destChainId, "erc20_vault", address(srcPrankBridge)
        );
        addressManager.setAddress(
            block.chainid, "erc1155_vault", address(srcPrankBridge)
        );
        addressManager.setAddress(
            block.chainid, "erc20_vault", address(srcPrankBridge)
        );
        addressManager.setAddress(
            block.chainid, "ether_vault", address(etherVault)
        );
        // Authorize
        etherVault.authorize(address(srcPrankBridge), true);
        etherVault.authorize(address(bridge), true);

        vm.stopPrank();

        vm.startPrank(Alice);
        canonicalToken721 = new TestTokenERC721("http://example.host.com/");
        canonicalToken721.mint(10);

        vm.stopPrank();
    }

    function test_721Vault_sendToken_721() public {
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

    function test_721Vault_sendToken_with_invalid_to_address_721() public {
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
            tokenIds,
            amounts,
            140_000,
            140_000,
            Alice,
            ""
        );
        vm.prank(Alice, Alice);
        vm.expectRevert(BaseNFTVault.VAULT_INVALID_TO.selector);
        erc721Vault.sendToken{ value: 140_000 }(sendOpts);
    }

    function test_721Vault_sendToken_with_invalid_token_address() public {
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
            address(0),
            tokenIds,
            amounts,
            140_000,
            140_000,
            Alice,
            ""
        );
        vm.prank(Alice, Alice);
        vm.expectRevert(BaseNFTVault.VAULT_INVALID_TOKEN.selector);
        erc721Vault.sendToken{ value: 140_000 }(sendOpts);
    }

    function test_721Vault_sendToken_with_1_tokens_but_erc721_amount_1_invalid()
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
            tokenIds,
            amounts,
            140_000,
            140_000,
            Alice,
            ""
        );
        vm.prank(Alice, Alice);
        vm.expectRevert(BaseNFTVault.VAULT_INVALID_AMOUNT.selector);
        erc721Vault.sendToken{ value: 140_000 }(sendOpts);
    }

    function test_721Vault_receiveTokens_from_newly_deployed_bridged_contract_on_destination_chain_721(
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
            name: "TT"
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
            chainId,
            0
        );

        // Query canonicalToBridged
        address deployedContract = destChainErc721Vault.canonicalToBridged(
            chainId, address(canonicalToken721)
        );

        // Alice bridged over tokenId 1
        assertEq(ERC721(deployedContract).ownerOf(1), Alice);
    }

    function test_721Vault_receiveTokens_but_mint_not_deploy_if_bridged_second_time_721(
    )
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
            name: "TT"
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
            chainId,
            0
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
            chainId,
            0
        );

        // Query canonicalToBridged
        address bridgedContract = destChainErc721Vault.canonicalToBridged(
            chainId, address(canonicalToken721)
        );

        assertEq(bridgedContract, deployedContract);
    }

    function test_721Vault_receiveTokens_erc721_with_ether_to_dave() public {
        vm.prank(Alice, Alice);
        canonicalToken721.approve(address(erc721Vault), 1);

        assertEq(canonicalToken721.ownerOf(1), Alice);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 0;

        uint256 etherValue = 0.1 ether;
        BaseNFTVault.BridgeTransferOp memory sendOpts = BaseNFTVault
            .BridgeTransferOp(
            destChainId,
            David,
            address(canonicalToken721),
            tokenIds,
            amounts,
            140_000,
            140_000,
            Alice,
            ""
        );
        vm.prank(Alice, Alice);
        erc721Vault.sendToken{ value: etherValue }(sendOpts);

        assertEq(canonicalToken721.ownerOf(1), address(erc721Vault));

        BaseNFTVault.CanonicalNFT memory canonicalToken = BaseNFTVault
            .CanonicalNFT({
            chainId: 31_337,
            addr: address(canonicalToken721),
            symbol: "TT",
            name: "TT"
        });

        uint256 chainId = block.chainid;
        vm.chainId(destChainId);

        destChainIdBridge.sendReceiveERC721ToERC721Vault(
            canonicalToken,
            Alice,
            David,
            tokenIds,
            bytes32(0),
            address(erc721Vault),
            chainId,
            etherValue
        );

        // Query canonicalToBridged
        address deployedContract = destChainErc721Vault.canonicalToBridged(
            chainId, address(canonicalToken721)
        );

        // Alice bridged over tokenId 1 and etherValue to David
        assertEq(ERC721(deployedContract).ownerOf(1), David);
        assertEq(etherValue, David.balance);
    }

    function test_721Vault_onMessageRecalled_721() public {
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
            tokenIds,
            amounts,
            140_000,
            140_000,
            Alice,
            ""
        );
        // Let's test that message is failed and we want to release it back to
        // the owner
        vm.prank(Amelia, Amelia);
        addressManager.setAddress(
            block.chainid, "bridge", address(srcPrankBridge)
        );

        vm.prank(Alice, Alice);
        erc721Vault.sendToken{ value: 140_000 }(sendOpts);

        assertEq(canonicalToken721.ownerOf(1), address(erc721Vault));

        // Reconstruct the message.
        // Actually the only 2 things absolute necessary to fill are the owner
        // and
        // srcChain, because we mock the bridge functions, but good to have data
        // here so that it could have been hashed back to the exact same bytes32
        // value - if we were not mocking.
        IBridge.Message memory message;
        message.srcChainId = 31_337;
        message.destChainId = destChainId;
        message.user = Alice;
        message.from = address(erc721Vault);
        message.to = address(destChainErc721Vault);
        message.data = srcPrankBridge.getPreDeterminedDataBytes();
        message.gasLimit = 140_000;
        message.fee = 140_000;
        message.refundTo = Alice;
        message.memo = "";
        bytes memory proof = bytes("");

        srcPrankBridge.recallMessage(message, proof);

        // Alice got back her NFT
        assertEq(canonicalToken721.ownerOf(1), Alice);
    }

    function test_721Vault_receiveTokens_multiple_721() public {
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
            name: "TT"
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
            srcChainId,
            0
        );

        // Query canonicalToBridged
        address deployedContract = destChainErc721Vault.canonicalToBridged(
            srcChainId, address(canonicalToken721)
        );

        // Alice bridged over tokenId 1
        assertEq(ERC721(deployedContract).ownerOf(1), Alice);
        assertEq(ERC721(deployedContract).ownerOf(2), Alice);
    }

    function test_721Vault_bridge_back_but_owner_is_different_now_721()
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
            name: "TT"
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
            chainId,
            0
        );

        // Query canonicalToBridged
        address deployedContract = destChainErc721Vault.canonicalToBridged(
            chainId, address(canonicalToken721)
        );

        // Alice bridged over tokenId 1
        assertEq(ERC721(deployedContract).ownerOf(1), Alice);

        // Transfer the asset to Bob, and Bob can receive it back on canonical
        // chain
        vm.prank(Alice, Alice);
        ERC721(deployedContract).transferFrom(Alice, Bob, 1);

        assertEq(ERC721(deployedContract).ownerOf(1), Bob);

        vm.prank(Bob, Bob);
        ERC721(deployedContract).approve(address(destChainErc721Vault), 1);

        sendOpts = BaseNFTVault.BridgeTransferOp(
            chainId,
            Bob,
            address(deployedContract),
            tokenIds,
            amounts,
            140_000,
            140_000,
            Bob,
            ""
        );

        vm.prank(Bob, Bob);
        destChainErc721Vault.sendToken{ value: 140_000 }(sendOpts);

        vm.chainId(chainId);

        assertEq(ERC721(canonicalToken721).ownerOf(1), address(erc721Vault));

        destChainIdBridge.setERC721Vault(address(erc721Vault));

        vm.prank(Amelia, Amelia);
        addressManager.setAddress(
            block.chainid, "bridge", address(destChainIdBridge)
        );

        destChainIdBridge.sendReceiveERC721ToERC721Vault(
            canonicalToken,
            Bob,
            Bob,
            tokenIds,
            bytes32(0),
            address(erc721Vault),
            chainId,
            0
        );

        assertEq(canonicalToken721.ownerOf(1), Bob);
    }

    function test_721Vault_bridge_back_but_original_owner_cannot_claim_it_anymore_if_sold_721(
    )
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
            name: "TT"
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
            chainId,
            0
        );

        // Query canonicalToBridged
        address deployedContract = destChainErc721Vault.canonicalToBridged(
            chainId, address(canonicalToken721)
        );

        // Alice bridged over tokenId 1
        assertEq(ERC721(deployedContract).ownerOf(1), Alice);

        // Transfer the asset to Bob, and Bob can receive it back on canonical
        // chain
        vm.prank(Alice, Alice);
        ERC721(deployedContract).transferFrom(Alice, Bob, 1);

        assertEq(ERC721(deployedContract).ownerOf(1), Bob);

        vm.prank(Bob, Bob);
        ERC721(deployedContract).approve(address(destChainErc721Vault), 1);

        // Alice puts together a malicious bridging back message
        sendOpts = BaseNFTVault.BridgeTransferOp(
            chainId,
            Alice,
            address(deployedContract),
            tokenIds,
            amounts,
            140_000,
            140_000,
            Bob,
            ""
        );

        vm.prank(Alice, Alice);
        vm.expectRevert(BridgedERC721.BRIDGED_TOKEN_INVALID_BURN.selector);
        destChainErc721Vault.sendToken{ value: 140_000 }(sendOpts);
    }

    function test_721Vault_upgrade_bridged_tokens_721() public {
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
            name: "TT"
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
            chainId,
            0
        );

        // Query canonicalToBridged
        address deployedContract = destChainErc721Vault.canonicalToBridged(
            chainId, address(canonicalToken721)
        );

        try UpdatedBridgedERC721(deployedContract).helloWorld() {
            fail();
        } catch {
            //It should not yet support this function call
        }

        // Upgrade the implementation of that contract
        // so that it supports now the 'helloWorld' call
        UpdatedBridgedERC721 newBridgedContract = new UpdatedBridgedERC721();
        vm.prank(Amelia, Amelia);
        TransparentUpgradeableProxy(payable(deployedContract)).upgradeTo(
            address(newBridgedContract)
        );

        try UpdatedBridgedERC721(deployedContract).helloWorld() {
            //It should support now this function call
        } catch {
            fail();
        }
    }
}
