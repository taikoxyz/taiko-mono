// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @title Slot Chain current-fork schedule-carrier verifier
/// @custom:security-contact security@taiko.xyz
interface IScheduleForkVerifierV1 {
    /// @notice Returns the complete immutable fork-verifier configuration.
    /// @return magic_ The fixed `SFV1` response magic.
    /// @return forkDigest_ The configured L1 fork digest.
    /// @return beaconSlotGindex_ The BeaconBlock slot generalized index.
    /// @return executionPayloadGindex_ The execution-payload generalized index.
    /// @return stateRootGindex_ The payload state-root generalized index.
    /// @return prevRandaoGindex_ The payload prevRandao generalized index.
    /// @return timestampGindex_ The payload timestamp generalized index.
    /// @return blockHashGindex_ The payload block-hash generalized index.
    /// @return witnessSchemaHash_ The exact current-fork witness schema hash.
    /// @return configurationHash_ The immutable verifier configuration hash.
    function scheduleForkVerifierConfigV1()
        external
        view
        returns (
            bytes4 magic_,
            bytes4 forkDigest_,
            uint64 beaconSlotGindex_,
            uint64 executionPayloadGindex_,
            uint64 stateRootGindex_,
            uint64 prevRandaoGindex_,
            uint64 timestampGindex_,
            uint64 blockHashGindex_,
            bytes32 witnessSchemaHash_,
            bytes32 configurationHash_
        );

    /// @notice Verifies the exact current-fork SSZ multiproof against a beacon-block root.
    /// @dev The statement binds `block.chainid`, `msg.sender`, the configured fork digest, and every
    ///      returned carrier field. Calldata must use its sole canonical ABI encoding.
    /// @param _witness The exact 672-byte `ScheduleSszMultiproofV1` witness.
    /// @param _beaconBlockRoot The nonzero EIP-4788 parent beacon-block root.
    /// @return magic_ The fixed `SFC1` response magic.
    /// @return statementHash_ The exact verified carrier-statement hash.
    /// @return parentSlot_ The authenticated parent beacon slot.
    /// @return executionBlockNumber_ The context-bound carrier execution-block number.
    /// @return payloadTimestamp_ The authenticated parent payload timestamp.
    /// @return blockHash_ The authenticated parent payload block hash.
    /// @return stateRoot_ The authenticated parent payload state root.
    /// @return prevRandao_ The authenticated parent payload prevRandao.
    function verifyScheduleCarrierV1(
        bytes calldata _witness,
        bytes32 _beaconBlockRoot
    )
        external
        view
        returns (
            bytes4 magic_,
            bytes32 statementHash_,
            uint64 parentSlot_,
            uint64 executionBlockNumber_,
            uint64 payloadTimestamp_,
            bytes32 blockHash_,
            bytes32 stateRoot_,
            bytes32 prevRandao_
        );
}
