// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "../TaikoTest.sol";

contract TestTokenERC1155 is ERC1155 {
    constructor(string memory baseURI) ERC1155(baseURI) { }

    function mint(uint256 tokenId, uint256 amount) public {
        _mint(msg.sender, tokenId, amount, "");
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
        uint64 srcChainId;
    }

    BridgeContext ctx;

    constructor(ERC1155Vault _srcVault) {
        destERC1155Vault = _srcVault;
    }

    function setERC1155Vault(address addr) public {
        destERC1155Vault = ERC1155Vault(addr);
    }

    function sendMessage(IBridge.Message memory message)
        external
        payable
        returns (bytes32 msgHash, IBridge.Message memory _message)
    {
        // Dummy return value
        return (keccak256(abi.encode(message.id)), _message);
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
        uint64 srcChainId,
        uint256 mockLibInvokeMsgValue
    )
        public
    {
        ctx.sender = srcChainERC1155Vault;
        ctx.msgHash = msgHash;
        ctx.srcChainId = srcChainId;

        // We need this in order to 'mock' the LibBridgeInvoke's
        //  (success,retVal) =
        //     message.to.call{ value: message.value, gas: gasLimit
        // }(message.data);
        // The problem (with foundry) is that this way it is not able to deploy
        // a contract
        // most probably due to some deployment address nonce issue. (Seems a
        // known issue).
        destERC1155Vault.onMessageInvocation{ value: mockLibInvokeMsgValue }(
            abi.encode(ctoken, from, to, tokenIds, amounts)
        );

        ctx.sender = address(0);
        ctx.msgHash = bytes32(0);
        ctx.srcChainId = 0;
    }
}

contract UpdatedBridgedERC1155 is BridgedERC1155 {
    function helloWorld() public pure returns (string memory) {
        return "helloworld";
    }
}

contract ERC1155VaultTest is TaikoTest {
    uint32 private constant GAS_LIMIT = 2_000_000;

    TestTokenERC1155 ctoken1155;
    SignalService signalService;
    Bridge bridge;
    ERC1155Vault srcVault;

    SignalService destSignalService;
    PrankDestBridge destBridge;
    ERC1155Vault destVault;

    function prepareContractsOnSourceChain() internal override {
        ctoken1155 = new TestTokenERC1155("http://example.host.com/");

        signalService = deploySignalService(address(new SignalServiceNoProofCheck()));
        bridge = deployBridge(address(new Bridge()));
        srcVault = deployERC1155Vault();

        vm.deal(address(bridge), 100 ether);

        register("bridged_erc1155", address(new BridgedERC1155()));
    }

    function prepareContractsOnDestinationChain() internal override {
        destVault = deployERC1155Vault();
        destBridge = new PrankDestBridge(destVault);
        destSignalService = deploySignalService(address(new SignalServiceNoProofCheck()));

        vm.deal(address(destBridge), 100 ether);

        register("bridge", address(destBridge));
        register("bridged_erc1155", address(new BridgedERC1155()));
    }

    function setUp() public override {
        super.setUp();

        vm.deal(Alice, 100 ether);
        vm.deal(Bob, 100 ether);

        vm.startPrank(Alice);
        ctoken1155.mint(1, 10);
        ctoken1155.mint(2, 10);
        vm.stopPrank();
    }

    function test_1155Vault_sendToken_1155() public {
        vm.prank(Alice);
        ctoken1155.setApprovalForAll(address(srcVault), true);

        assertEq(ctoken1155.balanceOf(Alice, 1), 10);
        assertEq(ctoken1155.balanceOf(address(srcVault), 1), 0);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 2;

        BaseNFTVault.BridgeTransferOp memory sendOpts = BaseNFTVault.BridgeTransferOp(
            destChainId,
            address(0),
            Alice,
            GAS_LIMIT,
            address(ctoken1155),
            GAS_LIMIT,
            tokenIds,
            amounts
        );
        vm.prank(Alice);
        srcVault.sendToken{ value: GAS_LIMIT }(sendOpts);

        assertEq(ctoken1155.balanceOf(Alice, 1), 8);
        assertEq(ctoken1155.balanceOf(address(srcVault), 1), 2);
    }

    function test_1155Vault_sendToken_with_invalid_token_address_1155() public {
        vm.prank(Alice);
        ctoken1155.setApprovalForAll(address(srcVault), true);

        assertEq(ctoken1155.balanceOf(Alice, 1), 10);
        assertEq(ctoken1155.balanceOf(address(srcVault), 1), 0);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 2;

        BaseNFTVault.BridgeTransferOp memory sendOpts = BaseNFTVault.BridgeTransferOp(
            destChainId, address(0), Alice, GAS_LIMIT, address(0), GAS_LIMIT, tokenIds, amounts
        );
        vm.prank(Alice);
        vm.expectRevert(BaseNFTVault.VAULT_INVALID_TOKEN.selector);
        srcVault.sendToken{ value: GAS_LIMIT }(sendOpts);
    }

    function test_1155Vault_sendToken_with_0_tokens_1155() public {
        vm.prank(Alice);
        ctoken1155.setApprovalForAll(address(srcVault), true);

        assertEq(ctoken1155.balanceOf(Alice, 1), 10);
        assertEq(ctoken1155.balanceOf(address(srcVault), 1), 0);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 0;

        BaseNFTVault.BridgeTransferOp memory sendOpts = BaseNFTVault.BridgeTransferOp(
            destChainId,
            address(0),
            Alice,
            GAS_LIMIT,
            address(ctoken1155),
            GAS_LIMIT,
            tokenIds,
            amounts
        );
        vm.prank(Alice);
        vm.expectRevert(BaseNFTVault.VAULT_INVALID_AMOUNT.selector);
        srcVault.sendToken{ value: GAS_LIMIT }(sendOpts);
    }

    function test_1155Vault_receiveTokens_from_newly_deployed_bridged_contract_on_destination_chain_1155(
    )
        public
    {
        vm.prank(Alice);
        ctoken1155.setApprovalForAll(address(srcVault), true);

        assertEq(ctoken1155.balanceOf(Alice, 1), 10);
        assertEq(ctoken1155.balanceOf(address(srcVault), 1), 0);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 2;

        BaseNFTVault.BridgeTransferOp memory sendOpts = BaseNFTVault.BridgeTransferOp(
            destChainId,
            address(0),
            Alice,
            GAS_LIMIT,
            address(ctoken1155),
            GAS_LIMIT,
            tokenIds,
            amounts
        );
        vm.prank(Alice);
        srcVault.sendToken{ value: GAS_LIMIT }(sendOpts);

        assertEq(ctoken1155.balanceOf(Alice, 1), 8);
        assertEq(ctoken1155.balanceOf(address(srcVault), 1), 2);

        amounts[0] = 2;
        BaseNFTVault.CanonicalNFT memory ctoken = BaseNFTVault.CanonicalNFT({
            chainId: 31_337,
            addr: address(ctoken1155),
            symbol: "",
            name: ""
        });

        vm.chainId(destChainId);

        destBridge.sendReceiveERC1155ToERC1155Vault(
            ctoken, Alice, Alice, tokenIds, amounts, bytes32(0), address(srcVault), srcChainId, 0
        );

        // Query canonicalToBridged
        address deployedContract = destVault.canonicalToBridged(srcChainId, address(ctoken1155));

        // Alice bridged over 2 items
        assertEq(ERC1155(deployedContract).balanceOf(Alice, 1), 2);
    }

    function test_1155Vault_receiveTokens_but_mint_not_deploy_if_bridged_second_time_1155()
        public
    {
        vm.prank(Alice);
        ctoken1155.setApprovalForAll(address(srcVault), true);

        assertEq(ctoken1155.balanceOf(Alice, 1), 10);
        assertEq(ctoken1155.balanceOf(address(srcVault), 1), 0);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 2;

        BaseNFTVault.BridgeTransferOp memory sendOpts = BaseNFTVault.BridgeTransferOp(
            destChainId,
            address(0),
            Alice,
            GAS_LIMIT,
            address(ctoken1155),
            GAS_LIMIT,
            tokenIds,
            amounts
        );
        vm.prank(Alice);
        srcVault.sendToken{ value: GAS_LIMIT }(sendOpts);

        assertEq(ctoken1155.balanceOf(Alice, 1), 8);
        assertEq(ctoken1155.balanceOf(address(srcVault), 1), 2);

        BaseNFTVault.CanonicalNFT memory ctoken = BaseNFTVault.CanonicalNFT({
            chainId: 31_337,
            addr: address(ctoken1155),
            symbol: "",
            name: ""
        });

        vm.chainId(destChainId);

        destBridge.sendReceiveERC1155ToERC1155Vault(
            ctoken, Alice, Alice, tokenIds, amounts, bytes32(0), address(srcVault), srcChainId, 0
        );

        // Query canonicalToBridged
        address deployedContract = destVault.canonicalToBridged(srcChainId, address(ctoken1155));

        // Alice bridged over 2 items
        assertEq(ERC1155(deployedContract).balanceOf(Alice, 1), 2);

        // Change back to 'L1'
        vm.chainId(srcChainId);

        tokenIds[0] = 1;
        amounts[0] = 1;

        sendOpts = BaseNFTVault.BridgeTransferOp(
            destChainId,
            address(0),
            Alice,
            GAS_LIMIT,
            address(ctoken1155),
            GAS_LIMIT,
            tokenIds,
            amounts
        );
        vm.prank(Alice);
        srcVault.sendToken{ value: GAS_LIMIT }(sendOpts);

        assertEq(ctoken1155.balanceOf(Alice, 1), 7);
        assertEq(ctoken1155.balanceOf(address(srcVault), 1), 3);

        vm.chainId(destChainId);

        destBridge.sendReceiveERC1155ToERC1155Vault(
            ctoken, Alice, Alice, tokenIds, amounts, bytes32(0), address(srcVault), srcChainId, 0
        );

        // Query canonicalToBridged
        address bridgedContract = destVault.canonicalToBridged(srcChainId, address(ctoken1155));

        assertEq(bridgedContract, deployedContract);
    }

    function test_1155Vault_receiveTokens_erc1155_with_ether_to_dave() public {
        vm.prank(Alice);
        ctoken1155.setApprovalForAll(address(srcVault), true);

        assertEq(ctoken1155.balanceOf(Alice, 1), 10);
        assertEq(ctoken1155.balanceOf(address(srcVault), 1), 0);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 2;

        uint256 etherValue = 0.1 ether;

        BaseNFTVault.BridgeTransferOp memory sendOpts = BaseNFTVault.BridgeTransferOp(
            destChainId,
            address(0),
            David,
            GAS_LIMIT,
            address(ctoken1155),
            GAS_LIMIT,
            tokenIds,
            amounts
        );
        vm.prank(Alice);
        srcVault.sendToken{ value: etherValue }(sendOpts);

        assertEq(ctoken1155.balanceOf(Alice, 1), 8);
        assertEq(ctoken1155.balanceOf(address(srcVault), 1), 2);

        amounts[0] = 2;
        BaseNFTVault.CanonicalNFT memory ctoken = BaseNFTVault.CanonicalNFT({
            chainId: 31_337,
            addr: address(ctoken1155),
            symbol: "",
            name: ""
        });

        vm.chainId(destChainId);

        destBridge.sendReceiveERC1155ToERC1155Vault(
            ctoken,
            Alice,
            David,
            tokenIds,
            amounts,
            bytes32(0),
            address(srcVault),
            srcChainId,
            etherValue
        );

        // Query canonicalToBridged
        address deployedContract = destVault.canonicalToBridged(srcChainId, address(ctoken1155));

        // Alice bridged over 2 items and etherValue to David
        assertEq(ERC1155(deployedContract).balanceOf(David, 1), 2);
        assertEq(David.balance, etherValue);
    }

    function test_1155Vault_onMessageRecalled_1155() public {
        vm.prank(Alice);
        ctoken1155.setApprovalForAll(address(srcVault), true);

        assertEq(ctoken1155.balanceOf(Alice, 1), 10);
        assertEq(ctoken1155.balanceOf(address(srcVault), 1), 0);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 2;

        BaseNFTVault.BridgeTransferOp memory sendOpts = BaseNFTVault.BridgeTransferOp(
            destChainId,
            address(0),
            Alice,
            GAS_LIMIT,
            address(ctoken1155),
            GAS_LIMIT,
            tokenIds,
            amounts
        );

        vm.prank(Alice);
        IBridge.Message memory message = srcVault.sendToken{ value: GAS_LIMIT }(sendOpts);

        assertEq(ctoken1155.balanceOf(Alice, 1), 8);
        assertEq(ctoken1155.balanceOf(address(srcVault), 1), 2);

        bridge.recallMessage(message, bytes(""));

        // // Alice got back her NFTs, and vault has 0
        assertEq(ctoken1155.balanceOf(Alice, 1), 10);
        assertEq(ctoken1155.balanceOf(address(srcVault), 1), 0);
    }

    function test_1155Vault_receiveTokens_multiple_1155() public {
        vm.prank(Alice);
        ctoken1155.setApprovalForAll(address(srcVault), true);

        assertEq(ctoken1155.balanceOf(Alice, 1), 10);
        assertEq(ctoken1155.balanceOf(address(srcVault), 1), 0);

        assertEq(ctoken1155.balanceOf(Alice, 2), 10);
        assertEq(ctoken1155.balanceOf(address(srcVault), 2), 0);

        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 1;
        tokenIds[1] = 2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 2;
        amounts[1] = 5;

        BaseNFTVault.BridgeTransferOp memory sendOpts = BaseNFTVault.BridgeTransferOp(
            destChainId,
            address(0),
            Alice,
            GAS_LIMIT,
            address(ctoken1155),
            GAS_LIMIT,
            tokenIds,
            amounts
        );
        vm.prank(Alice);
        srcVault.sendToken{ value: GAS_LIMIT }(sendOpts);

        assertEq(ctoken1155.balanceOf(Alice, 1), 8);
        assertEq(ctoken1155.balanceOf(address(srcVault), 1), 2);

        assertEq(ctoken1155.balanceOf(Alice, 2), 5);
        assertEq(ctoken1155.balanceOf(address(srcVault), 2), 5);

        BaseNFTVault.CanonicalNFT memory ctoken = BaseNFTVault.CanonicalNFT({
            chainId: 31_337,
            addr: address(ctoken1155),
            symbol: "",
            name: ""
        });

        vm.chainId(destChainId);

        destBridge.sendReceiveERC1155ToERC1155Vault(
            ctoken, Alice, Alice, tokenIds, amounts, bytes32(0), address(srcVault), srcChainId, 0
        );

        // Query canonicalToBridged
        address deployedContract = destVault.canonicalToBridged(srcChainId, address(ctoken1155));

        // Alice bridged over 2 items
        assertEq(ERC1155(deployedContract).balanceOf(Alice, 1), 2);
        assertEq(ERC1155(deployedContract).balanceOf(Alice, 2), 5);
    }

    function test_1155Vault_bridge_back_but_owner_is_different_now_1155() public {
        vm.prank(Alice);
        ctoken1155.setApprovalForAll(address(srcVault), true);

        assertEq(ctoken1155.balanceOf(Alice, 1), 10);
        assertEq(ctoken1155.balanceOf(address(srcVault), 1), 0);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;

        BaseNFTVault.BridgeTransferOp memory sendOpts = BaseNFTVault.BridgeTransferOp(
            destChainId,
            address(0),
            Alice,
            GAS_LIMIT,
            address(ctoken1155),
            GAS_LIMIT,
            tokenIds,
            amounts
        );
        vm.prank(Alice);
        srcVault.sendToken{ value: GAS_LIMIT }(sendOpts);

        assertEq(ctoken1155.balanceOf(address(srcVault), 1), 1);

        // This canonicalToken is basically need to be exact same as the
        // sendToken() puts together
        // - here is just mocking putting it together.
        BaseNFTVault.CanonicalNFT memory canonicalToken = BaseNFTVault.CanonicalNFT({
            chainId: 31_337,
            addr: address(ctoken1155),
            symbol: "TT",
            name: "TT"
        });

        uint64 chainId = uint64(block.chainid);
        vm.chainId(destChainId);

        destBridge.sendReceiveERC1155ToERC1155Vault(
            canonicalToken,
            Alice,
            Alice,
            tokenIds,
            amounts,
            bytes32(0),
            address(srcVault),
            chainId,
            0
        );
        // Query canonicalToBridged
        address deployedContract = destVault.canonicalToBridged(chainId, address(ctoken1155));

        // Alice bridged over 1 from tokenId 1
        assertEq(ERC1155(deployedContract).balanceOf(Alice, 1), 1);

        // Transfer the asset to Bob, and Bob can receive it back on canonical
        // chain
        vm.prank(Alice);
        ERC1155(deployedContract).safeTransferFrom(Alice, Bob, 1, 1, "");

        assertEq(ERC1155(deployedContract).balanceOf(Bob, 1), 1);
        assertEq(ERC1155(deployedContract).balanceOf(Alice, 1), 0);

        vm.prank(Bob);
        ERC1155(deployedContract).setApprovalForAll(address(destVault), true);

        sendOpts = BaseNFTVault.BridgeTransferOp(
            chainId,
            address(0),
            Bob,
            GAS_LIMIT,
            address(deployedContract),
            GAS_LIMIT,
            tokenIds,
            amounts
        );

        vm.prank(Bob);
        destVault.sendToken{ value: GAS_LIMIT }(sendOpts);

        vm.chainId(chainId);

        assertEq(ctoken1155.balanceOf(address(srcVault), 1), 1);

        destBridge.setERC1155Vault(address(srcVault));

        vm.prank(deployer);
        resolver.setAddress(block.chainid, "bridge", address(destBridge));

        destBridge.sendReceiveERC1155ToERC1155Vault(
            canonicalToken, Bob, Bob, tokenIds, amounts, bytes32(0), address(srcVault), chainId, 0
        );

        assertEq(ctoken1155.balanceOf(Bob, 1), 1);
    }

    function test_1155Vault_bridge_back_but_original_owner_cannot_claim_it_anymore_if_sold_1155()
        public
    {
        vm.prank(Alice);
        ctoken1155.setApprovalForAll(address(srcVault), true);

        assertEq(ctoken1155.balanceOf(Alice, 1), 10);
        assertEq(ctoken1155.balanceOf(address(srcVault), 1), 0);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;

        BaseNFTVault.BridgeTransferOp memory sendOpts = BaseNFTVault.BridgeTransferOp(
            destChainId,
            address(0),
            Alice,
            GAS_LIMIT,
            address(ctoken1155),
            GAS_LIMIT,
            tokenIds,
            amounts
        );
        vm.prank(Alice);
        srcVault.sendToken{ value: GAS_LIMIT }(sendOpts);

        assertEq(ctoken1155.balanceOf(address(srcVault), 1), 1);

        // This canonicalToken is basically need to be exact same as the
        // sendToken() puts together
        // - here is just mocking putting it together.
        BaseNFTVault.CanonicalNFT memory canonicalToken = BaseNFTVault.CanonicalNFT({
            chainId: 31_337,
            addr: address(ctoken1155),
            symbol: "TT",
            name: "TT"
        });

        uint64 chainId = uint64(block.chainid);
        vm.chainId(destChainId);

        destBridge.sendReceiveERC1155ToERC1155Vault(
            canonicalToken,
            Alice,
            Alice,
            tokenIds,
            amounts,
            bytes32(0),
            address(srcVault),
            chainId,
            0
        );

        // Query canonicalToBridged
        address deployedContract = destVault.canonicalToBridged(chainId, address(ctoken1155));
        // Alice bridged over 1 from tokenId 1
        assertEq(ERC1155(deployedContract).balanceOf(Alice, 1), 1);

        // Transfer the asset to Bob, and Bob can receive it back on canonical
        // chain
        vm.prank(Alice);
        ERC1155(deployedContract).safeTransferFrom(Alice, Bob, 1, 1, "");

        assertEq(ERC1155(deployedContract).balanceOf(Bob, 1), 1);
        assertEq(ERC1155(deployedContract).balanceOf(Alice, 1), 0);

        vm.prank(Bob);
        ERC1155(deployedContract).setApprovalForAll(address(destVault), true);

        sendOpts = BaseNFTVault.BridgeTransferOp(
            chainId,
            address(0),
            Alice,
            GAS_LIMIT,
            address(deployedContract),
            GAS_LIMIT,
            tokenIds,
            amounts
        );

        vm.prank(Alice);
        vm.expectRevert("ERC1155: caller is not token owner or approved");
        destVault.sendToken{ value: GAS_LIMIT }(sendOpts);
    }

    function test_1155Vault_upgrade_bridged_tokens_1155() public {
        vm.prank(Alice);
        ctoken1155.setApprovalForAll(address(srcVault), true);

        assertEq(ctoken1155.balanceOf(Alice, 1), 10);
        assertEq(ctoken1155.balanceOf(address(srcVault), 1), 0);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 2;

        BaseNFTVault.BridgeTransferOp memory sendOpts = BaseNFTVault.BridgeTransferOp(
            destChainId,
            address(0),
            Alice,
            GAS_LIMIT,
            address(ctoken1155),
            GAS_LIMIT,
            tokenIds,
            amounts
        );
        vm.prank(Alice);
        srcVault.sendToken{ value: GAS_LIMIT }(sendOpts);

        assertEq(ctoken1155.balanceOf(Alice, 1), 8);
        assertEq(ctoken1155.balanceOf(address(srcVault), 1), 2);

        BaseNFTVault.CanonicalNFT memory ctoken = BaseNFTVault.CanonicalNFT({
            chainId: 31_337,
            addr: address(ctoken1155),
            symbol: "",
            name: ""
        });

        vm.chainId(destChainId);

        destBridge.sendReceiveERC1155ToERC1155Vault(
            ctoken, Alice, Alice, tokenIds, amounts, bytes32(0), address(srcVault), srcChainId, 0
        );

        // Query canonicalToBridged
        address deployedContract = destVault.canonicalToBridged(srcChainId, address(ctoken1155));

        try UpdatedBridgedERC1155(deployedContract).helloWorld() {
            fail();
        } catch { }

        // Upgrade the implementation of that contract
        // so that it supports now the 'helloWorld' call
        UpdatedBridgedERC1155 newBridgedContract = new UpdatedBridgedERC1155();
        vm.prank(deployer);
        BridgedERC1155(payable(deployedContract)).upgradeTo(address(newBridgedContract));

        try UpdatedBridgedERC1155(deployedContract).helloWorld() { }
        catch {
            fail();
        }
    }

    function test_1155Vault_shall_not_be_able_to_burn_arbitrarily() public {
        vm.prank(Alice);
        ctoken1155.setApprovalForAll(address(srcVault), true);

        assertEq(ctoken1155.balanceOf(Alice, 1), 10);
        assertEq(ctoken1155.balanceOf(address(srcVault), 1), 0);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;

        BaseNFTVault.BridgeTransferOp memory sendOpts = BaseNFTVault.BridgeTransferOp(
            destChainId,
            address(0),
            Alice,
            GAS_LIMIT,
            address(ctoken1155),
            GAS_LIMIT,
            tokenIds,
            amounts
        );
        vm.prank(Alice);
        srcVault.sendToken{ value: GAS_LIMIT }(sendOpts);

        assertEq(ctoken1155.balanceOf(address(srcVault), 1), 1);

        // This canonicalToken is basically need to be exact same as the
        // sendToken() puts together
        // - here is just mocking putting it together.
        BaseNFTVault.CanonicalNFT memory canonicalToken = BaseNFTVault.CanonicalNFT({
            chainId: 31_337,
            addr: address(ctoken1155),
            symbol: "TT",
            name: "TT"
        });

        uint64 chainId = uint64(block.chainid);
        vm.chainId(destChainId);

        destBridge.sendReceiveERC1155ToERC1155Vault(
            canonicalToken,
            Alice,
            Alice,
            tokenIds,
            amounts,
            bytes32(0),
            address(srcVault),
            chainId,
            0
        );

        // Query canonicalToBridged
        address deployedContract = destVault.canonicalToBridged(chainId, address(ctoken1155));
        // Alice bridged over 1 from tokenId 1
        assertEq(ERC1155(deployedContract).balanceOf(Alice, 1), 1);

        sendOpts = BaseNFTVault.BridgeTransferOp(
            chainId,
            address(0),
            Alice,
            GAS_LIMIT,
            address(deployedContract),
            GAS_LIMIT,
            tokenIds,
            amounts
        );

        // Alice hasn't approved the vault yet!
        vm.prank(Alice);
        vm.expectRevert("ERC1155: caller is not token owner or approved");
        destVault.sendToken{ value: GAS_LIMIT }(sendOpts);

        // Also Vault cannot burn tokens it does not own (even if the priv key compromised)
        vm.prank(address(destVault), address(destVault));
        vm.expectRevert("ERC1155: burn amount exceeds balance");
        BridgedERC1155(deployedContract).burn(1, 20);

        // After setApprovalForAll() ERC1155Vault can transfer and burn
        vm.prank(Alice);
        ERC1155(deployedContract).setApprovalForAll(address(destVault), true);
        vm.prank(Alice);
        destVault.sendToken{ value: GAS_LIMIT }(sendOpts);
    }
}
