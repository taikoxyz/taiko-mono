// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Script } from "forge-std/src/Script.sol";
import { console2 } from "forge-std/src/console2.sol";

import { CircleArtifactDeployer } from "script/shared/circle/CircleArtifactDeployer.sol";
import { USDCFaucet } from "src/shared/faucet/USDCFaucet.sol";
import { ICircleFiatToken } from "src/shared/thirdparty/ICircleFiatToken.sol";

/// @title ValidateHoodiL1USDC
/// @notice Verifies Ethereum Hoodi USDC and faucet deployment state on a fork.
/// @custom:security-contact security@taiko.xyz
contract ValidateHoodiL1USDC is Script, CircleArtifactDeployer {
    address internal _usdcToken;
    address internal _proxyAdminAddress;
    address internal _usdcAdmin;
    address internal _tokenOwner;
    address internal _pauser;
    address internal _blacklister;
    address internal _faucet;
    address internal _faucetOwner;
    uint256 internal _faucetClaimAmount;

    function setUp() public {
        _usdcToken = vm.envAddress("L1_USDC_TOKEN");
        _usdcAdmin = vm.envAddress("USDC_ADMIN");
        _proxyAdminAddress = vm.envOr("USDC_PROXY_ADMIN", _usdcAdmin);
        _tokenOwner = vm.envOr("USDC_OWNER", _usdcAdmin);
        _pauser = vm.envOr("USDC_PAUSER", _usdcAdmin);
        _blacklister = vm.envOr("USDC_BLACKLISTER", _usdcAdmin);
        _faucet = vm.envAddress("L1_USDC_FAUCET");
        _faucetOwner = vm.envOr("FAUCET_OWNER", _usdcAdmin);
        _faucetClaimAmount = vm.envUint("FAUCET_CLAIM_AMOUNT");
    }

    function run() external view {
        ICircleFiatToken token = ICircleFiatToken(_usdcToken);
        USDCFaucet faucet = USDCFaucet(_faucet);
        address implementation = _proxyImplementation(_usdcToken);

        require(_proxyAdmin(_usdcToken) == _proxyAdminAddress, "invalid proxy admin");
        require(implementation != address(0), "missing implementation");
        require(keccak256(bytes(token.name())) == keccak256(bytes("USD Coin")), "invalid name");
        require(keccak256(bytes(token.symbol())) == keccak256(bytes("USDC")), "invalid symbol");
        require(token.decimals() == 6, "invalid decimals");
        require(token.masterMinter() == _usdcAdmin, "invalid master minter");
        require(token.owner() == _tokenOwner, "invalid owner");
        require(token.pauser() == _pauser, "invalid pauser");
        require(token.blacklister() == _blacklister, "invalid blacklister");
        require(faucet.token() == _usdcToken, "invalid faucet token");
        require(faucet.owner() == _faucetOwner, "invalid faucet owner");
        require(faucet.claimAmount() == _faucetClaimAmount, "invalid faucet claim amount");
        require(token.isMinter(_faucet), "faucet is not a minter");
        require(
            token.minterAllowance(_faucet) >= _faucetClaimAmount, "insufficient faucet allowance"
        );

        console2.log("Validated L1 Hoodi USDC proxy:", _usdcToken);
        console2.log("Validated L1 Hoodi USDC implementation:", implementation);
        console2.log("Validated L1 Hoodi USDC faucet:", _faucet);
    }
}
