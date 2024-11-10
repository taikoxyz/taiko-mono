// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./ERC1155Vault.h.sol";

contract ERC1155VaultTest is CommonTest {
    uint32 private constant GAS_LIMIT = 2_000_000;

    // Contracts on Ethereum
    FreeMintERC1155Token private eERC1155Token;
    SignalService private eSignalService;
    Bridge private eBridge;
    ERC1155Vault private eVault;

    // Contracts on Taiko
    SignalService private tSignalService;
    PrankDestBridge private tBridge;
    ERC1155Vault private tVault;

    function setUpOnEthereum() internal override {
        eERC1155Token = new FreeMintERC1155Token("http://example.host.com/");

        eSignalService = deploySignalService(address(new SignalService_WithoutProofVerification()));
        eBridge = deployBridge(address(new Bridge()));
        eVault = deployERC1155Vault();

        register("bridged_erc1155", address(new BridgedERC1155()));

        vm.deal(address(eBridge), 100 ether);
        vm.deal(Alice, 100 ether);
        vm.deal(Bob, 100 ether);
    }

    function setUpOnTaiko() internal override {
        tVault = deployERC1155Vault();
        tBridge = new PrankDestBridge(tVault);
        tSignalService = deploySignalService(address(new SignalService_WithoutProofVerification()));

        register("bridge", address(tBridge));
        register("bridged_erc1155", address(new BridgedERC1155()));

        vm.deal(address(tBridge), 100 ether);
    }

    function setUp() public override {
        super.setUp();

        vm.startPrank(Alice);
        eERC1155Token.mint(1, 10);
        eERC1155Token.mint(2, 10);
        vm.stopPrank();
    }

    function test_1155Vault_sendToken_1155() public {
        vm.prank(Alice);
        eERC1155Token.setApprovalForAll(address(eVault), true);

        assertEq(eERC1155Token.balanceOf(Alice, 1), 10);
        assertEq(eERC1155Token.balanceOf(address(eVault), 1), 0);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 2;

        BaseNFTVault.BridgeTransferOp memory sendOpts = BaseNFTVault.BridgeTransferOp(
            taikoChainId,
            address(0),
            Alice,
            GAS_LIMIT,
            address(eERC1155Token),
            GAS_LIMIT,
            tokenIds,
            amounts
        );
        vm.prank(Alice);
        eVault.sendToken{ value: GAS_LIMIT }(sendOpts);

        assertEq(eERC1155Token.balanceOf(Alice, 1), 8);
        assertEq(eERC1155Token.balanceOf(address(eVault), 1), 2);
    }

    function test_1155Vault_sendToken_with_invalid_token_address_1155() public {
        vm.prank(Alice);
        eERC1155Token.setApprovalForAll(address(eVault), true);

        assertEq(eERC1155Token.balanceOf(Alice, 1), 10);
        assertEq(eERC1155Token.balanceOf(address(eVault), 1), 0);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 2;

        BaseNFTVault.BridgeTransferOp memory sendOpts = BaseNFTVault.BridgeTransferOp(
            taikoChainId, address(0), Alice, GAS_LIMIT, address(0), GAS_LIMIT, tokenIds, amounts
        );
        vm.prank(Alice);
        vm.expectRevert(BaseNFTVault.VAULT_INVALID_TOKEN.selector);
        eVault.sendToken{ value: GAS_LIMIT }(sendOpts);
    }

    function test_1155Vault_sendToken_with_0_tokens_1155() public {
        vm.prank(Alice);
        eERC1155Token.setApprovalForAll(address(eVault), true);

        assertEq(eERC1155Token.balanceOf(Alice, 1), 10);
        assertEq(eERC1155Token.balanceOf(address(eVault), 1), 0);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 0;

        BaseNFTVault.BridgeTransferOp memory sendOpts = BaseNFTVault.BridgeTransferOp(
            taikoChainId,
            address(0),
            Alice,
            GAS_LIMIT,
            address(eERC1155Token),
            GAS_LIMIT,
            tokenIds,
            amounts
        );
        vm.prank(Alice);
        vm.expectRevert(BaseNFTVault.VAULT_INVALID_AMOUNT.selector);
        eVault.sendToken{ value: GAS_LIMIT }(sendOpts);
    }

    function test_1155Vault_receiveTokens_from_newly_deployed_bridged_contract_on_destination_chain_1155(
    )
        public
    {
        vm.prank(Alice);
        eERC1155Token.setApprovalForAll(address(eVault), true);

        assertEq(eERC1155Token.balanceOf(Alice, 1), 10);
        assertEq(eERC1155Token.balanceOf(address(eVault), 1), 0);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 2;

        BaseNFTVault.BridgeTransferOp memory sendOpts = BaseNFTVault.BridgeTransferOp(
            taikoChainId,
            address(0),
            Alice,
            GAS_LIMIT,
            address(eERC1155Token),
            GAS_LIMIT,
            tokenIds,
            amounts
        );
        vm.prank(Alice);
        eVault.sendToken{ value: GAS_LIMIT }(sendOpts);

        assertEq(eERC1155Token.balanceOf(Alice, 1), 8);
        assertEq(eERC1155Token.balanceOf(address(eVault), 1), 2);

        amounts[0] = 2;
        BaseNFTVault.CanonicalNFT memory ctoken = BaseNFTVault.CanonicalNFT({
            chainId: ethereumChainId,
            addr: address(eERC1155Token),
            symbol: "",
            name: ""
        });

        vm.chainId(taikoChainId);

        tBridge.sendReceiveERC1155ToERC1155Vault(
            ctoken, Alice, Alice, tokenIds, amounts, bytes32(0), address(eVault), ethereumChainId, 0
        );

        // Query canonicalToBridged
        address deployedContract =
            tVault.canonicalToBridged(ethereumChainId, address(eERC1155Token));

        // Alice bridged over 2 items
        assertEq(ERC1155(deployedContract).balanceOf(Alice, 1), 2);
    }

    function test_1155Vault_receiveTokens_but_mint_not_deploy_if_bridged_second_time_1155()
        public
    {
        vm.prank(Alice);
        eERC1155Token.setApprovalForAll(address(eVault), true);

        assertEq(eERC1155Token.balanceOf(Alice, 1), 10);
        assertEq(eERC1155Token.balanceOf(address(eVault), 1), 0);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 2;

        BaseNFTVault.BridgeTransferOp memory sendOpts = BaseNFTVault.BridgeTransferOp(
            taikoChainId,
            address(0),
            Alice,
            GAS_LIMIT,
            address(eERC1155Token),
            GAS_LIMIT,
            tokenIds,
            amounts
        );
        vm.prank(Alice);
        eVault.sendToken{ value: GAS_LIMIT }(sendOpts);

        assertEq(eERC1155Token.balanceOf(Alice, 1), 8);
        assertEq(eERC1155Token.balanceOf(address(eVault), 1), 2);

        BaseNFTVault.CanonicalNFT memory ctoken = BaseNFTVault.CanonicalNFT({
            chainId: ethereumChainId,
            addr: address(eERC1155Token),
            symbol: "",
            name: ""
        });

        vm.chainId(taikoChainId);

        tBridge.sendReceiveERC1155ToERC1155Vault(
            ctoken, Alice, Alice, tokenIds, amounts, bytes32(0), address(eVault), ethereumChainId, 0
        );

        // Query canonicalToBridged
        address deployedContract =
            tVault.canonicalToBridged(ethereumChainId, address(eERC1155Token));

        // Alice bridged over 2 items
        assertEq(ERC1155(deployedContract).balanceOf(Alice, 1), 2);

        // Change back to 'L1'
        vm.chainId(ethereumChainId);

        tokenIds[0] = 1;
        amounts[0] = 1;

        sendOpts = BaseNFTVault.BridgeTransferOp(
            taikoChainId,
            address(0),
            Alice,
            GAS_LIMIT,
            address(eERC1155Token),
            GAS_LIMIT,
            tokenIds,
            amounts
        );
        vm.prank(Alice);
        eVault.sendToken{ value: GAS_LIMIT }(sendOpts);

        assertEq(eERC1155Token.balanceOf(Alice, 1), 7);
        assertEq(eERC1155Token.balanceOf(address(eVault), 1), 3);

        vm.chainId(taikoChainId);

        tBridge.sendReceiveERC1155ToERC1155Vault(
            ctoken, Alice, Alice, tokenIds, amounts, bytes32(0), address(eVault), ethereumChainId, 0
        );

        // Query canonicalToBridged
        address bridgedContract =
            tVault.canonicalToBridged(ethereumChainId, address(eERC1155Token));

        assertEq(bridgedContract, deployedContract);
    }

    function test_1155Vault_receiveTokens_erc1155_with_ether_to_dave() public {
        vm.prank(Alice);
        eERC1155Token.setApprovalForAll(address(eVault), true);

        assertEq(eERC1155Token.balanceOf(Alice, 1), 10);
        assertEq(eERC1155Token.balanceOf(address(eVault), 1), 0);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 2;

        uint256 etherValue = 0.1 ether;

        BaseNFTVault.BridgeTransferOp memory sendOpts = BaseNFTVault.BridgeTransferOp(
            taikoChainId,
            address(0),
            David,
            GAS_LIMIT,
            address(eERC1155Token),
            GAS_LIMIT,
            tokenIds,
            amounts
        );
        vm.prank(Alice);
        eVault.sendToken{ value: etherValue }(sendOpts);

        assertEq(eERC1155Token.balanceOf(Alice, 1), 8);
        assertEq(eERC1155Token.balanceOf(address(eVault), 1), 2);

        amounts[0] = 2;
        BaseNFTVault.CanonicalNFT memory ctoken = BaseNFTVault.CanonicalNFT({
            chainId: ethereumChainId,
            addr: address(eERC1155Token),
            symbol: "",
            name: ""
        });

        vm.chainId(taikoChainId);

        tBridge.sendReceiveERC1155ToERC1155Vault(
            ctoken,
            Alice,
            David,
            tokenIds,
            amounts,
            bytes32(0),
            address(eVault),
            ethereumChainId,
            etherValue
        );

        // Query canonicalToBridged
        address deployedContract =
            tVault.canonicalToBridged(ethereumChainId, address(eERC1155Token));

        // Alice bridged over 2 items and etherValue to David
        assertEq(ERC1155(deployedContract).balanceOf(David, 1), 2);
        assertEq(David.balance, etherValue);
    }

    function test_1155Vault_onMessageRecalled_1155() public {
        vm.prank(Alice);
        eERC1155Token.setApprovalForAll(address(eVault), true);

        assertEq(eERC1155Token.balanceOf(Alice, 1), 10);
        assertEq(eERC1155Token.balanceOf(address(eVault), 1), 0);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 2;

        BaseNFTVault.BridgeTransferOp memory sendOpts = BaseNFTVault.BridgeTransferOp(
            taikoChainId,
            address(0),
            Alice,
            GAS_LIMIT,
            address(eERC1155Token),
            GAS_LIMIT,
            tokenIds,
            amounts
        );

        vm.prank(Alice);
        IBridge.Message memory message = eVault.sendToken{ value: GAS_LIMIT }(sendOpts);

        assertEq(eERC1155Token.balanceOf(Alice, 1), 8);
        assertEq(eERC1155Token.balanceOf(address(eVault), 1), 2);

        eBridge.recallMessage(message, bytes(""));

        // // Alice got back her NFTs, and vault has 0
        assertEq(eERC1155Token.balanceOf(Alice, 1), 10);
        assertEq(eERC1155Token.balanceOf(address(eVault), 1), 0);
    }

    function test_1155Vault_receiveTokens_multiple_1155() public {
        vm.prank(Alice);
        eERC1155Token.setApprovalForAll(address(eVault), true);

        assertEq(eERC1155Token.balanceOf(Alice, 1), 10);
        assertEq(eERC1155Token.balanceOf(address(eVault), 1), 0);

        assertEq(eERC1155Token.balanceOf(Alice, 2), 10);
        assertEq(eERC1155Token.balanceOf(address(eVault), 2), 0);

        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 1;
        tokenIds[1] = 2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 2;
        amounts[1] = 5;

        BaseNFTVault.BridgeTransferOp memory sendOpts = BaseNFTVault.BridgeTransferOp(
            taikoChainId,
            address(0),
            Alice,
            GAS_LIMIT,
            address(eERC1155Token),
            GAS_LIMIT,
            tokenIds,
            amounts
        );
        vm.prank(Alice);
        eVault.sendToken{ value: GAS_LIMIT }(sendOpts);

        assertEq(eERC1155Token.balanceOf(Alice, 1), 8);
        assertEq(eERC1155Token.balanceOf(address(eVault), 1), 2);

        assertEq(eERC1155Token.balanceOf(Alice, 2), 5);
        assertEq(eERC1155Token.balanceOf(address(eVault), 2), 5);

        BaseNFTVault.CanonicalNFT memory ctoken = BaseNFTVault.CanonicalNFT({
            chainId: ethereumChainId,
            addr: address(eERC1155Token),
            symbol: "",
            name: ""
        });

        vm.chainId(taikoChainId);

        tBridge.sendReceiveERC1155ToERC1155Vault(
            ctoken, Alice, Alice, tokenIds, amounts, bytes32(0), address(eVault), ethereumChainId, 0
        );

        // Query canonicalToBridged
        address deployedContract =
            tVault.canonicalToBridged(ethereumChainId, address(eERC1155Token));

        // Alice bridged over 2 items
        assertEq(ERC1155(deployedContract).balanceOf(Alice, 1), 2);
        assertEq(ERC1155(deployedContract).balanceOf(Alice, 2), 5);
    }

    function test_1155Vault_bridge_back_but_owner_is_different_now_1155() public {
        vm.prank(Alice);
        eERC1155Token.setApprovalForAll(address(eVault), true);

        assertEq(eERC1155Token.balanceOf(Alice, 1), 10);
        assertEq(eERC1155Token.balanceOf(address(eVault), 1), 0);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;

        BaseNFTVault.BridgeTransferOp memory sendOpts = BaseNFTVault.BridgeTransferOp(
            taikoChainId,
            address(0),
            Alice,
            GAS_LIMIT,
            address(eERC1155Token),
            GAS_LIMIT,
            tokenIds,
            amounts
        );
        vm.prank(Alice);
        eVault.sendToken{ value: GAS_LIMIT }(sendOpts);

        assertEq(eERC1155Token.balanceOf(address(eVault), 1), 1);

        // This canonicalToken is basically need to be exact same as the
        // sendToken() puts together
        // - here is just mocking putting it together.
        BaseNFTVault.CanonicalNFT memory canonicalToken = BaseNFTVault.CanonicalNFT({
            chainId: ethereumChainId,
            addr: address(eERC1155Token),
            symbol: "TT",
            name: "TT"
        });

        vm.chainId(taikoChainId);

        tBridge.sendReceiveERC1155ToERC1155Vault(
            canonicalToken,
            Alice,
            Alice,
            tokenIds,
            amounts,
            bytes32(0),
            address(eVault),
            ethereumChainId,
            0
        );
        // Query canonicalToBridged
        address deployedContract =
            tVault.canonicalToBridged(ethereumChainId, address(eERC1155Token));

        // Alice bridged over 1 from tokenId 1
        assertEq(ERC1155(deployedContract).balanceOf(Alice, 1), 1);

        // Transfer the asset to Bob, and Bob can receive it back on canonical
        // chain
        vm.prank(Alice);
        ERC1155(deployedContract).safeTransferFrom(Alice, Bob, 1, 1, "");

        assertEq(ERC1155(deployedContract).balanceOf(Bob, 1), 1);
        assertEq(ERC1155(deployedContract).balanceOf(Alice, 1), 0);

        vm.prank(Bob);
        ERC1155(deployedContract).setApprovalForAll(address(tVault), true);

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

        vm.prank(Bob);
        tVault.sendToken{ value: GAS_LIMIT }(sendOpts);

        vm.chainId(ethereumChainId);

        assertEq(eERC1155Token.balanceOf(address(eVault), 1), 1);

        tBridge.setERC1155Vault(address(eVault));

        vm.prank(deployer);
        register("bridge", address(tBridge));

        tBridge.sendReceiveERC1155ToERC1155Vault(
            canonicalToken,
            Bob,
            Bob,
            tokenIds,
            amounts,
            bytes32(0),
            address(eVault),
            ethereumChainId,
            0
        );

        assertEq(eERC1155Token.balanceOf(Bob, 1), 1);
    }

    function test_1155Vault_bridge_back_but_original_owner_cannot_claim_it_anymore_if_sold_1155()
        public
    {
        vm.prank(Alice);
        eERC1155Token.setApprovalForAll(address(eVault), true);

        assertEq(eERC1155Token.balanceOf(Alice, 1), 10);
        assertEq(eERC1155Token.balanceOf(address(eVault), 1), 0);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;

        BaseNFTVault.BridgeTransferOp memory sendOpts = BaseNFTVault.BridgeTransferOp(
            taikoChainId,
            address(0),
            Alice,
            GAS_LIMIT,
            address(eERC1155Token),
            GAS_LIMIT,
            tokenIds,
            amounts
        );
        vm.prank(Alice);
        eVault.sendToken{ value: GAS_LIMIT }(sendOpts);

        assertEq(eERC1155Token.balanceOf(address(eVault), 1), 1);

        // This canonicalToken is basically need to be exact same as the
        // sendToken() puts together
        // - here is just mocking putting it together.
        BaseNFTVault.CanonicalNFT memory canonicalToken = BaseNFTVault.CanonicalNFT({
            chainId: ethereumChainId,
            addr: address(eERC1155Token),
            symbol: "TT",
            name: "TT"
        });

        vm.chainId(taikoChainId);

        tBridge.sendReceiveERC1155ToERC1155Vault(
            canonicalToken,
            Alice,
            Alice,
            tokenIds,
            amounts,
            bytes32(0),
            address(eVault),
            ethereumChainId,
            0
        );

        // Query canonicalToBridged
        address deployedContract =
            tVault.canonicalToBridged(ethereumChainId, address(eERC1155Token));
        // Alice bridged over 1 from tokenId 1
        assertEq(ERC1155(deployedContract).balanceOf(Alice, 1), 1);

        // Transfer the asset to Bob, and Bob can receive it back on canonical
        // chain
        vm.prank(Alice);
        ERC1155(deployedContract).safeTransferFrom(Alice, Bob, 1, 1, "");

        assertEq(ERC1155(deployedContract).balanceOf(Bob, 1), 1);
        assertEq(ERC1155(deployedContract).balanceOf(Alice, 1), 0);

        vm.prank(Bob);
        ERC1155(deployedContract).setApprovalForAll(address(tVault), true);

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
        vm.expectRevert("ERC1155: caller is not token owner or approved");
        tVault.sendToken{ value: GAS_LIMIT }(sendOpts);
    }

    function test_1155Vault_upgrade_bridged_tokens_1155() public {
        vm.prank(Alice);
        eERC1155Token.setApprovalForAll(address(eVault), true);

        assertEq(eERC1155Token.balanceOf(Alice, 1), 10);
        assertEq(eERC1155Token.balanceOf(address(eVault), 1), 0);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 2;

        BaseNFTVault.BridgeTransferOp memory sendOpts = BaseNFTVault.BridgeTransferOp(
            taikoChainId,
            address(0),
            Alice,
            GAS_LIMIT,
            address(eERC1155Token),
            GAS_LIMIT,
            tokenIds,
            amounts
        );
        vm.prank(Alice);
        eVault.sendToken{ value: GAS_LIMIT }(sendOpts);

        assertEq(eERC1155Token.balanceOf(Alice, 1), 8);
        assertEq(eERC1155Token.balanceOf(address(eVault), 1), 2);

        BaseNFTVault.CanonicalNFT memory ctoken = BaseNFTVault.CanonicalNFT({
            chainId: ethereumChainId,
            addr: address(eERC1155Token),
            symbol: "",
            name: ""
        });

        vm.chainId(taikoChainId);

        tBridge.sendReceiveERC1155ToERC1155Vault(
            ctoken, Alice, Alice, tokenIds, amounts, bytes32(0), address(eVault), ethereumChainId, 0
        );

        // Query canonicalToBridged
        address deployedContract =
            tVault.canonicalToBridged(ethereumChainId, address(eERC1155Token));

        try BridgedERC1155_WithHelloWorld(deployedContract).helloWorld() {
            fail();
        } catch { }

        // Upgrade the implementation of that contract
        // so that it supports now the 'helloWorld' call
        BridgedERC1155_WithHelloWorld newBridgedContract = new BridgedERC1155_WithHelloWorld();
        vm.prank(deployer);
        BridgedERC1155(payable(deployedContract)).upgradeTo(address(newBridgedContract));

        try CanSayHelloWorld(deployedContract).helloWorld() { }
        catch {
            fail();
        }
    }

    function test_1155Vault_shall_not_be_able_to_burn_arbitrarily() public {
        vm.prank(Alice);
        eERC1155Token.setApprovalForAll(address(eVault), true);

        assertEq(eERC1155Token.balanceOf(Alice, 1), 10);
        assertEq(eERC1155Token.balanceOf(address(eVault), 1), 0);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;

        BaseNFTVault.BridgeTransferOp memory sendOpts = BaseNFTVault.BridgeTransferOp(
            taikoChainId,
            address(0),
            Alice,
            GAS_LIMIT,
            address(eERC1155Token),
            GAS_LIMIT,
            tokenIds,
            amounts
        );
        vm.prank(Alice);
        eVault.sendToken{ value: GAS_LIMIT }(sendOpts);

        assertEq(eERC1155Token.balanceOf(address(eVault), 1), 1);

        // This canonicalToken is basically need to be exact same as the
        // sendToken() puts together
        // - here is just mocking putting it together.
        BaseNFTVault.CanonicalNFT memory canonicalToken = BaseNFTVault.CanonicalNFT({
            chainId: ethereumChainId,
            addr: address(eERC1155Token),
            symbol: "TT",
            name: "TT"
        });

        vm.chainId(taikoChainId);

        tBridge.sendReceiveERC1155ToERC1155Vault(
            canonicalToken,
            Alice,
            Alice,
            tokenIds,
            amounts,
            bytes32(0),
            address(eVault),
            ethereumChainId,
            0
        );

        // Query canonicalToBridged
        address deployedContract =
            tVault.canonicalToBridged(ethereumChainId, address(eERC1155Token));
        // Alice bridged over 1 from tokenId 1
        assertEq(ERC1155(deployedContract).balanceOf(Alice, 1), 1);

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
        vm.expectRevert("ERC1155: caller is not token owner or approved");
        tVault.sendToken{ value: GAS_LIMIT }(sendOpts);

        // Also Vault cannot burn tokens it does not own (even if the priv key compromised)
        vm.prank(address(tVault));
        vm.expectRevert("ERC1155: burn amount exceeds balance");
        BridgedERC1155(deployedContract).burn(1, 20);

        // After setApprovalForAll() ERC1155Vault can transfer and burn
        vm.prank(Alice);
        ERC1155(deployedContract).setApprovalForAll(address(tVault), true);
        vm.prank(Alice);
        tVault.sendToken{ value: GAS_LIMIT }(sendOpts);
    }
}
