// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Script } from "forge-std/src/Script.sol";
import { console2 } from "forge-std/src/console2.sol";

import { CircleArtifactDeployer } from "script/shared/circle/CircleArtifactDeployer.sol";
import { USDCFaucet } from "src/shared/faucet/USDCFaucet.sol";
import { ICircleFiatToken } from "src/shared/thirdparty/ICircleFiatToken.sol";

/// @title DeployHoodiL1USDC
/// @notice Deploys Circle-compatible USDC and the L1 faucet on Ethereum Hoodi.
/// @custom:security-contact security@taiko.xyz
contract DeployHoodiL1USDC is Script, CircleArtifactDeployer {
    string internal constant OUTPUT_PATH = "/deployments/hoodi-usdc-l1.json";

    uint256 internal _deployerPrivateKey;
    uint256 internal _usdcAdminPrivateKey;

    address internal _usdcAdmin;
    address internal _tokenOwner;
    address internal _pauser;
    address internal _blacklister;
    address internal _faucetOwner;

    uint256 internal _faucetClaimAmount;

    function setUp() public {
        _deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        _usdcAdminPrivateKey = vm.envUint("USDC_ADMIN_PRIVATE_KEY");

        _usdcAdmin = vm.envAddress("USDC_ADMIN");
        _tokenOwner = vm.envOr("USDC_OWNER", _usdcAdmin);
        _pauser = vm.envOr("USDC_PAUSER", _usdcAdmin);
        _blacklister = vm.envOr("USDC_BLACKLISTER", _usdcAdmin);
        _faucetOwner = vm.envOr("FAUCET_OWNER", _usdcAdmin);
        _faucetClaimAmount = vm.envUint("FAUCET_CLAIM_AMOUNT");
    }

    function run() external returns (address impl_, address proxy_, address faucet_) {
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
        faucet_ = address(new USDCFaucet(proxy_, _faucetOwner, _faucetClaimAmount));
        vm.stopBroadcast();

        vm.startBroadcast(_usdcAdminPrivateKey);
        ICircleFiatToken(proxy_).configureMinter(faucet_, type(uint256).max);
        vm.stopBroadcast();

        _writeDeployment(impl_, proxy_, faucet_);

        console2.log("L1 Hoodi USDC implementation:", impl_);
        console2.log("L1 Hoodi USDC proxy:", proxy_);
        console2.log("L1 Hoodi USDC faucet:", faucet_);
    }

    function _writeDeployment(address _impl, address _proxy, address _faucet) internal {
        string memory rootKey = "hoodi_l1_usdc";
        string memory output = vm.serializeAddress(rootKey, "implementation", _impl);
        output = vm.serializeAddress(rootKey, "proxy", _proxy);
        output = vm.serializeAddress(rootKey, "proxyAdmin", _proxyAdmin(_proxy));
        output =
            vm.serializeAddress(rootKey, "masterMinter", ICircleFiatToken(_proxy).masterMinter());
        output = vm.serializeAddress(rootKey, "owner", ICircleFiatToken(_proxy).owner());
        output = vm.serializeAddress(rootKey, "pauser", ICircleFiatToken(_proxy).pauser());
        output = vm.serializeAddress(rootKey, "blacklister", ICircleFiatToken(_proxy).blacklister());
        output = vm.serializeAddress(rootKey, "faucet", _faucet);
        output = vm.serializeUint(rootKey, "faucetClaimAmount", _faucetClaimAmount);
        vm.writeJson(output, string.concat(vm.projectRoot(), OUTPUT_PATH));
    }
}
