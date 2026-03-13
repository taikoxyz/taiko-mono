// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "test/shared/CommonTest.sol";

import { ICircleFiatToken } from "src/shared/thirdparty/ICircleFiatToken.sol";
import { Bridge } from "src/shared/bridge/Bridge.sol";
import { SignalService } from "src/shared/signal/SignalService.sol";
import { ERC20Vault } from "src/shared/vault/ERC20Vault.sol";
import { CircleArtifactTestBase } from "test/shared/helpers/CircleArtifactTestBase.sol";

contract TestCircleUSDCBridge is CommonTest, CircleArtifactTestBase {
    event Transfer(address indexed from, address indexed to, uint256 value);

    uint256 private constant BRIDGE_AMOUNT = 25_000_000;

    SignalService private eSignalService;
    Bridge private eBridge;
    ERC20Vault private eVault;
    ICircleFiatToken private eUSDC;
    address private tUSDCImplementation;

    SignalService private tSignalService;
    Bridge private tBridge;
    ERC20Vault private tVault;
    ICircleFiatToken private tUSDC;

    function setUpOnEthereum() internal override {
        eSignalService = deploySignalServiceWithoutProof(randAddress(), randAddress(), deployer);
        eBridge = deployBridge(address(new Bridge(address(resolver), address(eSignalService))));
        eVault = deployERC20Vault();

        address l1Proxy;
        (tUSDCImplementation, l1Proxy) = _deployTestUSDC();
        eUSDC = ICircleFiatToken(l1Proxy);

        vm.stopPrank();
        vm.startPrank(MASTER_MINTER);
        eUSDC.configureMinter(address(this), type(uint256).max);
        vm.stopPrank();
        eUSDC.mint(Alice, BRIDGE_AMOUNT * 2);
        vm.startPrank(deployer);

        vm.deal(Alice, 1 ether);
        vm.deal(Bob, 1 ether);
    }

    function setUpOnTaiko() internal override {
        tSignalService = deploySignalServiceWithoutProof(randAddress(), randAddress(), deployer);
        tBridge = deployBridge(address(new Bridge(address(resolver), address(tSignalService))));
        tVault = deployERC20Vault();
        tUSDC = ICircleFiatToken(_deployTestUSDCProxy(tUSDCImplementation));

        vm.stopPrank();
        vm.startPrank(MASTER_MINTER);
        tUSDC.configureMinter(address(tVault), type(uint256).max);
        vm.stopPrank();
        vm.startPrank(deployer);

        vm.warp(block.timestamp + tVault.MIN_MIGRATION_DELAY() + 1);
        tVault.changeBridgedToken(_canonicalL1USDC(), address(tUSDC));

        vm.deal(Alice, 1 ether);
        vm.deal(Bob, 1 ether);
        vm.deal(address(tBridge), 100 ether);
    }

    function test_change_bridged_token_registers_native_usdc() public onTaiko {
        assertEq(tVault.canonicalToBridged(ethereumChainId, address(eUSDC)), address(tUSDC));

        (
            uint64 canonicalChainId,
            address canonicalAddress,
            uint8 decimals,
            string memory symbol,
            string memory name
        ) = tVault.bridgedToCanonical(address(tUSDC));

        assertEq(canonicalChainId, ethereumChainId);
        assertEq(canonicalAddress, address(eUSDC));
        assertEq(decimals, 6);
        assertEq(symbol, "USDC");
        assertEq(name, "USD Coin");
    }

    function test_l1_to_l2_mint_path_decreases_vault_minter_allowance() public {
        uint256 allowanceBefore = tUSDC.minterAllowance(address(tVault));

        _bridgeL1ToL2(BRIDGE_AMOUNT);

        assertEq(tUSDC.balanceOf(Alice), BRIDGE_AMOUNT);
        assertEq(tUSDC.minterAllowance(address(tVault)), allowanceBefore - BRIDGE_AMOUNT);
    }

    function test_l2_to_l1_burn_path_transfers_into_vault_then_burns_without_changing_allowance()
        public
    {
        _bridgeL1ToL2(BRIDGE_AMOUNT);

        vm.chainId(taikoChainId);

        uint256 allowanceBefore = tUSDC.minterAllowance(address(tVault));
        uint256 totalSupplyBefore = tUSDC.totalSupply();

        vm.prank(Alice);
        tUSDC.approve(address(tVault), BRIDGE_AMOUNT);

        vm.expectEmit(true, true, false, true, address(tUSDC));
        emit Transfer(Alice, address(tVault), BRIDGE_AMOUNT);
        vm.expectEmit(true, true, false, true, address(tUSDC));
        emit Transfer(address(tVault), address(0), BRIDGE_AMOUNT);

        vm.prank(Alice);
        IBridge.Message memory message = tVault.sendToken(
            ERC20Vault.BridgeTransferOp({
                destChainId: ethereumChainId,
                destOwner: address(0),
                to: Alice,
                fee: 0,
                token: address(tUSDC),
                gasLimit: 1_000_000,
                amount: BRIDGE_AMOUNT
            })
        );

        assertEq(tUSDC.balanceOf(address(tVault)), 0);
        assertEq(tUSDC.totalSupply(), totalSupplyBefore - BRIDGE_AMOUNT);
        assertEq(tUSDC.minterAllowance(address(tVault)), allowanceBefore);

        vm.chainId(ethereumChainId);

        uint256 l1BalanceBeforeProcess = eUSDC.balanceOf(Alice);

        vm.prank(Bob);
        eBridge.processMessage(message, hex"00");

        assertEq(eUSDC.balanceOf(Alice), l1BalanceBeforeProcess + BRIDGE_AMOUNT);
    }

    function _bridgeL1ToL2(uint256 _amount) private {
        vm.chainId(ethereumChainId);

        vm.prank(Alice);
        eUSDC.approve(address(eVault), _amount);

        vm.prank(Alice);
        IBridge.Message memory message = eVault.sendToken(
            ERC20Vault.BridgeTransferOp({
                destChainId: taikoChainId,
                destOwner: address(0),
                to: Alice,
                fee: 0,
                token: address(eUSDC),
                gasLimit: 1_000_000,
                amount: _amount
            })
        );

        vm.chainId(taikoChainId);
        vm.prank(Bob);
        tBridge.processMessage(message, hex"00");
    }

    function _canonicalL1USDC() private view returns (ERC20Vault.CanonicalERC20 memory canonical_) {
        canonical_ = ERC20Vault.CanonicalERC20({
            chainId: ethereumChainId,
            addr: address(eUSDC),
            decimals: 6,
            symbol: "USDC",
            name: "USD Coin"
        });
    }
}
