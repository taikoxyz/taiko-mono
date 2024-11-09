// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./ERC20Vault.h.sol";

contract TestERC20Vault is CommonTest {
    // Contracts on Ethereum
    SignalService private eSignalService;
    Bridge private eBridge;
    ERC20Vault private eVault;
    FreeMintERC20 private eFreeMintERC20;
    FreeMintERC20 private eFreeMintERC20WithWeirdName;

    // Contracts on Taiko
    SignalService private tSignalService;
    PrankDestBridge private tBridge;
    ERC20Vault private tVault;
    BridgedERC20 private tUSDC;
    BridgedERC20 private tUSDT;
    BridgedERC20 private tStETH;

    function setUpOnEthereum() internal override {
        eSignalService = deploySignalService(address(new SignalServiceNoProofCheck()));
        eBridge = deployBridge(address(new Bridge()));
        eVault = deployERC20Vault();

        eFreeMintERC20 = new FreeMintERC20("ERC20", "ERC20");
        eFreeMintERC20.mint(Alice);

        eFreeMintERC20WithWeirdName = new FreeMintERC20("", "123456abcdefgh");
        eFreeMintERC20WithWeirdName.mint(Alice);

        register("bridged_erc20", address(new BridgedERC20()));

        vm.deal(Alice, 1 ether);
        vm.deal(Bob, 1 ether);
    }

    function setUpOnTaiko() internal override {
        tSignalService = deploySignalService(address(new SignalServiceNoProofCheck()));
        tVault = deployERC20Vault();
        tBridge = new PrankDestBridge(eVault);

        register("bridge", address(tBridge));
        register("bridged_erc20", address(new BridgedERC20()));

        tUSDC = deployBridgedERC20(randAddress(), 100, 18, "USDC", "USDC coin");
        tUSDT = deployBridgedERC20(randAddress(), 100, 18, "USDT", "USDT coin");
        tStETH = deployBridgedERC20(randAddress(), 100, 18, "tStETH", "Lido Staked ETH");

        vm.deal(address(tBridge), 100 ether);
    }

    function test_20Vault_send_erc20_revert_if_allowance_not_set() public {
        vm.startPrank(Alice);
        vm.expectRevert(BaseVault.VAULT_INSUFFICIENT_FEE.selector);
        eVault.sendToken(
            ERC20Vault.BridgeTransferOp(
                taikoChainId, address(0), Bob, 1, address(eFreeMintERC20), 1_000_000, 1 wei
            )
        );
    }

    function test_20Vault_send_erc20_no_processing_fee() public {
        vm.startPrank(Alice);

        uint64 amount = 2 wei;
        eFreeMintERC20.approve(address(eVault), amount);

        uint256 aliceBalanceBefore = eFreeMintERC20.balanceOf(Alice);
        uint256 eVaultBalanceBefore = eFreeMintERC20.balanceOf(address(eVault));

        eVault.sendToken(
            ERC20Vault.BridgeTransferOp(
                taikoChainId, address(0), Bob, 0, address(eFreeMintERC20), 1_000_000, amount
            )
        );

        uint256 aliceBalanceAfter = eFreeMintERC20.balanceOf(Alice);
        uint256 eVaultBalanceAfter = eFreeMintERC20.balanceOf(address(eVault));

        assertEq(aliceBalanceBefore - aliceBalanceAfter, amount);
        assertEq(eVaultBalanceAfter - eVaultBalanceBefore, amount);
    }

    function test_20Vault_send_erc20_processing_fee_reverts_if_msg_value_too_low() public {
        vm.startPrank(Alice);

        uint64 amount = 2 wei;
        eFreeMintERC20.approve(address(eVault), amount);

        vm.expectRevert();
        eVault.sendToken(
            ERC20Vault.BridgeTransferOp(
                taikoChainId,
                address(0),
                Bob,
                amount - 1,
                address(eFreeMintERC20),
                1_000_000,
                amount
            )
        );
    }

    function test_20Vault_send_erc20_processing_fee() public {
        vm.startPrank(Alice);

        uint64 amount = 2 wei;
        eFreeMintERC20.approve(address(eVault), amount);

        uint256 aliceBalanceBefore = eFreeMintERC20.balanceOf(Alice);
        uint256 eVaultBalanceBefore = eFreeMintERC20.balanceOf(address(eVault));

        eVault.sendToken{ value: amount }(
            ERC20Vault.BridgeTransferOp(
                taikoChainId,
                address(0),
                Bob,
                amount - 1,
                address(eFreeMintERC20),
                1_000_000,
                amount - 1 // value: (msg.value - fee)
            )
        );

        uint256 aliceBalanceAfter = eFreeMintERC20.balanceOf(Alice);
        uint256 eVaultBalanceAfter = eFreeMintERC20.balanceOf(address(eVault));

        assertEq(aliceBalanceBefore - aliceBalanceAfter, 1);
        assertEq(eVaultBalanceAfter - eVaultBalanceBefore, 1);
    }

    function test_20Vault_send_erc20_reverts_invalid_amount() public {
        vm.startPrank(Alice);

        uint64 amount = 0;

        vm.expectRevert(ERC20Vault.VAULT_INVALID_AMOUNT.selector);
        eVault.sendToken(
            ERC20Vault.BridgeTransferOp(
                taikoChainId, address(0), Bob, 0, address(eFreeMintERC20), 1_000_000, amount
            )
        );
    }

    function test_20Vault_send_erc20_reverts_invalid_token_address() public {
        vm.startPrank(Alice);

        uint64 amount = 1;

        vm.expectRevert(ERC20Vault.VAULT_INVALID_TOKEN.selector);
        eVault.sendToken(
            ERC20Vault.BridgeTransferOp(
                taikoChainId, address(0), Bob, 0, address(0), 1_000_000, amount
            )
        );
    }

    function test_20Vault_receive_erc20_canonical_to_dest_chain_transfers_from_canonical_token()
        public
    {
        vm.startPrank(Alice);

        vm.chainId(taikoChainId);

        eFreeMintERC20.mint(address(eVault));

        uint64 amount = 1;
        address to = Bob;

        uint256 eVaultBalanceBefore = eFreeMintERC20.balanceOf(address(eVault));
        uint256 toBalanceBefore = eFreeMintERC20.balanceOf(to);

        tBridge.sendReceiveERC20ToERC20Vault(
            erc20ToCanonicalERC20(taikoChainId),
            Alice,
            to,
            amount,
            bytes32(0),
            address(eVault),
            ethereumChainId,
            0
        );

        uint256 eVaultBalanceAfter = eFreeMintERC20.balanceOf(address(eVault));
        assertEq(eVaultBalanceBefore - eVaultBalanceAfter, amount);

        uint256 toBalanceAfter = eFreeMintERC20.balanceOf(to);
        assertEq(toBalanceAfter - toBalanceBefore, amount);
    }

    function test_20Vault_receiveFreeMintERC20s_erc20_with_ether_to_dave() public {
        vm.startPrank(Alice);

        vm.chainId(taikoChainId);

        eFreeMintERC20.mint(address(eVault));

        uint64 amount = 1;
        uint256 etherAmount = 0.1 ether;
        address to = David;

        uint256 eVaultBalanceBefore = eFreeMintERC20.balanceOf(address(eVault));
        uint256 toBalanceBefore = eFreeMintERC20.balanceOf(to);

        tBridge.sendReceiveERC20ToERC20Vault(
            erc20ToCanonicalERC20(taikoChainId),
            Alice,
            to,
            amount,
            bytes32(0),
            address(eVault),
            ethereumChainId,
            etherAmount
        );

        uint256 eVaultBalanceAfter = eFreeMintERC20.balanceOf(address(eVault));
        assertEq(eVaultBalanceBefore - eVaultBalanceAfter, amount);

        uint256 toBalanceAfter = eFreeMintERC20.balanceOf(to);
        assertEq(toBalanceAfter - toBalanceBefore, amount);
        assertEq(David.balance, etherAmount);
    }

    function test_20Vault_receive_erc20_non_canonical_to_dest_chain_deploys_new_bridged_token_and_mints(
    )
        public
    {
        vm.startPrank(Alice);

        vm.chainId(taikoChainId);

        uint64 amount = 1;

        tBridge.setERC20Vault(address(tVault));

        address bridgedAddressBefore =
            tVault.canonicalToBridged(ethereumChainId, address(eFreeMintERC20));
        assertEq(bridgedAddressBefore == address(0), true);

        tBridge.sendReceiveERC20ToERC20Vault(
            erc20ToCanonicalERC20(ethereumChainId),
            Alice,
            Bob,
            amount,
            bytes32(0),
            address(eVault),
            ethereumChainId,
            0
        );

        address bridgedAddressAfter =
            tVault.canonicalToBridged(ethereumChainId, address(eFreeMintERC20));
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
            addr: address(eFreeMintERC20),
            decimals: eFreeMintERC20.decimals(),
            symbol: eFreeMintERC20.symbol(),
            name: eFreeMintERC20.name()
        });
    }

    function noNameErc20(uint64 chainId) internal view returns (ERC20Vault.CanonicalERC20 memory) {
        return ERC20Vault.CanonicalERC20({
            chainId: chainId,
            addr: address(eFreeMintERC20WithWeirdName),
            decimals: eFreeMintERC20WithWeirdName.decimals(),
            symbol: eFreeMintERC20WithWeirdName.symbol(),
            name: eFreeMintERC20WithWeirdName.name()
        });
    }

    function test_20Vault_upgrade_bridged_tokens_20() public {
        vm.startPrank(Alice);

        vm.chainId(taikoChainId);

        uint64 amount = 1;

        tBridge.setERC20Vault(address(tVault));

        address bridgedAddressBefore =
            tVault.canonicalToBridged(ethereumChainId, address(eFreeMintERC20));
        assertEq(bridgedAddressBefore == address(0), true);

        tBridge.sendReceiveERC20ToERC20Vault(
            erc20ToCanonicalERC20(ethereumChainId),
            Alice,
            Bob,
            amount,
            bytes32(0),
            address(eVault),
            ethereumChainId,
            0
        );

        address bridgedAddressAfter =
            tVault.canonicalToBridged(ethereumChainId, address(eFreeMintERC20));
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

        vm.prank(Alice);
        try UpdatedBridgedERC20(bridgedAddressAfter).helloWorld() {
            // It should support now this function call
        } catch {
            fail();
        }
    }

    function test_20Vault_onMessageRecalled_20() public {
        vm.startPrank(Alice);

        uint64 amount = 2 wei;
        eFreeMintERC20.approve(address(eVault), amount);

        uint256 aliceBalanceBefore = eFreeMintERC20.balanceOf(Alice);
        uint256 eVaultBalanceBefore = eFreeMintERC20.balanceOf(address(eVault));

        IBridge.Message memory _messageToSimulateFail = eVault.sendToken(
            ERC20Vault.BridgeTransferOp(
                taikoChainId, address(0), Bob, 0, address(eFreeMintERC20), 1_000_000, amount
            )
        );

        uint256 aliceBalanceAfter = eFreeMintERC20.balanceOf(Alice);
        uint256 eVaultBalanceAfter = eFreeMintERC20.balanceOf(address(eVault));

        assertEq(aliceBalanceBefore - aliceBalanceAfter, amount);
        assertEq(eVaultBalanceAfter - eVaultBalanceBefore, amount);

        // No need to imitate that it is failed because we have a mock SignalService
        eBridge.recallMessage(_messageToSimulateFail, bytes(""));

        uint256 aliceBalanceAfterRecall = eFreeMintERC20.balanceOf(Alice);
        uint256 eVaultBalanceAfterRecall = eFreeMintERC20.balanceOf(address(eVault));

        // Release -> original balance
        assertEq(aliceBalanceAfterRecall, aliceBalanceBefore);
        assertEq(eVaultBalanceAfterRecall, eVaultBalanceBefore);
    }

    function test_20Vault_change_bridged_token() public {
        // A mock canonical "token"
        address canonicalRandomToken = vm.addr(102);

        vm.warp(block.timestamp + 91 days);

        vm.startPrank(deployer);

        eVault.changeBridgedToken(
            ERC20Vault.CanonicalERC20({
                chainId: 1,
                addr: address(eFreeMintERC20),
                decimals: 18,
                symbol: "ERC20TT",
                name: "ERC20 Test token"
            }),
            address(tUSDC)
        );

        assertEq(eVault.canonicalToBridged(1, address(eFreeMintERC20)), address(tUSDC));

        vm.expectRevert(ERC20Vault.VAULT_LAST_MIGRATION_TOO_CLOSE.selector);
        eVault.changeBridgedToken(
            ERC20Vault.CanonicalERC20({
                chainId: 1,
                addr: address(eFreeMintERC20),
                decimals: 18,
                symbol: "ERC20TT",
                name: "ERC20 Test token"
            }),
            address(tUSDT)
        );

        vm.warp(block.timestamp + 91 days);

        vm.expectRevert(ERC20Vault.VAULT_CTOKEN_MISMATCH.selector);
        eVault.changeBridgedToken(
            ERC20Vault.CanonicalERC20({
                chainId: 1,
                addr: address(eFreeMintERC20),
                decimals: 18,
                symbol: "ERC20TT_WRONG_NAME",
                name: "ERC20 Test token"
            }),
            address(tUSDT)
        );

        eVault.changeBridgedToken(
            ERC20Vault.CanonicalERC20({
                chainId: 1,
                addr: address(eFreeMintERC20),
                decimals: 18,
                symbol: "ERC20TT",
                name: "ERC20 Test token"
            }),
            address(tUSDT)
        );

        assertEq(eVault.canonicalToBridged(1, address(eFreeMintERC20)), address(tUSDT));

        eVault.changeBridgedToken(
            ERC20Vault.CanonicalERC20({
                chainId: 1,
                addr: canonicalRandomToken,
                decimals: 18,
                symbol: "ERC20TT2",
                name: "ERC20 Test token2"
            }),
            address(tStETH)
        );

        vm.warp(block.timestamp + 91 days);

        // tUSDC is already blacklisted!
        vm.expectRevert(ERC20Vault.VAULT_BTOKEN_BLACKLISTED.selector);
        eVault.changeBridgedToken(
            ERC20Vault.CanonicalERC20({
                chainId: 1,
                addr: address(eFreeMintERC20),
                decimals: 18,
                symbol: "ERC20TT",
                name: "ERC20 Test token"
            }),
            address(tUSDC)
        );

        // invalid btoken
        vm.expectRevert(ERC20Vault.VAULT_INVALID_CTOKEN.selector);
        eVault.changeBridgedToken(
            ERC20Vault.CanonicalERC20({
                chainId: ethereumChainId,
                addr: address(eFreeMintERC20),
                decimals: 18,
                symbol: "ERC20TT",
                name: "ERC20 Test token"
            }),
            address(tUSDC)
        );

        // We cannot use tStETH for erc20 (as it is used in connection with another token)
        vm.expectRevert(ERC20Vault.VAULT_INVALID_NEW_BTOKEN.selector);
        eVault.changeBridgedToken(
            ERC20Vault.CanonicalERC20({
                chainId: 1,
                addr: address(eFreeMintERC20),
                decimals: 18,
                symbol: "ERC20TT",
                name: "ERC20 Test token"
            }),
            address(tStETH)
        );

        vm.stopPrank();
    }

    function test_20Vault_to_string() public {
        vm.startPrank(Alice);

        (, bytes memory symbolData) =
            address(eFreeMintERC20WithWeirdName).staticcall(abi.encodeCall(INameSymbol.symbol, ()));
        (, bytes memory nameData) =
            address(eFreeMintERC20WithWeirdName).staticcall(abi.encodeCall(INameSymbol.name, ()));

        string memory decodedSymbol = LibBytes.toString(symbolData);
        string memory decodedName = LibBytes.toString(nameData);

        assertEq(decodedSymbol, "123456abcdefgh");
        assertEq(decodedName, "");

        vm.stopPrank();
    }

    function test_20Vault_deploy_erc20_with_no_name() public {
        vm.startPrank(Alice);

        vm.chainId(taikoChainId);

        uint64 amount = 1;

        tBridge.setERC20Vault(address(tVault));

        address bridgedAddressBefore =
            tVault.canonicalToBridged(ethereumChainId, address(eFreeMintERC20));
        assertEq(bridgedAddressBefore == address(0), true);

        // Token with empty name succeeds
        tBridge.sendReceiveERC20ToERC20Vault(
            noNameErc20(ethereumChainId),
            Alice,
            Bob,
            amount,
            bytes32(0),
            address(eVault),
            ethereumChainId,
            0
        );
    }
}
