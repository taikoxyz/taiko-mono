// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { ISharedArtifactProbe } from "./ISharedArtifactProbe.sol";

contract SharedArtifactProbe is ISharedArtifactProbe {
    bytes32 private constant DOMAIN = keccak256("slot-chain-artifact-probe-v1");

    /// @inheritdoc ISharedArtifactProbe
    function artifactHash(bytes32 _value) external pure returns (bytes32 hash_) {
        return keccak256(abi.encodePacked(DOMAIN, _value));
    }
}
