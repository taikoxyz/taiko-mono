// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Script } from "forge-std/src/Script.sol";
import { console2 } from "forge-std/src/console2.sol";

import { CircleArtifactDeployer } from "script/shared/circle/CircleArtifactDeployer.sol";
import { LibL2HoodiAddrs } from "src/layer2/hoodi/LibL2HoodiAddrs.sol";
import { ICircleFiatToken } from "src/shared/thirdparty/ICircleFiatToken.sol";

/// @title DeployHoodiL2USDC
/// @notice Deploys Circle-compatible native USDC on Taiko Hoodi and configures the ERC20 vault as
/// its bridge minter.
/// @custom:security-contact security@taiko.xyz
contract DeployHoodiL2USDC is Script, CircleArtifactDeployer {
    string internal constant OUTPUT_PATH = "/deployments/hoodi-usdc-l2.json";

    uint256 internal _deployerPrivateKey;
    uint256 internal _usdcAdminPrivateKey;

    address internal _usdcAdmin;
    address internal _tokenOwner;
    address internal _pauser;
    address internal _blacklister;
    address internal _erc20Vault;

    function setUp() public {
        _deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        _usdcAdminPrivateKey = vm.envUint("USDC_ADMIN_PRIVATE_KEY");

        _usdcAdmin = vm.envAddress("USDC_ADMIN");
        _tokenOwner = vm.envOr("USDC_OWNER", _usdcAdmin);
        _pauser = vm.envOr("USDC_PAUSER", _usdcAdmin);
        _blacklister = vm.envOr("USDC_BLACKLISTER", _usdcAdmin);
        _erc20Vault = vm.envOr("ERC20_VAULT_ADDRESS", LibL2HoodiAddrs.HOODI_ERC20_VAULT);
    }

    function run() external returns (address impl_, address proxy_) {
        FiatTokenDeploymentConfig memory config = FiatTokenDeploymentConfig({
            tokenName: "USD Coin",
            tokenSymbol: "USDC",
            tokenCurrency: "USD",
            tokenDecimals: 6,
            proxyAdmin: _usdcAdmin,
            masterMinter: _usdcAdmin,
            pauser: _pauser,
            blacklister: _blacklister,
            owner: _tokenOwner
        });

        vm.startBroadcast(_deployerPrivateKey);
        (impl_, proxy_) = _deployFiatToken(config);
        vm.stopBroadcast();

        vm.startBroadcast(_usdcAdminPrivateKey);
        ICircleFiatToken(proxy_).configureMinter(_erc20Vault, type(uint256).max);
        vm.stopBroadcast();

        _writeDeployment(impl_, proxy_);

        console2.log("L2 Hoodi USDC implementation:", impl_);
        console2.log("L2 Hoodi USDC proxy:", proxy_);
        console2.log("L2 Hoodi ERC20 vault minter:", _erc20Vault);
    }

    function _writeDeployment(address _impl, address _proxy) internal {
        string memory rootKey = "hoodi_l2_usdc";
        string memory output = vm.serializeAddress(rootKey, "implementation", _impl);
        output = vm.serializeAddress(rootKey, "proxy", _proxy);
        output = vm.serializeAddress(rootKey, "proxyAdmin", _proxyAdmin(_proxy));
        output =
            vm.serializeAddress(rootKey, "masterMinter", ICircleFiatToken(_proxy).masterMinter());
        output = vm.serializeAddress(rootKey, "owner", ICircleFiatToken(_proxy).owner());
        output = vm.serializeAddress(rootKey, "pauser", ICircleFiatToken(_proxy).pauser());
        output = vm.serializeAddress(rootKey, "blacklister", ICircleFiatToken(_proxy).blacklister());
        output = vm.serializeAddress(rootKey, "erc20Vault", _erc20Vault);
        output = vm.serializeUint(
            rootKey,
            "erc20VaultMinterAllowance",
            ICircleFiatToken(_proxy).minterAllowance(_erc20Vault)
        );
        vm.writeJson(output, string.concat(vm.projectRoot(), OUTPUT_PATH));
    }
}
