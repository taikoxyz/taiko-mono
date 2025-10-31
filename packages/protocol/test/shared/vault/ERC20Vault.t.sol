// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../helpers/FreeMintERC20Token.sol";
import "./ERC20Vault.h.sol";

contract TestERC20Vault is CommonTest {
    // Contracts on Ethereum
    SignalService private eSignalService;
    Bridge private eBridge;
    ERC20Vault private eVault;
    FreeMintERC20Token private eERC20Token1;
    FreeMintERC20Token private eERC20Token2;

    // Contracts on Taiko
    SignalService private tSignalService;
    PrankDestBridge private tBridge;
    PrankTaikoInbox private taikoInbox;
    ERC20Vault private tVault;
    BridgedERC20 private tUSDC;
    BridgedERC20 private tUSDT;
    BridgedERC20 private tStETH;

    function setUpOnEthereum() internal override {
        eSignalService = _deployMockSignalService("ETH");
        eBridge = deployBridge(address(new Bridge(address(resolver), address(eSignalService))));
        eVault = deployERC20Vault();

        eERC20Token1 = new FreeMintERC20Token("ERC20", "ERC20");
        eERC20Token1.mint(Alice);

        eERC20Token2 = new FreeMintERC20Token("", "123456abcdefgh");
        eERC20Token2.mint(Alice);

        register("bridged_erc20", address(new BridgedERC20(address(eVault))));

        vm.deal(Alice, 1 ether);
        vm.deal(Bob, 1 ether);
    }

    function setUpOnTaiko() internal override {
        tSignalService = _deployMockSignalService("TAIKO");
        tVault = deployERC20Vault();
        tBridge = new PrankDestBridge(eVault);
        taikoInbox = new PrankTaikoInbox();

        register("bridge", address(tBridge));
        register("bridged_erc20", address(new BridgedERC20(address(tVault))));
        register("taiko", address(taikoInbox));

        // TODO(fix): shall we use "tValut" below?
        tUSDC = deployBridgedERC20(address(eVault), randAddress(), 100, 18, "USDC", "USDC coin");
        tUSDT = deployBridgedERC20(address(eVault), randAddress(), 100, 18, "USDT", "USDT coin");
        tStETH = deployBridgedERC20(
            address(eVault), randAddress(), 100, 18, "tStETH", "Lido Staked ETH"
        );

        vm.deal(address(tBridge), 100 ether);
    }

    function test_20Vault_send_erc20_revert_if_allowance_not_set() public {
        vm.startPrank(Alice);
        vm.expectRevert(ERC20Vault.VAULT_INVALID_AMOUNT.selector);
        eVault.sendToken(
            ERC20Vault.BridgeTransferOp(
                taikoChainId, address(0), Bob, 0, address(eERC20Token1), 1_000_000, 0
            )
        );
    }

    function test_20Vault_send_erc20_no_processing_fee() public {
        vm.startPrank(Alice);

        uint64 amount = 2 wei;
        eERC20Token1.approve(address(eVault), amount);

        uint256 aliceBalanceBefore = eERC20Token1.balanceOf(Alice);
        uint256 eVaultBalanceBefore = eERC20Token1.balanceOf(address(eVault));

        eVault.sendToken(
            ERC20Vault.BridgeTransferOp(
                taikoChainId, address(0), Bob, 0, address(eERC20Token1), 1_000_000, amount
            )
        );

        uint256 aliceBalanceAfter = eERC20Token1.balanceOf(Alice);
        uint256 eVaultBalanceAfter = eERC20Token1.balanceOf(address(eVault));

        assertEq(aliceBalanceBefore - aliceBalanceAfter, amount);
        assertEq(eVaultBalanceAfter - eVaultBalanceBefore, amount);
    }

    function test_20Vault_send_erc20_processing_fee_reverts_if_msg_value_too_low() public {
        vm.startPrank(Alice);

        uint64 amount = 2 wei;
        eERC20Token1.approve(address(eVault), amount);

        vm.expectRevert();
        eVault.sendToken(
            ERC20Vault.BridgeTransferOp(
                taikoChainId, address(0), Bob, amount - 1, address(eERC20Token1), 1_000_000, amount
            )
        );
    }

    function test_20Vault_send_erc20_processing_fee() public {
        vm.startPrank(Alice);

        uint64 amount = 2 wei;
        eERC20Token1.approve(address(eVault), amount);

        uint256 aliceBalanceBefore = eERC20Token1.balanceOf(Alice);
        uint256 eVaultBalanceBefore = eERC20Token1.balanceOf(address(eVault));

        eVault.sendToken{
            value: amount
        }(
            ERC20Vault.BridgeTransferOp(
                taikoChainId,
                address(0),
                Bob,
                amount - 1,
                address(eERC20Token1),
                1_000_000,
                amount - 1 // value: (msg.value - fee)
            )
        );

        uint256 aliceBalanceAfter = eERC20Token1.balanceOf(Alice);
        uint256 eVaultBalanceAfter = eERC20Token1.balanceOf(address(eVault));

        assertEq(aliceBalanceBefore - aliceBalanceAfter, 1);
        assertEq(eVaultBalanceAfter - eVaultBalanceBefore, 1);
    }

    function test_20Vault_send_erc20_reverts_invalid_amount() public {
        vm.startPrank(Alice);

        uint64 amount = 0;

        vm.expectRevert(ERC20Vault.VAULT_INVALID_AMOUNT.selector);
        eVault.sendToken(
            ERC20Vault.BridgeTransferOp(
                taikoChainId, address(0), Bob, 0, address(eERC20Token1), 1_000_000, amount
            )
        );
    }

    function test_20Vault_send_erc20_reverts_insufficient_ether() public {
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

        eERC20Token1.mint(address(eVault));

        uint64 amount = 1;
        address to = Bob;

        uint256 eVaultBalanceBefore = eERC20Token1.balanceOf(address(eVault));
        uint256 toBalanceBefore = eERC20Token1.balanceOf(to);

        tBridge.sendReceiveERC20ToERC20Vault(
            erc20ToCanonicalERC20(taikoChainId),
            Alice,
            to,
            amount,
            0,
            bytes32(0),
            bytes32(0),
            address(eVault),
            ethereumChainId,
            0
        );

        uint256 eVaultBalanceAfter = eERC20Token1.balanceOf(address(eVault));
        assertEq(eVaultBalanceBefore - eVaultBalanceAfter, amount);

        uint256 toBalanceAfter = eERC20Token1.balanceOf(to);
        assertEq(toBalanceAfter - toBalanceBefore, amount);
    }

    function test_20Vault_receiveERC20Token1s_erc20_with_ether_to_dave() public {
        vm.startPrank(Alice);

        vm.chainId(taikoChainId);

        eERC20Token1.mint(address(eVault));

        uint64 amount = 1;
        uint256 etherAmount = 0.1 ether;
        address to = David;

        uint256 eVaultBalanceBefore = eERC20Token1.balanceOf(address(eVault));
        uint256 toBalanceBefore = eERC20Token1.balanceOf(to);

        tBridge.sendReceiveERC20ToERC20Vault(
            erc20ToCanonicalERC20(taikoChainId),
            Alice,
            to,
            amount,
            0,
            bytes32(0),
            bytes32(0),
            address(eVault),
            ethereumChainId,
            etherAmount
        );

        uint256 eVaultBalanceAfter = eERC20Token1.balanceOf(address(eVault));
        assertEq(eVaultBalanceBefore - eVaultBalanceAfter, amount);

        uint256 toBalanceAfter = eERC20Token1.balanceOf(to);
        assertEq(toBalanceAfter - toBalanceBefore, amount);
        assertEq(David.balance, etherAmount);
    }

    function test_20Vault_receive_erc20_non_canonical_to_dest_chain_deploys_new_bridged_token_and_mints()
        public
    {
        vm.startPrank(Alice);

        vm.chainId(taikoChainId);

        uint64 amount = 1;

        tBridge.setERC20Vault(address(tVault));

        address bridgedAddressBefore =
            tVault.canonicalToBridged(ethereumChainId, address(eERC20Token1));
        assertEq(bridgedAddressBefore == address(0), true);

        tBridge.sendReceiveERC20ToERC20Vault(
            erc20ToCanonicalERC20(ethereumChainId),
            Alice,
            Bob,
            amount,
            0,
            bytes32(0),
            bytes32(0),
            address(eVault),
            ethereumChainId,
            0
        );

        address bridgedAddressAfter =
            tVault.canonicalToBridged(ethereumChainId, address(eERC20Token1));
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
            addr: address(eERC20Token1),
            decimals: eERC20Token1.decimals(),
            symbol: eERC20Token1.symbol(),
            name: eERC20Token1.name()
        });
    }

    function noNameErc20(uint64 chainId) internal view returns (ERC20Vault.CanonicalERC20 memory) {
        return ERC20Vault.CanonicalERC20({
            chainId: chainId,
            addr: address(eERC20Token2),
            decimals: eERC20Token2.decimals(),
            symbol: eERC20Token2.symbol(),
            name: eERC20Token2.name()
        });
    }

    function test_20Vault_upgrade_bridged_tokens_20() public {
        vm.startPrank(Alice);

        vm.chainId(taikoChainId);

        uint64 amount = 1;

        tBridge.setERC20Vault(address(tVault));

        address bridgedAddressBefore =
            tVault.canonicalToBridged(ethereumChainId, address(eERC20Token1));
        assertEq(bridgedAddressBefore == address(0), true);

        tBridge.sendReceiveERC20ToERC20Vault(
            erc20ToCanonicalERC20(ethereumChainId),
            Alice,
            Bob,
            amount,
            0,
            bytes32(0),
            bytes32(0),
            address(eVault),
            ethereumChainId,
            0
        );

        address bridgedAddressAfter =
            tVault.canonicalToBridged(ethereumChainId, address(eERC20Token1));
        assertEq(bridgedAddressAfter != address(0), true);

        try CanSayHelloWorld(bridgedAddressAfter).helloWorld() {
            fail();
        } catch {
            // It should not yet support this function call
        }

        // Upgrade the implementation of that contract
        // so that it supports now the 'helloWorld' call
        BridgedERC20V2_WithHelloWorld newBridgedContract =
            new BridgedERC20V2_WithHelloWorld(address(tVault));
        vm.stopPrank();
        vm.prank(deployer);
        BridgedERC20(payable(bridgedAddressAfter)).upgradeTo(address(newBridgedContract));

        vm.prank(Alice);
        try CanSayHelloWorld(bridgedAddressAfter).helloWorld() {
        // It should support now this function call
        }
        catch {
            fail();
        }
    }

    function test_20Vault_onMessageRecalled_20() public {
        vm.startPrank(Alice);

        uint64 amount = 2 wei;
        eERC20Token1.approve(address(eVault), amount);

        uint256 aliceBalanceBefore = eERC20Token1.balanceOf(Alice);
        uint256 eVaultBalanceBefore = eERC20Token1.balanceOf(address(eVault));

        IBridge.Message memory _messageToSimulateFail = eVault.sendToken(
            ERC20Vault.BridgeTransferOp(
                taikoChainId, address(0), Bob, 0, address(eERC20Token1), 1_000_000, amount
            )
        );

        uint256 aliceBalanceAfter = eERC20Token1.balanceOf(Alice);
        uint256 eVaultBalanceAfter = eERC20Token1.balanceOf(address(eVault));

        assertEq(aliceBalanceBefore - aliceBalanceAfter, amount);
        assertEq(eVaultBalanceAfter - eVaultBalanceBefore, amount);

        // No need to imitate that it is failed because we have a mock SignalService
        eBridge.recallMessage(_messageToSimulateFail, bytes(""));

        uint256 aliceBalanceAfterRecall = eERC20Token1.balanceOf(Alice);
        uint256 eVaultBalanceAfterRecall = eERC20Token1.balanceOf(address(eVault));

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
                addr: address(eERC20Token1),
                decimals: 18,
                symbol: "ERC20TT",
                name: "ERC20 Test token"
            }),
            address(tUSDC)
        );

        assertEq(eVault.canonicalToBridged(1, address(eERC20Token1)), address(tUSDC));

        vm.expectRevert(ERC20Vault.VAULT_LAST_MIGRATION_TOO_CLOSE.selector);
        eVault.changeBridgedToken(
            ERC20Vault.CanonicalERC20({
                chainId: 1,
                addr: address(eERC20Token1),
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
                addr: address(eERC20Token1),
                decimals: 18,
                symbol: "ERC20TT_WRONG_NAME",
                name: "ERC20 Test token"
            }),
            address(tUSDT)
        );

        eVault.changeBridgedToken(
            ERC20Vault.CanonicalERC20({
                chainId: 1,
                addr: address(eERC20Token1),
                decimals: 18,
                symbol: "ERC20TT",
                name: "ERC20 Test token"
            }),
            address(tUSDT)
        );

        assertEq(eVault.canonicalToBridged(1, address(eERC20Token1)), address(tUSDT));

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
                addr: address(eERC20Token1),
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
                addr: address(eERC20Token1),
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
                addr: address(eERC20Token1),
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

        (bool success1, bytes memory symbolData) =
            address(eERC20Token2).staticcall(abi.encodeCall(INameSymbol.symbol, ()));
        require(success1, "Symbol call failed");
        (bool success2, bytes memory nameData) =
            address(eERC20Token2).staticcall(abi.encodeCall(INameSymbol.name, ()));
        require(success2, "Name call failed");

        string memory decodedSymbol = LibBytesInternal.toString(symbolData);
        string memory decodedName = LibBytesInternal.toString(nameData);

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
            tVault.canonicalToBridged(ethereumChainId, address(eERC20Token1));
        assertEq(bridgedAddressBefore == address(0), true);

        // Token with empty name succeeds
        tBridge.sendReceiveERC20ToERC20Vault(
            noNameErc20(ethereumChainId),
            Alice,
            Bob,
            amount,
            0,
            bytes32(0),
            bytes32(0),
            address(eVault),
            ethereumChainId,
            0
        );
    }

    function test_20Vault_by_Halborn_BridgedToken_SolverFee_NotTransferred() public {
        vm.startPrank(Alice);
        vm.chainId(ethereumChainId);

        // Deploy a token on one chain that will be bridged
        FreeMintERC20Token originalToken = new FreeMintERC20Token("ORIG", "Original");
        originalToken.mint(Alice);

        // Create a canonical representation for this token
        ERC20Vault.CanonicalERC20 memory canonicalToken = ERC20Vault.CanonicalERC20({
            chainId: 999, // Some other chain ID
            addr: address(originalToken),
            decimals: 18,
            symbol: "ORIG",
            name: "Original"
        });

        // Deploy a bridged token on this chain
        // Note the owner is 0x0 without using a proxy
        address bridgedTokenAddr = address(new BridgedERC20(address(eVault)));

        // Set up the mappings in the vault
        vm.stopPrank();

        // Warp time to avoid migration issues
        vm.warp(block.timestamp + 91 days);

        vm.prank(deployer);
        eVault.changeBridgedToken(canonicalToken, bridgedTokenAddr);

        vm.prank(address(eVault)); // Only owner or ERC20Vault can mint
        BridgedERC20(bridgedTokenAddr).mint(Alice, 10e18);

        vm.startPrank(Alice);

        uint256 aliceBalanceBefore = BridgedERC20(bridgedTokenAddr).balanceOf(Alice);
        // console.log("Alice amount before = %s", aliceBalanceBefore);

        // Define the amounts
        uint256 amount = 1e18;
        BridgedERC20(bridgedTokenAddr).approve(address(eVault), amount);

        // Execute the bridge transfer
        eVault.sendToken(
            ERC20Vault.BridgeTransferOp(
                taikoChainId,
                address(0),
                Bob,
                0, // No processing fee
                bridgedTokenAddr,
                1_000_000,
                uint256(amount)
            )
        );

        // Check Alice's balance after the transaction
        uint256 aliceBalanceAfter = BridgedERC20(bridgedTokenAddr).balanceOf(Alice);
        // console.log("Alice amount after = %s", aliceBalanceAfter);
        // console.log(
        //     "Alice amount before - Alice amount after = %s", aliceBalanceBefore -
        // aliceBalanceAfter
        // );

        // Ensure that only the approved amount was deducted
        assertEq(aliceBalanceBefore - aliceBalanceAfter, amount);
        vm.stopPrank();
    }

    function _deployMockSignalService(bytes32 label) private returns (SignalService) {
        return deploySignalServiceWithoutProof(
            address(this),
            address(uint160(uint256(keccak256(abi.encodePacked(label, "_REMOTE_SIGNAL"))))),
            deployer
        );
    }
}

// Create a malicious contract that will receive tokens but revert the ETH.
contract MaliciousReceiver {
    // Will revert when receiving ETH.
    receive() external payable {
        revert("I refuse to accept ETH!");
    }
    // Optional fallback function that will revert when receiving ETH.

    fallback() external payable {
        revert("I refuse to accept ETH!");
    }
}
