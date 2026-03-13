// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Script } from "forge-std/src/Script.sol";
import { console2 } from "forge-std/src/console2.sol";

import { LibL2HoodiAddrs } from "src/layer2/hoodi/LibL2HoodiAddrs.sol";
import { ERC20Vault } from "src/shared/vault/ERC20Vault.sol";
import { LibNetwork } from "src/shared/libs/LibNetwork.sol";
import { ICircleFiatToken } from "src/shared/thirdparty/ICircleFiatToken.sol";
import { CircleArtifactDeployer } from "script/shared/circle/CircleArtifactDeployer.sol";

/// @title ValidateHoodiL2USDC
/// @notice Verifies Taiko Hoodi native USDC deployment state and optional canonical mapping.
/// @custom:security-contact security@taiko.xyz
contract ValidateHoodiL2USDC is Script, CircleArtifactDeployer {
    address internal _usdcToken;
    address internal _usdcAdmin;
    address internal _tokenOwner;
    address internal _pauser;
    address internal _blacklister;
    address internal _erc20Vault;
    address internal _l1UsdcToken;
    address internal _expectedBridgedToken;

    function setUp() public {
        _usdcToken = vm.envAddress("L2_USDC_TOKEN");
        _usdcAdmin = vm.envAddress("USDC_ADMIN");
        _tokenOwner = vm.envOr("USDC_OWNER", _usdcAdmin);
        _pauser = vm.envOr("USDC_PAUSER", _usdcAdmin);
        _blacklister = vm.envOr("USDC_BLACKLISTER", _usdcAdmin);
        _erc20Vault = vm.envOr("ERC20_VAULT_ADDRESS", LibL2HoodiAddrs.HOODI_ERC20_VAULT);
        _l1UsdcToken = vm.envOr("L1_USDC_TOKEN", address(0));
        _expectedBridgedToken = vm.envOr("EXPECTED_BRIDGED_TOKEN", address(0));
    }

    function run() external view {
        ICircleFiatToken token = ICircleFiatToken(_usdcToken);
        ERC20Vault vault = ERC20Vault(payable(_erc20Vault));
        address implementation = _proxyImplementation(_usdcToken);

        require(_proxyAdmin(_usdcToken) == _usdcAdmin, "invalid proxy admin");
        require(implementation != address(0), "missing implementation");
        require(keccak256(bytes(token.name())) == keccak256(bytes("USD Coin")), "invalid name");
        require(keccak256(bytes(token.symbol())) == keccak256(bytes("USDC")), "invalid symbol");
        require(token.decimals() == 6, "invalid decimals");
        require(token.masterMinter() == _usdcAdmin, "invalid master minter");
        require(token.owner() == _tokenOwner, "invalid owner");
        require(token.pauser() == _pauser, "invalid pauser");
        require(token.blacklister() == _blacklister, "invalid blacklister");
        require(token.isMinter(_erc20Vault), "vault is not a minter");
        require(token.minterAllowance(_erc20Vault) > 0, "missing vault allowance");

        if (_l1UsdcToken != address(0)) {
            address currentBridgedToken =
                vault.canonicalToBridged(LibNetwork.ETHEREUM_HOODI, _l1UsdcToken);
            require(currentBridgedToken == _expectedBridgedToken, "invalid canonical mapping");
        }

        console2.log("Validated L2 Hoodi USDC proxy:", _usdcToken);
        console2.log("Validated L2 Hoodi USDC implementation:", implementation);
        console2.log("Validated L2 Hoodi ERC20 vault minter:", _erc20Vault);
    }
}
