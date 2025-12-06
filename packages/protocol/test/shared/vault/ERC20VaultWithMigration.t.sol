// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../helpers/FreeMintERC20Token.sol";
import "./ERC20Vault.h.sol";
import "src/shared/vault/ERC20VaultWithMigration.sol";

contract TestERC20VaultWithMigration is CommonTest {
    // Contracts on Ethereum
    SignalService private eSignalService;
    Bridge private eBridge;
    ERC20VaultWithMigration private eVault;
    FreeMintERC20Token private eERC20Token1;

    // Bridged tokens for migration testing
    BridgedERC20 private tUSDC;
    BridgedERC20 private tUSDT;
    BridgedERC20 private tStETH;

    function setUpOnEthereum() internal override {
        eSignalService = _deployMockSignalService("ETH");
        eBridge = deployBridge(address(new Bridge(address(resolver), address(eSignalService))));
        eVault = deployERC20VaultWithMigration();

        eERC20Token1 = new FreeMintERC20Token("ERC20", "ERC20");
        eERC20Token1.mint(Alice);

        register("bridged_erc20", address(new BridgedERC20(address(eVault))));

        // Deploy bridged tokens for migration testing
        tUSDC = deployBridgedERC20(address(eVault), randAddress(), 100, 18, "USDC", "USDC coin");
        tUSDT = deployBridgedERC20(address(eVault), randAddress(), 100, 18, "USDT", "USDT coin");
        tStETH = deployBridgedERC20(
            address(eVault), randAddress(), 100, 18, "tStETH", "Lido Staked ETH"
        );

        vm.deal(Alice, 1 ether);
        vm.deal(Bob, 1 ether);
    }

    function setUpOnTaiko() internal override { }

    function deployERC20VaultWithMigration() internal returns (ERC20VaultWithMigration) {
        return ERC20VaultWithMigration(
            deploy({
                name: "erc20_vault",
                impl: address(new ERC20VaultWithMigration(address(resolver))),
                data: abi.encodeCall(ERC20Vault.init, (address(0)))
            })
        );
    }

    function test_20VaultWithMigration_change_bridged_token() public {
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

        vm.expectRevert(ERC20VaultWithMigration.VAULT_LAST_MIGRATION_TOO_CLOSE.selector);
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

        vm.expectRevert(ERC20VaultWithMigration.VAULT_CTOKEN_MISMATCH.selector);
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
        vm.expectRevert(ERC20VaultWithMigration.VAULT_INVALID_CTOKEN.selector);
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
        vm.expectRevert(ERC20VaultWithMigration.VAULT_INVALID_NEW_BTOKEN.selector);
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

    function _deployMockSignalService(bytes32 label) private returns (SignalService) {
        return deploySignalServiceWithoutProof(
            address(this),
            address(uint160(uint256(keccak256(abi.encodePacked(label, "_REMOTE_SIGNAL"))))),
            deployer
        );
    }
}
