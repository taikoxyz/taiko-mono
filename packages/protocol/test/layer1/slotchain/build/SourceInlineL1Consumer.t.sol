// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/src/Test.sol";
import { ISharedArtifactProbe } from "test/shared/slotchain/fixtures/ISharedArtifactProbe.sol";
import { LibSourceInlineProbe } from "test/shared/slotchain/fixtures/LibSourceInlineProbe.sol";

contract SourceInlineL1ConsumerTest is Test {
    /// @notice Verifies L1 source-inline compilation and shared owner-bytecode consumption.
    function test_sourceInlineAndOwnerBytecodeConsumption() external {
        bytes32 value = keccak256("l1-probe-value");
        assertEq(
            LibSourceInlineProbe.hash(value, 1),
            keccak256(
                abi.encodePacked(keccak256("slot-chain-source-inline-probe-v1"), uint64(1), value)
            )
        );

        ISharedArtifactProbe probe = _deployOwnerArtifact();
        assertEq(
            probe.artifactHash(value),
            keccak256(abi.encodePacked(keccak256("slot-chain-artifact-probe-v1"), value))
        );
    }

    /// @dev Deploys the shared-profile artifact without compiling its implementation in L1.
    /// @return probe_ Interface to the deployed owner artifact.
    function _deployOwnerArtifact() private returns (ISharedArtifactProbe probe_) {
        bytes memory creationCode =
            vm.getCode("out/shared/SharedArtifactProbe.sol/SharedArtifactProbe.json");
        address deployed;
        assembly {
            deployed := create(0, add(creationCode, 0x20), mload(creationCode))
        }
        assertTrue(deployed != address(0));
        probe_ = ISharedArtifactProbe(deployed);
    }
}
