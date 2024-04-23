// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../test/DeployCapability.sol";
import "../contracts/tokenvault/ERC20Vault.sol";

/// @dev This script shall be run on Taiko chain to hook up a native USDC deployment and the USDC
/// deployed on layer 1.
///
/// To deploy a native USDC contract on L2, run:
/// https://github.com/taikoxyz/USDC/blob/main/script/DeployUSDC.s.sol
contract SetupUSDCBridging is DeployCapability {
    address public constant USDC_ON_ETHEREUM = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    uint256 public privateKey = vm.envUint("PRIVATE_KEY");
    address public erc20VaultOnL2 = vm.envAddress("ERC20_VAULT_ON_L2");

    // These are FiatTokenProxy addresses of the USDC coin.
    address public usdcOnL1 = vm.envAddress("USDC_ADDRESS_ON_L1");
    address public usdcOnL2 = vm.envAddress("USDC_ADDRESS_ON_L2");

    function run() external {
        require(erc20VaultOnL2 != address(0) && usdcOnL2 != address(0), "invalid params");

        if (usdcOnL1 == address(0)) {
            usdcOnL1 = USDC_ON_ETHEREUM;
        }

        ERC20Vault vault = ERC20Vault(erc20VaultOnL2);

        address currBridgedtoken = vault.canonicalToBridged(1, usdcOnL1);
        console2.log("current btoken for usdc:", currBridgedtoken);

        vm.startBroadcast(privateKey);
        vault.changeBridgedToken(
            ERC20Vault.CanonicalERC20({
                chainId: 1,
                addr: usdcOnL1,
                decimals: 6,
                symbol: "USDC",
                name: "USD Coin"
            }),
            usdcOnL2
        );
        if (vault.paused()) {
            vault.unpause();
        }
        vm.stopBroadcast();

        address newBridgedToken = vault.canonicalToBridged(1, usdcOnL1);
        console2.log("new btoken for usdc:", newBridgedToken);

        require(usdcOnL2 == newBridgedToken, "unexpected result");
    }
}
