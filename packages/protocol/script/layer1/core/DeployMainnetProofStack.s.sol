// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { DeployProofStack } from "./DeployProofStack.s.sol";
import { LibL1Addrs } from "src/layer1/mainnet/LibL1Addrs.sol";
import { LibNetwork } from "src/shared/libs/LibNetwork.sol";

/// @title DeployMainnetProofStack
/// @notice Deploys the Ethereum Mainnet proof-verification stack (see DeployProofStack) wired to a
/// pre-deployed Taiko-owned AutomataDcapAttestationFee entrypoint (env `DCAP_ATTESTATION`).
/// @custom:security-contact security@taiko.xyz
contract DeployMainnetProofStack is DeployProofStack {
    /// @dev Returns the Ethereum Mainnet verifier dimensions. Unlike DeployShastaMainnet, the R0/SP1
    /// verifiers default to fresh deploys (`address(0)`); override with the R0_GROTH16 / SP1_PLONK
    /// env to reuse the live mainnet verifiers (0x8EaB2D97… / 0x3B604117…).
    /// @return The Mainnet Config.
    function _config() internal pure override returns (Config memory) {
        return Config({
            chainId: LibNetwork.TAIKO_MAINNET,
            owner: LibL1Addrs.DAO_CONTROLLER,
            validityDelay: 24 hours,
            r0Groth16: address(0),
            sp1Plonk: address(0)
        });
    }
}
