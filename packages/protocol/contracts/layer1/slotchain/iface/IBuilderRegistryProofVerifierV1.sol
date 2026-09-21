// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { IComponentConfigV2 } from "../../../shared/slotchain/iface/IComponentConfigV2.sol";

/// @title Slot Chain builder-registry proof verifier
/// @custom:security-contact security@taiko.xyz
interface IBuilderRegistryProofVerifierV1 is IComponentConfigV2 {
    /// @notice Returns the immutable proof-verifier schema and resource profile.
    /// @return magic_ The fixed `BPV1` magic.
    /// @return schema_ The fixed schema version one.
    /// @return registryLeaves_ The registry-tree leaf count.
    /// @return admissionUsedLeaves_ The writable admission-tree leaf count.
    /// @return admissionTreeLeaves_ The complete admission-tree leaf count.
    /// @return trancheLeaves_ The tranche-tree leaf count.
    /// @return registryDepth_ The registry-tree depth.
    /// @return admissionDepth_ The admission-tree depth.
    /// @return trancheDepth_ The tranche-tree depth.
    /// @return maximumTrancheBatch_ The maximum chained tranche transitions per call.
    /// @return identityCallGas_ The Registry stipend for identity verification.
    /// @return registryCallGas_ The Registry stipend for one registry replacement.
    /// @return admissionCallGas_ The Registry stipend for one admission replacement.
    /// @return trancheBatchCallGas_ The Registry stipend for a tranche batch.
    /// @return evidenceCallGas_ The Registry stipend for a complete evidence proof.
    /// @return configurationHash_ The exact verifier configuration commitment.
    function builderRegistryProofVerifierConfigV1()
        external
        pure
        returns (
            bytes4 magic_,
            uint8 schema_,
            uint16 registryLeaves_,
            uint16 admissionUsedLeaves_,
            uint16 admissionTreeLeaves_,
            uint16 trancheLeaves_,
            uint8 registryDepth_,
            uint8 admissionDepth_,
            uint8 trancheDepth_,
            uint8 maximumTrancheBatch_,
            uint32 identityCallGas_,
            uint32 registryCallGas_,
            uint32 admissionCallGas_,
            uint32 trancheBatchCallGas_,
            uint32 evidenceCallGas_,
            bytes32 configurationHash_
        );

    /// @notice Verifies the signature-bound identity of canonical equivocation evidence.
    /// @dev Both signed headers must carry `_expectedSettlementChainId`, a uint64 protocol
    ///      version, a nonzero pair-equal `l2ChainId` and a nonzero pair-equal verifying
    ///      contract. The returned identity commitment is
    ///      `H("slot-chain-builder-equivocation-identity-v2" || u16(224) ||
    ///      verifierConfigurationHash || evidenceHash || u256(expectedSettlementChainId) ||
    ///      u256(l2ChainId) || u64(protocolVersion) || address20(verifyingContract) ||
    ///      u64(window) || u64(signedAdmissionVersion) || signedAdmissionRoot ||
    ///      address20(builder))`; the caller must require every returned field, including
    ///      `l2ChainId_`, to equal its own pinned or prechecked values. The exact calldata is
    ///      2,468 bytes and the exact return is 352 bytes.
    /// @param _expectedSettlementChainId The Registry-authenticated settlement-chain identifier.
    /// @param _evidence The exact 2,366-byte canonical evidence payload.
    /// @return magic_ The fixed `EIV1` magic.
    /// @return verifierConfigurationHash_ The exact verifier configuration commitment.
    /// @return evidenceHash_ The Keccak-256 hash of `_evidence`.
    /// @return identityCommitment_ The complete evidence-identity commitment.
    /// @return builder_ The common nonzero recovered signer.
    /// @return window_ The signed slot divided by 384.
    /// @return protocolVersion_ The common uint64 protocol version.
    /// @return verifyingContract_ The common signed Settlement address.
    /// @return l2ChainId_ The common signed nonzero L2 chain identifier.
    /// @return signedAdmissionVersion_ The common signed admission version.
    /// @return signedAdmissionRoot_ The common signed admission root.
    function verifyBuilderEquivocationIdentityV1(
        uint256 _expectedSettlementChainId,
        bytes calldata _evidence
    )
        external
        pure
        returns (
            bytes4 magic_,
            bytes32 verifierConfigurationHash_,
            bytes32 evidenceHash_,
            bytes32 identityCommitment_,
            address builder_,
            uint64 window_,
            uint64 protocolVersion_,
            address verifyingContract_,
            uint256 l2ChainId_,
            uint64 signedAdmissionVersion_,
            bytes32 signedAdmissionRoot_
        );

    /// @notice Verifies one exact packed fixed-tree or equivocation proof request.
    /// @param _request The canonical `BPR1` proof request.
    /// @return magic_ The fixed `BPO1` magic.
    /// @return verifierConfigurationHash_ The exact verifier configuration commitment.
    /// @return requestCommitment_ The complete request commitment.
    /// @return newRegistryRoot_ The replacement Registry root, or zero when masked off.
    /// @return newAdmissionRoot_ The replacement admission root, or zero when masked off.
    /// @return newTrancheRoot_ The replacement tranche root, or zero when masked off.
    function verifyBuilderRegistryProofV1(bytes calldata _request)
        external
        pure
        returns (
            bytes4 magic_,
            bytes32 verifierConfigurationHash_,
            bytes32 requestCommitment_,
            bytes32 newRegistryRoot_,
            bytes32 newAdmissionRoot_,
            bytes32 newTrancheRoot_
        );
}
