// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./ERC721Vault.h.sol";

contract ERC721VaultTest is TaikoTest {
    uint32 private constant GAS_LIMIT = 2_000_000;

    ERC721Vault vault;
    Bridge bridge;

    ERC721Vault destVault;
    PrankDestBridge destBridge;

    TestTokenERC721 canonicalToken721;

    function setUpOnEthereum() internal override {
        deploySignalService(address(new SignalServiceNoProofCheck()));
        bridge = deployBridge(address(new Bridge()));
        vault = deployERC721Vault();

        register("bridged_erc721", address(new BridgedERC721()));

        vm.deal(Alice, 100 ether);
        vm.deal(Bob, 100 ether);
    }

    function setUpOnTaiko() internal override {
        deploySignalService(address(new SignalServiceNoProofCheck()));
        destVault = deployERC721Vault();
        destBridge = new PrankDestBridge(destVault);

        register("bridge", address(destBridge));
        register("bridged_erc721", address(new BridgedERC721()));

        vm.deal(address(destBridge), 100 ether);
    }

    function setUp() public override {
        super.setUp();

        vm.startPrank(Alice);
        canonicalToken721 = new TestTokenERC721("http://example.host.com/");
        canonicalToken721.mint(10);
        vm.stopPrank();
    }

    function test_721Vault_sendToken_721() public {
        vm.prank(Alice);
        canonicalToken721.approve(address(vault), 1);

        assertEq(canonicalToken721.ownerOf(1), Alice);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 0;

        BaseNFTVault.BridgeTransferOp memory sendOpts = BaseNFTVault.BridgeTransferOp(
            taikoChainId,
            address(0),
            Alice,
            GAS_LIMIT,
            address(canonicalToken721),
            GAS_LIMIT,
            tokenIds,
            amounts // With ERC721 still need to specify 1
        );
        vm.prank(Alice);
        vault.sendToken{ value: GAS_LIMIT }(sendOpts);

        assertEq(ERC721(canonicalToken721).ownerOf(1), address(vault));
    }

    function test_721Vault_sendToken_with_invalid_token_address() public {
        vm.prank(Alice);
        canonicalToken721.approve(address(vault), 1);

        assertEq(canonicalToken721.ownerOf(1), Alice);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 0;

        BaseNFTVault.BridgeTransferOp memory sendOpts = BaseNFTVault.BridgeTransferOp(
            taikoChainId, address(0), Alice, GAS_LIMIT, address(0), GAS_LIMIT, tokenIds, amounts
        );
        vm.prank(Alice);
        vm.expectRevert(BaseNFTVault.VAULT_INVALID_TOKEN.selector);
        vault.sendToken{ value: GAS_LIMIT }(sendOpts);
    }

    function test_721Vault_sendToken_with_1_tokens_but_erc721_amount_1_invalid() public {
        vm.prank(Alice);
        canonicalToken721.approve(address(vault), 1);

        assertEq(canonicalToken721.ownerOf(1), Alice);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;
        BaseNFTVault.BridgeTransferOp memory sendOpts = BaseNFTVault.BridgeTransferOp(
            taikoChainId,
            address(0),
            Alice,
            GAS_LIMIT,
            address(canonicalToken721),
            GAS_LIMIT,
            tokenIds,
            amounts
        );
        vm.prank(Alice);
        vm.expectRevert(BaseNFTVault.VAULT_INVALID_AMOUNT.selector);
        vault.sendToken{ value: GAS_LIMIT }(sendOpts);
    }

    function test_721Vault_receiveTokens_from_newly_deployed_bridged_contract_on_destination_chain_721(
    )
        public
    {
        vm.prank(Alice);
        canonicalToken721.approve(address(vault), 1);

        assertEq(canonicalToken721.ownerOf(1), Alice);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 0;

        BaseNFTVault.BridgeTransferOp memory sendOpts = BaseNFTVault.BridgeTransferOp(
            taikoChainId,
            address(0),
            Alice,
            GAS_LIMIT,
            address(canonicalToken721),
            GAS_LIMIT,
            tokenIds,
            amounts
        );
        vm.prank(Alice);
        vault.sendToken{ value: GAS_LIMIT }(sendOpts);

        assertEq(canonicalToken721.ownerOf(1), address(vault));

        BaseNFTVault.CanonicalNFT memory canonicalToken = BaseNFTVault.CanonicalNFT({
            chainId: ethereumChainId,
            addr: address(canonicalToken721),
            symbol: "TT",
            name: "TT"
        });


        vm.chainId(taikoChainId);

        destBridge.sendReceiveERC721ToERC721Vault(
            canonicalToken, Alice, Alice, tokenIds, bytes32(0), address(vault), ethereumChainId, 0
        );

        // Query canonicalToBridged
        address deployedContract = destVault.canonicalToBridged(ethereumChainId, address(canonicalToken721));

        // Alice bridged over tokenId 1
        assertEq(ERC721(deployedContract).ownerOf(1), Alice);
    }

    function test_721Vault_receiveTokens_but_mint_not_deploy_if_bridged_second_time_721() public {
        vm.prank(Alice);
        canonicalToken721.approve(address(vault), 1);
        vm.prank(Alice);
        canonicalToken721.approve(address(vault), 2);

        assertEq(canonicalToken721.ownerOf(1), Alice);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 0;

        BaseNFTVault.BridgeTransferOp memory sendOpts = BaseNFTVault.BridgeTransferOp(
            taikoChainId,
            address(0),
            Alice,
            GAS_LIMIT,
            address(canonicalToken721),
            GAS_LIMIT,
            tokenIds,
            amounts
        );
        vm.prank(Alice);
        vault.sendToken{ value: GAS_LIMIT }(sendOpts);

        assertEq(canonicalToken721.ownerOf(1), address(vault));

        // This canonicalToken is basically need to be exact same as the
        // sendToken() puts together
        // - here is just mocking putting it together.
        BaseNFTVault.CanonicalNFT memory canonicalToken = BaseNFTVault.CanonicalNFT({
            chainId: ethereumChainId,
            addr: address(canonicalToken721),
            symbol: "TT",
            name: "TT"
        });


        vm.chainId(taikoChainId);

        destBridge.sendReceiveERC721ToERC721Vault(
            canonicalToken, Alice, Alice, tokenIds, bytes32(0), address(vault), ethereumChainId, 0
        );

        // Query canonicalToBridged
        address deployedContract = destVault.canonicalToBridged(ethereumChainId, address(canonicalToken721));

        // Alice bridged over tokenId 1
        assertEq(ERC721(deployedContract).ownerOf(1), Alice);

        // Change back to 'L1'
        vm.chainId(ethereumChainId);

        tokenIds[0] = 2;

        amounts[0] = 0;

        sendOpts = BaseNFTVault.BridgeTransferOp(
            taikoChainId,
            address(0),
            Alice,
            GAS_LIMIT,
            address(canonicalToken721),
            GAS_LIMIT,
            tokenIds,
            amounts
        );
        vm.prank(Alice);
        vault.sendToken{ value: GAS_LIMIT }(sendOpts);

        assertEq(canonicalToken721.ownerOf(2), address(vault));

        vm.chainId(taikoChainId);

        destBridge.sendReceiveERC721ToERC721Vault(
            canonicalToken, Alice, Alice, tokenIds, bytes32(0), address(vault), ethereumChainId, 0
        );

        // Query canonicalToBridged
        address bridgedContract = destVault.canonicalToBridged(ethereumChainId, address(canonicalToken721));

        assertEq(bridgedContract, deployedContract);
    }

    function test_721Vault_receiveTokens_erc721_with_ether_to_dave() public {
        vm.prank(Alice);
        canonicalToken721.approve(address(vault), 1);

        assertEq(canonicalToken721.ownerOf(1), Alice);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 0;

        uint256 etherValue = 0.1 ether;
        BaseNFTVault.BridgeTransferOp memory sendOpts = BaseNFTVault.BridgeTransferOp(
            taikoChainId,
            address(0),
            David,
            GAS_LIMIT,
            address(canonicalToken721),
            GAS_LIMIT,
            tokenIds,
            amounts
        );
        vm.prank(Alice);
        vault.sendToken{ value: etherValue }(sendOpts);

        assertEq(canonicalToken721.ownerOf(1), address(vault));

        BaseNFTVault.CanonicalNFT memory canonicalToken = BaseNFTVault.CanonicalNFT({
            chainId: ethereumChainId,
            addr: address(canonicalToken721),
            symbol: "TT",
            name: "TT"
        });


        vm.chainId(taikoChainId);

        destBridge.sendReceiveERC721ToERC721Vault(
            canonicalToken, Alice, David, tokenIds, bytes32(0), address(vault), ethereumChainId, etherValue
        );

        // Query canonicalToBridged
        address deployedContract = destVault.canonicalToBridged(ethereumChainId, address(canonicalToken721));

        // Alice bridged over tokenId 1 and etherValue to David
        assertEq(ERC721(deployedContract).ownerOf(1), David);
        assertEq(etherValue, David.balance);
    }

    function test_721Vault_onMessageRecalled_721() public {
        vm.prank(Alice);
        canonicalToken721.approve(address(vault), 1);

        assertEq(canonicalToken721.ownerOf(1), Alice);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 0;

        BaseNFTVault.BridgeTransferOp memory sendOpts = BaseNFTVault.BridgeTransferOp(
            taikoChainId,
            address(0),
            Alice,
            GAS_LIMIT,
            address(canonicalToken721),
            GAS_LIMIT,
            tokenIds,
            amounts
        );

        vm.prank(Alice);
        IBridge.Message memory message = vault.sendToken{ value: GAS_LIMIT }(sendOpts);

        assertEq(canonicalToken721.ownerOf(1), address(vault));

        bridge.recallMessage(message, bytes(""));

        // Alice got back her NFT
        assertEq(canonicalToken721.ownerOf(1), Alice);
    }

    function test_721Vault_receiveTokens_multiple_721() public {
        vm.prank(Alice);
        canonicalToken721.approve(address(vault), 1);
        vm.prank(Alice);
        canonicalToken721.approve(address(vault), 2);

        assertEq(canonicalToken721.ownerOf(1), Alice);
        assertEq(canonicalToken721.ownerOf(2), Alice);

        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 1;
        tokenIds[1] = 2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 0;
        amounts[1] = 0;

        BaseNFTVault.BridgeTransferOp memory sendOpts = BaseNFTVault.BridgeTransferOp(
            taikoChainId,
            address(0),
            Alice,
            GAS_LIMIT,
            address(canonicalToken721),
            GAS_LIMIT,
            tokenIds,
            amounts
        );
        vm.prank(Alice);
        vault.sendToken{ value: GAS_LIMIT }(sendOpts);

        assertEq(canonicalToken721.ownerOf(1), address(vault));
        assertEq(canonicalToken721.ownerOf(2), address(vault));

        BaseNFTVault.CanonicalNFT memory canonicalToken = BaseNFTVault.CanonicalNFT({
            chainId: ethereumChainId,
            addr: address(canonicalToken721),
            symbol: "TT",
            name: "TT"
        });

        vm.chainId(taikoChainId);

        destBridge.sendReceiveERC721ToERC721Vault(
            canonicalToken, Alice, Alice, tokenIds, bytes32(0), address(vault), ethereumChainId, 0
        );

        // Query canonicalToBridged
        address deployedContract =
            destVault.canonicalToBridged(ethereumChainId, address(canonicalToken721));

        // Alice bridged over tokenId 1
        assertEq(ERC721(deployedContract).ownerOf(1), Alice);
        assertEq(ERC721(deployedContract).ownerOf(2), Alice);
    }

    function test_721Vault_bridge_back_but_owner_is_different_now_721() public {
        vm.prank(Alice);
        canonicalToken721.approve(address(vault), 1);
        vm.prank(Alice);
        canonicalToken721.approve(address(vault), 2);

        assertEq(canonicalToken721.ownerOf(1), Alice);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 0;

        BaseNFTVault.BridgeTransferOp memory sendOpts = BaseNFTVault.BridgeTransferOp(
            taikoChainId,
            address(0),
            Alice,
            GAS_LIMIT,
            address(canonicalToken721),
            GAS_LIMIT,
            tokenIds,
            amounts
        );
        vm.prank(Alice);
        vault.sendToken{ value: GAS_LIMIT }(sendOpts);

        assertEq(canonicalToken721.ownerOf(1), address(vault));

        // This canonicalToken is basically need to be exact same as the
        // sendToken() puts together
        // - here is just mocking putting it together.
        BaseNFTVault.CanonicalNFT memory canonicalToken = BaseNFTVault.CanonicalNFT({
            chainId: ethereumChainId,
            addr: address(canonicalToken721),
            symbol: "TT",
            name: "TT"
        });


        vm.chainId(taikoChainId);

        destBridge.sendReceiveERC721ToERC721Vault(
            canonicalToken, Alice, Alice, tokenIds, bytes32(0), address(vault), ethereumChainId, 0
        );

        // Query canonicalToBridged
        address deployedContract = destVault.canonicalToBridged(ethereumChainId, address(canonicalToken721));

        // Alice bridged over tokenId 1
        assertEq(ERC721(deployedContract).ownerOf(1), Alice);

        // Transfer the asset to Bob, and Bob can receive it back on canonical
        // chain
        vm.prank(Alice);
        ERC721(deployedContract).transferFrom(Alice, Bob, 1);

        assertEq(ERC721(deployedContract).ownerOf(1), Bob);

        vm.prank(Bob, Bob);
        ERC721(deployedContract).approve(address(destVault), 1);

        sendOpts = BaseNFTVault.BridgeTransferOp(
            ethereumChainId,
            address(0),
            Bob,
            GAS_LIMIT,
            address(deployedContract),
            GAS_LIMIT,
            tokenIds,
            amounts
        );

        vm.prank(Bob, Bob);
        destVault.sendToken{ value: GAS_LIMIT }(sendOpts);

        vm.chainId(ethereumChainId);

        assertEq(ERC721(canonicalToken721).ownerOf(1), address(vault));

        destBridge.setERC721Vault(address(vault));

        vm.prank(deployer);
        resolver.setAddress(block.chainid, "bridge", address(destBridge));

        destBridge.sendReceiveERC721ToERC721Vault(
            canonicalToken, Bob, Bob, tokenIds, bytes32(0), address(vault), ethereumChainId, 0
        );

        assertEq(canonicalToken721.ownerOf(1), Bob);
    }

    function test_721Vault_bridge_back_but_original_owner_cannot_claim_it_anymore_if_sold_721()
        public
    {
        vm.prank(Alice);
        canonicalToken721.approve(address(vault), 1);
        vm.prank(Alice);
        canonicalToken721.approve(address(vault), 2);

        assertEq(canonicalToken721.ownerOf(1), Alice);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 0;

        BaseNFTVault.BridgeTransferOp memory sendOpts = BaseNFTVault.BridgeTransferOp(
            taikoChainId,
            address(0),
            Alice,
            GAS_LIMIT,
            address(canonicalToken721),
            GAS_LIMIT,
            tokenIds,
            amounts
        );
        vm.prank(Alice);
        vault.sendToken{ value: GAS_LIMIT }(sendOpts);

        assertEq(canonicalToken721.ownerOf(1), address(vault));

        // This canonicalToken is basically need to be exact same as the
        // sendToken() puts together
        // - here is just mocking putting it together.
        BaseNFTVault.CanonicalNFT memory canonicalToken = BaseNFTVault.CanonicalNFT({
            chainId: ethereumChainId,
            addr: address(canonicalToken721),
            symbol: "TT",
            name: "TT"
        });


        vm.chainId(taikoChainId);

        destBridge.sendReceiveERC721ToERC721Vault(
            canonicalToken, Alice, Alice, tokenIds, bytes32(0), address(vault), ethereumChainId, 0
        );

        // Query canonicalToBridged
        address deployedContract = destVault.canonicalToBridged(ethereumChainId, address(canonicalToken721));

        // Alice bridged over tokenId 1
        assertEq(ERC721(deployedContract).ownerOf(1), Alice);

        // Transfer the asset to Bob, and Bob can receive it back on canonical
        // chain
        vm.prank(Alice);
        ERC721(deployedContract).transferFrom(Alice, Bob, 1);

        assertEq(ERC721(deployedContract).ownerOf(1), Bob);

        vm.prank(Bob, Bob);
        ERC721(deployedContract).approve(address(destVault), 1);

        // Alice puts together a malicious bridging back message
        sendOpts = BaseNFTVault.BridgeTransferOp(
            ethereumChainId,
            address(0),
            Alice,
            GAS_LIMIT,
            address(deployedContract),
            GAS_LIMIT,
            tokenIds,
            amounts
        );

        vm.prank(Alice);
        vm.expectRevert("ERC721: transfer from incorrect owner");
        destVault.sendToken{ value: GAS_LIMIT }(sendOpts);
    }

    function test_721Vault_upgrade_bridged_tokens_721() public {
        vm.prank(Alice);
        canonicalToken721.approve(address(vault), 1);
        vm.prank(Alice);
        canonicalToken721.approve(address(vault), 2);

        assertEq(canonicalToken721.ownerOf(1), Alice);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 0;

        BaseNFTVault.BridgeTransferOp memory sendOpts = BaseNFTVault.BridgeTransferOp(
            taikoChainId,
            address(0),
            Alice,
            GAS_LIMIT,
            address(canonicalToken721),
            GAS_LIMIT,
            tokenIds,
            amounts
        );
        vm.prank(Alice);
        vault.sendToken{ value: GAS_LIMIT }(sendOpts);

        assertEq(canonicalToken721.ownerOf(1), address(vault));

        // This canonicalToken is basically need to be exact same as the
        // sendToken() puts together
        // - here is just mocking putting it together.
        BaseNFTVault.CanonicalNFT memory canonicalToken = BaseNFTVault.CanonicalNFT({
            chainId: ethereumChainId,
            addr: address(canonicalToken721),
            symbol: "TT",
            name: "TT"
        });


        vm.chainId(taikoChainId);

        destBridge.sendReceiveERC721ToERC721Vault(
            canonicalToken, Alice, Alice, tokenIds, bytes32(0), address(vault), ethereumChainId, 0
        );

        // Query canonicalToBridged
        address deployedContract = destVault.canonicalToBridged(ethereumChainId, address(canonicalToken721));

        try UpdatedBridgedERC721(deployedContract).helloWorld() {
            fail();
        } catch {
            // It should not yet support this function call
        }

        // Upgrade the implementation of that contract
        // so that it supports now the 'helloWorld' call
        UpdatedBridgedERC721 newBridgedContract = new UpdatedBridgedERC721();
        vm.prank(deployer);
        BridgedERC721(payable(deployedContract)).upgradeTo(address(newBridgedContract));

        try UpdatedBridgedERC721(deployedContract).helloWorld() {
            // It should support now this function call
        } catch {
            fail();
        }
    }

    function test_721Vault_shall_not_be_able_to_burn_arbitrarily() public {
        vm.prank(Alice);
        canonicalToken721.approve(address(vault), 1);
        vm.prank(Alice);
        canonicalToken721.approve(address(vault), 2);

        assertEq(canonicalToken721.ownerOf(1), Alice);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 0;

        BaseNFTVault.BridgeTransferOp memory sendOpts = BaseNFTVault.BridgeTransferOp(
            taikoChainId,
            address(0),
            Alice,
            GAS_LIMIT,
            address(canonicalToken721),
            GAS_LIMIT,
            tokenIds,
            amounts
        );
        vm.prank(Alice);
        vault.sendToken{ value: GAS_LIMIT }(sendOpts);

        assertEq(canonicalToken721.ownerOf(1), address(vault));

        // This canonicalToken is basically need to be exact same as the
        // sendToken() puts together
        // - here is just mocking putting it together.
        BaseNFTVault.CanonicalNFT memory canonicalToken = BaseNFTVault.CanonicalNFT({
            chainId: ethereumChainId,
            addr: address(canonicalToken721),
            symbol: "TT",
            name: "TT"
        });


        vm.chainId(taikoChainId);

        destBridge.sendReceiveERC721ToERC721Vault(
            canonicalToken, Alice, Alice, tokenIds, bytes32(0), address(vault), ethereumChainId, 0
        );

        // Query canonicalToBridged
        address deployedContract = destVault.canonicalToBridged(ethereumChainId, address(canonicalToken721));

        // Alice bridged over tokenId 1
        assertEq(ERC721(deployedContract).ownerOf(1), Alice);

        // Alice tries to bridge back message
        sendOpts = BaseNFTVault.BridgeTransferOp(
            ethereumChainId,
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
        vm.expectRevert("ERC721: caller is not token owner or approved");
        destVault.sendToken{ value: GAS_LIMIT }(sendOpts);

        // Also Vault cannot burn tokens it does not own (even if the priv key compromised)
        vm.prank(address(destVault));
        vm.expectRevert(BridgedERC721.BTOKEN_INVALID_BURN.selector);
        BridgedERC721(deployedContract).burn(1);

        // After approve() ERC721Vault can transfer and burn
        vm.prank(Alice);
        ERC721(deployedContract).approve(address(destVault), 1);
        vm.prank(Alice);
        destVault.sendToken{ value: GAS_LIMIT }(sendOpts);
    }
}
