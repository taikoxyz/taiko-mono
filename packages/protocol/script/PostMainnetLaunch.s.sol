// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/src/Script.sol";
import "forge-std/src/console2.sol";

import "../contracts/tokenvault/ERC20Vault.sol";
import "../contracts/bridge/Bridge.sol";

contract PostMainnetLaunch is Script {
    // All following addresses are L2 addresses
    address public bridgedTKO = address(0); // TODO
    address public bridgedUSDC = address(0); // TODO

    address public erc20Vault = 0x1670000000000000000000000000000000000002;
    address public bridge = 0x1670000000000000000000000000000000000001;

    function run() external {
        ERC20Vault.CanonicalERC20 memory canonical;
        canonical.chainId = 1;

        canonical.addr = 0x10dea67478c5F8C5E2D90e5E9B26dBe60c54d800;
        canonical.decimals = 18;
        canonical.symbol = "TKO";
        canonical.name = "Taiko Token";

        // ERC20Vault(erc20Vault).changeBridgedToken(canonical, bridgedTKO);
        bytes memory call = abi.encodeCall(ERC20Vault.changeBridgedToken, (canonical, bridgedTKO));

        console2.log(erc20Vault);
        console.logBytes(call);

        canonical.addr = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        canonical.decimals = 6;
        canonical.symbol = "USDC";
        canonical.name = "USD Coin";
        // ERC20Vault(erc20Vault).changeBridgedToken(canonical, bridgedUSDC);
        call = abi.encodeCall(ERC20Vault.changeBridgedToken, (canonical, bridgedUSDC));
        console2.log(erc20Vault);
        console.logBytes(call);

        // Bridge(bridge).unpause();
        call = abi.encodeCall(EssentialContract.unpause, ());
        console2.log(bridge);
        console.logBytes(call);
    }
}
