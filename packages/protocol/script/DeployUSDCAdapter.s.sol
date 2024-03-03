// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../contracts/tokenvault/adapters/USDCAdapter.sol";
import "../contracts/tokenvault/ERC20Vault.sol";
import "../test/DeployCapability.sol";

/// @title DeployUSDCAdapter
/// @notice This script deploys the adapter contract for USDC.
contract DeployUSDCAdapter is DeployCapability {
    address public usdcProxyL2 = vm.envAddress("NATIVE_USDC_PROXY_ON_L2");
    address public usdcProxyL1 = vm.envAddress("NATIVE_USDC_PROXY_ON_L1");
    address public l2SharedAddressManager = vm.envAddress("L2_SHARED_ADDRESS_MANAGER");
    address public erc20Vault = vm.envAddress("ERC20_VAULT_ADDRESS");
    address public erc20VaultOwner = vm.envAddress("ERC20_VAULT_OWNER");

    uint256 public deployerPrivKey = vm.envUint("ADAPTOR_DEPLOYER_PRIVATE_KEY");
    uint256 public masterMinterPrivKey = vm.envUint("MASTER_MINTER_PRIVATE_KEY");

    uint256 public erc20VaultOwnerPrivKey = vm.envUint("ERC20_VAULT_OWNER_PRIVATE_KEY");

    // Fixed, not changed. (From circle contracts)
    // https://holesky.etherscan.io/tx/0xbfb68e7d92506498553e09ee22aba0adc23401108d508fc92f56da5e42ffc828
    bytes4 public configureMinterSelector = 0x4e44d956;

    error CANNOT_CONFIGURE_MINTER();
    error CANNOT_CHANGE_BRIDGED_TOKEN();

    function setUp() external { }

    function run() external {
        require(deployerPrivKey != 0, "invalid deplyoer priv key");
        require(masterMinterPrivKey != 0, "invalid master minter priv key");
        vm.startBroadcast(deployerPrivKey);
        // Verify this contract after deployment (!)
        address adapterProxy = deployProxy({
            name: "usdc_adapter",
            impl: address(new USDCAdapter()),
            data: abi.encodeCall(
                USDCAdapter.init, (address(0), l2SharedAddressManager, IUSDC(usdcProxyL2))
                )
        });

        USDCAdapter(adapterProxy).transferOwnership(erc20VaultOwner);

        vm.stopBroadcast();

        // Grant the adapter the minter role by master minter
        vm.startBroadcast(masterMinterPrivKey);
        (bool success, bytes memory retVal) = address(usdcProxyL2).call(
            abi.encodeWithSelector(configureMinterSelector, adapterProxy, type(uint256).max)
        );

        if (!success) {
            console2.log("Error is:");
            console2.logBytes(retVal);
            revert CANNOT_CONFIGURE_MINTER();
        }

        vm.stopBroadcast();

        vm.startBroadcast(erc20VaultOwnerPrivKey);
        ERC20Vault.CanonicalERC20 memory canonicalToken = ERC20Vault.CanonicalERC20({
            chainId: 17_000, // On mainnet, Ethereum chainID
            addr: usdcProxyL1, // On mainnet, USDC contract address
            decimals: 6,
            symbol: "USDC",
            name: "USD Coin"
        });

        (success, retVal) = erc20Vault.call(
            abi.encodeCall(ERC20Vault.changeBridgedToken, (canonicalToken, adapterProxy))
        );

        if (!success) {
            console2.log("Error is:");
            console2.logBytes(retVal);
            revert CANNOT_CHANGE_BRIDGED_TOKEN();
        }

        vm.stopBroadcast();
    }
}
