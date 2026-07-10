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
    /// @dev Returns the Ethereum Mainnet verifier dimensions (mirrors DeployShastaMainnet). The
    /// R0/SP1 verifiers reference the live mainnet deployments, whose proving keys the mainnet raiko
    /// provers already target; set R0_GROTH16 / SP1_PLONK to `address(0)` to deploy fresh ones.
    /// @return The Mainnet Config.
    function _config() internal pure override returns (Config memory) {
        return Config({
            chainId: LibNetwork.TAIKO_MAINNET,
            owner: LibL1Addrs.DAO_CONTROLLER,
            validityDelay: 24 hours,
            r0Groth16: 0x8EaB2D97Dfce405A1692a21b3ff3A172d593D319,
            sp1Plonk: 0x3B6041173B80E77f038f3F2C0f9744f04837185e
        });
    }
}
