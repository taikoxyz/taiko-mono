// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./ERC20Vault.h.sol";

contract TestERC20Vault is TaikoTest {
    SignalService signalService;
    Bridge bridge;
    ERC20Vault erc20Vault;
    FreeMintERC20 erc20;
    FreeMintERC20 weirdNamedToken;

    SignalService destSignalService;
    PrankDestBridge destBridge;
    ERC20Vault destERC20Vault;
    BridgedERC20 usdc;
    BridgedERC20 usdt;
    BridgedERC20 stETH;

    function prepareContractsOnSourceChain() internal override {
        signalService = deploySignalService(address(new SignalServiceNoProofCheck()));
        bridge = deployBridge(address(new Bridge()));
        erc20Vault = deployERC20Vault();

        erc20 = new FreeMintERC20("ERC20", "ERC20");
        erc20.mint(Alice);

        weirdNamedToken = new FreeMintERC20("", "123456abcdefgh");
        weirdNamedToken.mint(Alice);

        register("bridged_erc20", address(new BridgedERC20()));

        vm.deal(Alice, 1 ether);
        vm.deal(Bob, 1 ether);
    }

    function prepareContractsOnDestinationChain() internal override {
        destSignalService = deploySignalService(address(new SignalServiceNoProofCheck()));
        destERC20Vault = deployERC20Vault();
        destBridge = new PrankDestBridge(erc20Vault);

        register("bridge", address(destBridge));
        register("bridged_erc20", address(new BridgedERC20()));

        usdc = deployBridgedERC20(randAddress(), 100, 18, "USDC", "USDC coin");
        usdt = deployBridgedERC20(randAddress(), 100, 18, "USDT", "USDT coin");
        stETH = deployBridgedERC20(randAddress(), 100, 18, "stETH", "Lido Staked ETH");

        vm.deal(address(destBridge), 100 ether);
    }

    function test_20Vault_send_erc20_revert_if_allowance_not_set() public {
        vm.startPrank(Alice);
        vm.expectRevert(BaseVault.VAULT_INSUFFICIENT_FEE.selector);
        erc20Vault.sendToken(
            ERC20Vault.BridgeTransferOp(
                destChainId, address(0), Bob, 1, address(erc20), 1_000_000, 1 wei
            )
        );
    }

    function test_20Vault_send_erc20_no_processing_fee() public {
        vm.startPrank(Alice);

        uint64 amount = 2 wei;
        erc20.approve(address(erc20Vault), amount);

        uint256 aliceBalanceBefore = erc20.balanceOf(Alice);
        uint256 erc20VaultBalanceBefore = erc20.balanceOf(address(erc20Vault));

        erc20Vault.sendToken(
            ERC20Vault.BridgeTransferOp(
                destChainId, address(0), Bob, 0, address(erc20), 1_000_000, amount
            )
        );

        uint256 aliceBalanceAfter = erc20.balanceOf(Alice);
        uint256 erc20VaultBalanceAfter = erc20.balanceOf(address(erc20Vault));

        assertEq(aliceBalanceBefore - aliceBalanceAfter, amount);
        assertEq(erc20VaultBalanceAfter - erc20VaultBalanceBefore, amount);
    }

    function test_20Vault_send_erc20_processing_fee_reverts_if_msg_value_too_low() public {
        vm.startPrank(Alice);

        uint64 amount = 2 wei;
        erc20.approve(address(erc20Vault), amount);

        vm.expectRevert();
        erc20Vault.sendToken(
            ERC20Vault.BridgeTransferOp(
                destChainId, address(0), Bob, amount - 1, address(erc20), 1_000_000, amount
            )
        );
    }

    function test_20Vault_send_erc20_processing_fee() public {
        vm.startPrank(Alice);

        uint64 amount = 2 wei;
        erc20.approve(address(erc20Vault), amount);

        uint256 aliceBalanceBefore = erc20.balanceOf(Alice);
        uint256 erc20VaultBalanceBefore = erc20.balanceOf(address(erc20Vault));

        erc20Vault.sendToken{ value: amount }(
            ERC20Vault.BridgeTransferOp(
                destChainId,
                address(0),
                Bob,
                amount - 1,
                address(erc20),
                1_000_000,
                amount - 1 // value: (msg.value - fee)
            )
        );

        uint256 aliceBalanceAfter = erc20.balanceOf(Alice);
        uint256 erc20VaultBalanceAfter = erc20.balanceOf(address(erc20Vault));

        assertEq(aliceBalanceBefore - aliceBalanceAfter, 1);
        assertEq(erc20VaultBalanceAfter - erc20VaultBalanceBefore, 1);
    }

    function test_20Vault_send_erc20_reverts_invalid_amount() public {
        vm.startPrank(Alice);

        uint64 amount = 0;

        vm.expectRevert(ERC20Vault.VAULT_INVALID_AMOUNT.selector);
        erc20Vault.sendToken(
            ERC20Vault.BridgeTransferOp(
                destChainId, address(0), Bob, 0, address(erc20), 1_000_000, amount
            )
        );
    }

    function test_20Vault_send_erc20_reverts_invalid_token_address() public {
        vm.startPrank(Alice);

        uint64 amount = 1;

        vm.expectRevert(ERC20Vault.VAULT_INVALID_TOKEN.selector);
        erc20Vault.sendToken(
            ERC20Vault.BridgeTransferOp(
                destChainId, address(0), Bob, 0, address(0), 1_000_000, amount
            )
        );
    }

    function test_20Vault_receive_erc20_canonical_to_dest_chain_transfers_from_canonical_token()
        public
    {
        vm.startPrank(Alice);

        vm.chainId(destChainId);

        erc20.mint(address(erc20Vault));

        uint64 amount = 1;
        address to = Bob;

        uint256 erc20VaultBalanceBefore = erc20.balanceOf(address(erc20Vault));
        uint256 toBalanceBefore = erc20.balanceOf(to);

        destBridge.sendReceiveERC20ToERC20Vault(
            erc20ToCanonicalERC20(destChainId),
            Alice,
            to,
            amount,
            bytes32(0),
            address(erc20Vault),
            srcChainId,
            0
        );

        uint256 erc20VaultBalanceAfter = erc20.balanceOf(address(erc20Vault));
        assertEq(erc20VaultBalanceBefore - erc20VaultBalanceAfter, amount);

        uint256 toBalanceAfter = erc20.balanceOf(to);
        assertEq(toBalanceAfter - toBalanceBefore, amount);
    }

    function test_20Vault_receiveTokens_erc20_with_ether_to_dave() public {
        vm.startPrank(Alice);

        vm.chainId(destChainId);

        erc20.mint(address(erc20Vault));

        uint64 amount = 1;
        uint256 etherAmount = 0.1 ether;
        address to = David;

        uint256 erc20VaultBalanceBefore = erc20.balanceOf(address(erc20Vault));
        uint256 toBalanceBefore = erc20.balanceOf(to);

        destBridge.sendReceiveERC20ToERC20Vault(
            erc20ToCanonicalERC20(destChainId),
            Alice,
            to,
            amount,
            bytes32(0),
            address(erc20Vault),
            srcChainId,
            etherAmount
        );

        uint256 erc20VaultBalanceAfter = erc20.balanceOf(address(erc20Vault));
        assertEq(erc20VaultBalanceBefore - erc20VaultBalanceAfter, amount);

        uint256 toBalanceAfter = erc20.balanceOf(to);
        assertEq(toBalanceAfter - toBalanceBefore, amount);
        assertEq(David.balance, etherAmount);
    }

    function test_20Vault_receive_erc20_non_canonical_to_dest_chain_deploys_new_bridged_token_and_mints(
    )
        public
    {
        vm.startPrank(Alice);

        vm.chainId(destChainId);

        uint64 amount = 1;

        destBridge.setERC20Vault(address(destERC20Vault));

        address bridgedAddressBefore = destERC20Vault.canonicalToBridged(srcChainId, address(erc20));
        assertEq(bridgedAddressBefore == address(0), true);

        destBridge.sendReceiveERC20ToERC20Vault(
            erc20ToCanonicalERC20(srcChainId),
            Alice,
            Bob,
            amount,
            bytes32(0),
            address(erc20Vault),
            srcChainId,
            0
        );

        address bridgedAddressAfter = destERC20Vault.canonicalToBridged(srcChainId, address(erc20));
        assertEq(bridgedAddressAfter != address(0), true);
        BridgedERC20 bridgedERC20 = BridgedERC20(bridgedAddressAfter);

        assertEq(bridgedERC20.name(), "ERC20");
        assertEq(bridgedERC20.symbol(), "ERC20");
        assertEq(bridgedERC20.balanceOf(Bob), amount);
    }

    function erc20ToCanonicalERC20(uint64 chainId)
        internal
        view
        returns (ERC20Vault.CanonicalERC20 memory)
    {
        return ERC20Vault.CanonicalERC20({
            chainId: chainId,
            addr: address(erc20),
            decimals: erc20.decimals(),
            symbol: erc20.symbol(),
            name: erc20.name()
        });
    }

    function noNameErc20(uint64 chainId) internal view returns (ERC20Vault.CanonicalERC20 memory) {
        return ERC20Vault.CanonicalERC20({
            chainId: chainId,
            addr: address(weirdNamedToken),
            decimals: weirdNamedToken.decimals(),
            symbol: weirdNamedToken.symbol(),
            name: weirdNamedToken.name()
        });
    }

    function test_20Vault_upgrade_bridged_tokens_20() public {
        vm.startPrank(Alice);

        vm.chainId(destChainId);

        uint64 amount = 1;

        destBridge.setERC20Vault(address(destERC20Vault));

        address bridgedAddressBefore = destERC20Vault.canonicalToBridged(srcChainId, address(erc20));
        assertEq(bridgedAddressBefore == address(0), true);

        destBridge.sendReceiveERC20ToERC20Vault(
            erc20ToCanonicalERC20(srcChainId),
            Alice,
            Bob,
            amount,
            bytes32(0),
            address(erc20Vault),
            srcChainId,
            0
        );

        address bridgedAddressAfter = destERC20Vault.canonicalToBridged(srcChainId, address(erc20));
        assertEq(bridgedAddressAfter != address(0), true);

        try UpdatedBridgedERC20(bridgedAddressAfter).helloWorld() {
            fail();
        } catch {
            // It should not yet support this function call
        }

        // Upgrade the implementation of that contract
        // so that it supports now the 'helloWorld' call
        UpdatedBridgedERC20 newBridgedContract = new UpdatedBridgedERC20();
        vm.stopPrank();
        vm.prank(deployer);
        BridgedERC20(payable(bridgedAddressAfter)).upgradeTo(address(newBridgedContract));

        vm.prank(Alice, Alice);
        try UpdatedBridgedERC20(bridgedAddressAfter).helloWorld() {
            // It should support now this function call
        } catch {
            fail();
        }
    }

    function test_20Vault_onMessageRecalled_20() public {
        vm.startPrank(Alice);

        uint64 amount = 2 wei;
        erc20.approve(address(erc20Vault), amount);

        uint256 aliceBalanceBefore = erc20.balanceOf(Alice);
        uint256 erc20VaultBalanceBefore = erc20.balanceOf(address(erc20Vault));

        IBridge.Message memory _messageToSimulateFail = erc20Vault.sendToken(
            ERC20Vault.BridgeTransferOp(
                destChainId, address(0), Bob, 0, address(erc20), 1_000_000, amount
            )
        );

        uint256 aliceBalanceAfter = erc20.balanceOf(Alice);
        uint256 erc20VaultBalanceAfter = erc20.balanceOf(address(erc20Vault));

        assertEq(aliceBalanceBefore - aliceBalanceAfter, amount);
        assertEq(erc20VaultBalanceAfter - erc20VaultBalanceBefore, amount);

        // No need to imitate that it is failed because we have a mock SignalService
        bridge.recallMessage(_messageToSimulateFail, bytes(""));

        uint256 aliceBalanceAfterRecall = erc20.balanceOf(Alice);
        uint256 erc20VaultBalanceAfterRecall = erc20.balanceOf(address(erc20Vault));

        // Release -> original balance
        assertEq(aliceBalanceAfterRecall, aliceBalanceBefore);
        assertEq(erc20VaultBalanceAfterRecall, erc20VaultBalanceBefore);
    }

    function test_20Vault_change_bridged_token() public {
        // A mock canonical "token"
        address canonicalRandomToken = vm.addr(102);

        vm.warp(block.timestamp + 91 days);

        vm.startPrank(deployer);

        erc20Vault.changeBridgedToken(
            ERC20Vault.CanonicalERC20({
                chainId: 1,
                addr: address(erc20),
                decimals: 18,
                symbol: "ERC20TT",
                name: "ERC20 Test token"
            }),
            address(usdc)
        );

        assertEq(erc20Vault.canonicalToBridged(1, address(erc20)), address(usdc));

        vm.expectRevert(ERC20Vault.VAULT_LAST_MIGRATION_TOO_CLOSE.selector);
        erc20Vault.changeBridgedToken(
            ERC20Vault.CanonicalERC20({
                chainId: 1,
                addr: address(erc20),
                decimals: 18,
                symbol: "ERC20TT",
                name: "ERC20 Test token"
            }),
            address(usdt)
        );

        vm.warp(block.timestamp + 91 days);

        vm.expectRevert(ERC20Vault.VAULT_CTOKEN_MISMATCH.selector);
        erc20Vault.changeBridgedToken(
            ERC20Vault.CanonicalERC20({
                chainId: 1,
                addr: address(erc20),
                decimals: 18,
                symbol: "ERC20TT_WRONG_NAME",
                name: "ERC20 Test token"
            }),
            address(usdt)
        );

        erc20Vault.changeBridgedToken(
            ERC20Vault.CanonicalERC20({
                chainId: 1,
                addr: address(erc20),
                decimals: 18,
                symbol: "ERC20TT",
                name: "ERC20 Test token"
            }),
            address(usdt)
        );

        assertEq(erc20Vault.canonicalToBridged(1, address(erc20)), address(usdt));

        erc20Vault.changeBridgedToken(
            ERC20Vault.CanonicalERC20({
                chainId: 1,
                addr: canonicalRandomToken,
                decimals: 18,
                symbol: "ERC20TT2",
                name: "ERC20 Test token2"
            }),
            address(stETH)
        );

        vm.warp(block.timestamp + 91 days);

        // usdc is already blacklisted!
        vm.expectRevert(ERC20Vault.VAULT_BTOKEN_BLACKLISTED.selector);
        erc20Vault.changeBridgedToken(
            ERC20Vault.CanonicalERC20({
                chainId: 1,
                addr: address(erc20),
                decimals: 18,
                symbol: "ERC20TT",
                name: "ERC20 Test token"
            }),
            address(usdc)
        );

        // invalid btoken
        vm.expectRevert(ERC20Vault.VAULT_INVALID_CTOKEN.selector);
        erc20Vault.changeBridgedToken(
            ERC20Vault.CanonicalERC20({
                chainId: uint64(block.chainid),
                addr: address(erc20),
                decimals: 18,
                symbol: "ERC20TT",
                name: "ERC20 Test token"
            }),
            address(usdc)
        );

        // We cannot use stETH for erc20 (as it is used in connection with another token)
        vm.expectRevert(ERC20Vault.VAULT_INVALID_NEW_BTOKEN.selector);
        erc20Vault.changeBridgedToken(
            ERC20Vault.CanonicalERC20({
                chainId: 1,
                addr: address(erc20),
                decimals: 18,
                symbol: "ERC20TT",
                name: "ERC20 Test token"
            }),
            address(stETH)
        );

        vm.stopPrank();
    }

    function test_20Vault_to_string() public {
        vm.startPrank(Alice);

        (, bytes memory symbolData) =
            address(weirdNamedToken).staticcall(abi.encodeCall(INameSymbol.symbol, ()));
        (, bytes memory nameData) =
            address(weirdNamedToken).staticcall(abi.encodeCall(INameSymbol.name, ()));

        string memory decodedSymbol = LibBytes.toString(symbolData);
        string memory decodedName = LibBytes.toString(nameData);

        assertEq(decodedSymbol, "123456abcdefgh");
        assertEq(decodedName, "");

        vm.stopPrank();
    }

    function test_20Vault_deploy_erc20_with_no_name() public {
        vm.startPrank(Alice);

        vm.chainId(destChainId);

        uint64 amount = 1;

        destBridge.setERC20Vault(address(destERC20Vault));

        address bridgedAddressBefore = destERC20Vault.canonicalToBridged(srcChainId, address(erc20));
        assertEq(bridgedAddressBefore == address(0), true);

        // Token with empty name succeeds
        destBridge.sendReceiveERC20ToERC20Vault(
            noNameErc20(srcChainId),
            Alice,
            Bob,
            amount,
            bytes32(0),
            address(erc20Vault),
            srcChainId,
            0
        );
    }
}
