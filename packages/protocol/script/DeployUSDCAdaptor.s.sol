// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/
//
//   Email: security@taiko.xyz
//   Website: https://taiko.xyz
//   GitHub: https://github.com/taikoxyz
//   Discord: https://discord.gg/taikoxyz
//   Twitter: https://twitter.com/taikoxyz
//   Blog: https://mirror.xyz/labs.taiko.eth
//   Youtube: https://www.youtube.com/@taikoxyz

pragma solidity 0.8.20;

import "../contracts/tokenvault/adaptors/USDCAdaptor.sol";
import "../contracts/tokenvault/ERC20Vault.sol";
import "../test/DeployCapability.sol";

/// @title DeployUSDCAdaptor
/// @notice This script deploys the adaptor contract for USDC.
contract DeployUSDCAdaptor is DeployCapability {
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
        address adaptorProxy = deployProxy({
            name: "usdc_adaptor",
            impl: address(new USDCAdaptor()),
            data: abi.encodeCall(USDCAdaptor.init, (l2SharedAddressManager, IUSDC(usdcProxyL2)))
        });

        USDCAdaptor(adaptorProxy).transferOwnership(erc20VaultOwner);

        vm.stopBroadcast();

        // Grant the adaptor the minter role by master minter
        vm.startBroadcast(masterMinterPrivKey);
        (bool success, bytes memory retVal) = address(usdcProxyL2).call(
            abi.encodeWithSelector(configureMinterSelector, adaptorProxy, type(uint256).max)
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
            abi.encodeWithSelector(
                ERC20Vault.changeBridgedToken.selector, canonicalToken, adaptorProxy
            )
        );

        if (!success) {
            console2.log("Error is:");
            console2.logBytes(retVal);
            revert CANNOT_CHANGE_BRIDGED_TOKEN();
        }

        vm.stopBroadcast();
    }
}
