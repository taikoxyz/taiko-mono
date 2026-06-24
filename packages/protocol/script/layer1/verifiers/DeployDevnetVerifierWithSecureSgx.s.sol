// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { console2 } from "forge-std/src/console2.sol";
import { BaseScript } from "script/BaseScript.sol";
import { DevnetVerifier } from "src/layer1/devnet/DevnetVerifier.sol";
import { SecureSgxVerifier } from "src/layer1/verifiers/SecureSgxVerifier.sol";

/// @title DeployDevnetVerifierWithSecureSgx
/// @notice Deploys two SecureSgxVerifier contracts and a DevnetVerifier composed from them.
/// @custom:security-contact security@taiko.xyz
contract DeployDevnetVerifierWithSecureSgx is BaseScript {
    struct DeploymentConfig {
        uint64 l2ChainId;
        address contractOwner;
        address sgxGethAutomataProxy;
        address sgxRethAutomataProxy;
        address sgxGethRegistrar;
        address sgxRethRegistrar;
    }

    // ---------------------------------------------------------------
    // External Functions
    // ---------------------------------------------------------------

    function run() external broadcast {
        DeploymentConfig memory config = _loadConfig();
        _validateConfig(config);

        address sgxGethVerifier = address(
            new SecureSgxVerifier(
                config.l2ChainId,
                config.contractOwner,
                config.sgxGethAutomataProxy,
                config.sgxGethRegistrar
            )
        );

        address sgxRethVerifier = address(
            new SecureSgxVerifier(
                config.l2ChainId,
                config.contractOwner,
                config.sgxRethAutomataProxy,
                config.sgxRethRegistrar
            )
        );

        address devnetVerifier =
            address(new DevnetVerifier(sgxGethVerifier, sgxRethVerifier, address(0), address(0)));

        console2.log("SGX_GETH_VERIFIER=", sgxGethVerifier);
        console2.log("SGX_RETH_VERIFIER=", sgxRethVerifier);
        console2.log("DEVNET_VERIFIER=", devnetVerifier);
        console2.log("RISC0_RETH_VERIFIER=", address(0));
        console2.log("SP1_RETH_VERIFIER=", address(0));
    }

    // ---------------------------------------------------------------
    // Private Functions
    // ---------------------------------------------------------------

    function _loadConfig() private view returns (DeploymentConfig memory config_) {
        config_.l2ChainId = uint64(vm.envUint("L2_CHAIN_ID"));
        config_.contractOwner = vm.envAddress("CONTRACT_OWNER");
        config_.sgxGethAutomataProxy = vm.envAddress("SGX_GETH_AUTOMATA_PROXY");
        config_.sgxRethAutomataProxy = vm.envAddress("SGX_RETH_AUTOMATA_PROXY");
        config_.sgxGethRegistrar = vm.envOr("SGX_GETH_REGISTRAR", address(0));
        config_.sgxRethRegistrar = vm.envOr("SGX_RETH_REGISTRAR", address(0));
    }

    function _validateConfig(DeploymentConfig memory _config) private pure {
        if (_config.l2ChainId == 0) revert L2ChainIdIsZero();
        if (_config.contractOwner == address(0)) revert ContractOwnerIsZero();
        if (_config.sgxGethAutomataProxy == address(0)) revert SgxGethAutomataProxyIsZero();
        if (_config.sgxRethAutomataProxy == address(0)) revert SgxRethAutomataProxyIsZero();
    }

    // ---------------------------------------------------------------
    // Custom Errors
    // ---------------------------------------------------------------

    error L2ChainIdIsZero();
    error ContractOwnerIsZero();
    error SgxGethAutomataProxyIsZero();
    error SgxRethAutomataProxyIsZero();
}
