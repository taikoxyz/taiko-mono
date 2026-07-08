// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { DeployProofStack } from "./DeployProofStack.s.sol";
import { LibL1HoodiAddrs } from "src/layer1/hoodi/LibL1HoodiAddrs.sol";
import { LibNetwork } from "src/shared/libs/LibNetwork.sol";

/// @title DeployHoodiProofStack
/// @notice Deploys the Ethereum Hoodi proof-verification stack (see DeployProofStack) wired to a
/// pre-deployed Taiko-owned AutomataDcapAttestationFee entrypoint (env `DCAP_ATTESTATION`).
/// @custom:security-contact security@taiko.xyz
contract DeployHoodiProofStack is DeployProofStack {
    /// @dev Returns the Ethereum Hoodi verifier dimensions (mirrors DeployShastaHoodi).
    /// @return The Hoodi Config.
    function _config() internal pure override returns (Config memory) {
        return Config({
            chainId: LibNetwork.TAIKO_HOODI,
            owner: LibL1HoodiAddrs.HOODI_CONTRACT_OWNER,
            validityDelay: 1 hours,
            r0Groth16: 0x32Db7dc407AC886807277636a1633A1381748DD8,
            sp1Plonk: 0x2a5A70409Ee9F057503a50E0F4614A6d8CcBb462
        });
    }
}
