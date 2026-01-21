// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { MainnetInbox } from "src/layer1/mainnet/MainnetInbox.sol";
import { Inbox } from "src/layer1/core/impl/Inbox.sol";
import { CommonVerifier } from "src/layer1/verifiers/CommonVerifier.sol";
import { SignalServiceForkRouter } from "src/shared/signal/SignalServiceForkRouter.sol";
import { ProverWhitelist } from "src/layer1/core/impl/ProverWhitelist.sol";
import "src/layer1/preconf/impl/PreconfWhitelist.sol";
import "src/layer1/verifiers/Risc0Verifier.sol";
import "src/layer1/verifiers/SP1Verifier.sol";
import "src/layer1/verifiers/SgxVerifier.sol";
import "src/shared/signal/SignalService.sol";
import "test/shared/DeployCapability.sol";

/// @title DeployShastaContracts
/// @notice Base contract for deploying Shasta contracts with configurable parameters.
abstract contract DeployShastaContracts is DeployCapability {
    struct VerifierAddresses {
        address sgxReth;
        address risc0;
        address sp1;
        address sgxGeth;
    }

    struct DeploymentConfig {
        address contractOwner;
        uint64 l2ChainId;
        address l1SignalService;
        address l2SignalService;
        address taikoToken;
        address sgxAutomataProxy;
        address sgxGethAutomataProxy;
        address r0Groth16Verifier;
        address sp1PlonkVerifier;
        address[] provers;
        address oldSignalServiceImpl;
        uint64 shastaForkTimestamp;
        address preconfWhitelist;
    }

    modifier broadcast() {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        require(privateKey != 0, "PRIVATE_KEY not set or invalid");
        vm.startBroadcast();
        _;
        vm.stopBroadcast();
    }

    function run() external broadcast {
        DeploymentConfig memory config = _loadConfig();
        _validateConfig(config);
        _deploy(config);
    }

    /// @dev Override this function to provide deployment configuration.
    function _loadConfig() internal virtual returns (DeploymentConfig memory config);

    function _validateConfig(DeploymentConfig memory config) internal pure {
        require(config.contractOwner != address(0), "CONTRACT_OWNER not set");
        require(config.l2ChainId != 0, "L2_CHAIN_ID not set");
        require(config.l1SignalService != address(0), "L1_SIGNAL_SERVICE not set");
        require(config.l2SignalService != address(0), "L2_SIGNAL_SERVICE not set");
        require(config.taikoToken != address(0), "TAIKO_TOKEN not set");
        require(config.sgxAutomataProxy != address(0), "SGX_AUTOMATA_PROXY not set");
        require(config.sgxGethAutomataProxy != address(0), "SGX_GETH_AUTOMATA_PROXY not set");
        require(config.r0Groth16Verifier != address(0), "R0_GROTH16_VERIFIER not set");
        require(config.sp1PlonkVerifier != address(0), "SP1_PLONK_VERIFIER not set");
        require(config.provers.length != 0, "PROVERS not set");
        require(config.oldSignalServiceImpl != address(0), "OLD_SIGNAL_SERVICE_IMPL not set");
        require(config.shastaForkTimestamp != 0, "SHASTA_FORK_TIMESTAMP not set");
        require(config.preconfWhitelist != address(0), "PRECONF_WHITELIST not set");

        for (uint256 i = 0; i < config.provers.length; ++i) {
            require(config.provers[i] != address(0), "PROVERS contains zero address");
        }
    }

    function _deploy(DeploymentConfig memory config) internal {
        VerifierAddresses memory verifiers = _deployAllVerifiers(config);

        address proofVerifier = address(
            new CommonVerifier(verifiers.sgxGeth, verifiers.sgxReth, verifiers.risc0, verifiers.sp1)
        );
        console2.log("CommonVerifier deployed:", proofVerifier);

        address preconfWhitelist = address(new PreconfWhitelist());
        console2.log("PreconfWhitelist deployed:", preconfWhitelist);

        address proverWhitelist = deployProxy({
            name: "prover_whitelist",
            impl: address(new ProverWhitelist()),
            data: abi.encodeCall(ProverWhitelist.init, address(0))
        });
        console2.log("ProverWhitelist deployed:", proverWhitelist);

        for (uint256 i = 0; i < config.provers.length; ++i) {
            console2.log("Add prover into ProverWhitelist:", config.provers[i]);
            ProverWhitelist(proverWhitelist).whitelistProver(config.provers[i], true);
        }
        Ownable2StepUpgradeable(proverWhitelist).transferOwnership(config.contractOwner);

        address shastaInbox = deployProxy({
            name: "shasta_inbox",
            impl: address(
                new MainnetInbox(
                    proofVerifier,
                    config.preconfWhitelist,
                    proverWhitelist,
                    config.l1SignalService,
                    config.taikoToken
                )
            ),
            data: abi.encodeCall(Inbox.init, config.contractOwner)
        });
        console2.log("ShastaInbox deployed:", shastaInbox);

        address signalServiceImpl = address(new SignalService(shastaInbox, config.l2SignalService));
        address signalServiceForkRouter = address(
            new SignalServiceForkRouter(
                config.oldSignalServiceImpl, signalServiceImpl, config.shastaForkTimestamp
            )
        );
        console2.log("SignalServiceForkRouter deployed:", signalServiceForkRouter);
    }

    function _deployAllVerifiers(DeploymentConfig memory config)
        private
        returns (VerifierAddresses memory verifiers)
    {
        verifiers.sgxReth = address(
            new SgxVerifier(config.l2ChainId, config.contractOwner, config.sgxAutomataProxy)
        );
        console2.log("SgxVerifier deployed:", verifiers.sgxReth);

        verifiers.sgxGeth = address(
            new SgxVerifier(config.l2ChainId, config.contractOwner, config.sgxGethAutomataProxy)
        );
        console2.log("SgxGethVerifier deployed:", verifiers.sgxGeth);

        (verifiers.risc0, verifiers.sp1) = _deployZKVerifiers(config);
    }

    function _deployZKVerifiers(DeploymentConfig memory config)
        private
        returns (address risc0Verifier, address sp1Verifier)
    {
        risc0Verifier = address(
            new Risc0Verifier(config.l2ChainId, config.r0Groth16Verifier, config.contractOwner)
        );
        console2.log("Risc0Verifier deployed:", risc0Verifier);

        sp1Verifier = address(
            new SP1Verifier(config.l2ChainId, config.sp1PlonkVerifier, config.contractOwner)
        );
        console2.log("SP1Verifier deployed:", sp1Verifier);
    }
}
