// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { IComponentConfigV2 } from "../../../shared/slotchain/iface/IComponentConfigV2.sol";

/// @title Slot Chain builder registry
/// @custom:security-contact security@taiko.xyz
interface IBuilderRegistry is IComponentConfigV2 {
    /// @notice One immutable reward-class row committed by the registry economic configuration.
    struct BuilderRewardClassConfigV1 {
        uint8 classId;
        bytes32 nameHash;
        uint256 fixedWei;
        uint256 perExecutionGasWei;
        uint256 perPublishedByteWei;
        uint256 capWei;
    }

    /// @notice Exact static constructor tuple for one BuilderRegistry deployment: 43 static
    ///         words that follow the pinned activator word, so the complete constructor
    ///         encoding is 44 words (1,408 bytes) with no dynamic offset or suffix.
    /// @dev `settlement` is the existing L1 Inbox proxy whose implementation is the Settlement
    ///      and `scheduleOracle` is the ScheduleOracle proxy; both are pinned by address only.
    ///      `l2ChainId` is the EVM chain identifier of the L2 whose builder headers this
    ///      Registry may slash; equivocation evidence signed for any other L2 chain rejects.
    struct BuilderRegistryConstructorV1 {
        uint256 settlementChainId;
        uint256 l2ChainId;
        address builderLeaseToken;
        bytes32 builderLeaseTokenRuntimeHash;
        uint8 builderLeaseTokenDecimals;
        uint192 leasePerWindowAtomic;
        uint192 maximumBondAtomic;
        uint192 reporterRewardCapAtomic;
        uint64 genesisTimestamp;
        uint64 evidenceDelaySeconds;
        uint64 reorgMarginSeconds;
        uint64 firstManagedWindow;
        address builderPenaltySink;
        uint64 rewardClaimWindowSeconds;
        address settlement;
        address scheduleOracle;
        address builderProofVerifier;
        bytes32 builderProofVerifierRuntimeHash;
        bytes32 builderProofVerifierConfigurationHash;
        address seatLifecycleFacet;
        bytes32 seatLifecycleFacetRuntimeHash;
        bytes32 seatLifecycleFacetConfigurationHash;
        address leaseLifecycleFacet;
        bytes32 leaseLifecycleFacetRuntimeHash;
        bytes32 leaseLifecycleFacetConfigurationHash;
        BuilderRewardClassConfigV1[3] rewardClasses;
    }

    event BuilderRegistered(
        address indexed builder,
        uint64 indexed registrationIndex,
        uint8 activeIndex,
        uint192 baseBondAtomic,
        uint64 effectiveL2Slot
    );
    event BuilderWindowReserved(
        address indexed builder, uint64 indexed registrationIndex, uint64 indexed window
    );
    event BuilderExitRequested(
        address indexed builder,
        uint64 indexed registrationIndex,
        uint64 requestWindow,
        uint64 matureWindow,
        uint64 exitSequence
    );
    event BuilderGenerationMoved(
        address indexed builder,
        uint64 indexed registrationIndex,
        uint8 indexed formerActiveIndex,
        uint16 liabilityPosition,
        uint64 movementSequence
    );
    event BuilderTrancheReleased(
        address indexed builder,
        uint64 indexed registrationIndex,
        uint64 indexed window,
        uint256 amount
    );
    event BuilderGenerationReleased(
        address indexed builder, uint64 indexed registrationIndex, uint256 baseBondAtomic
    );
    event BuilderEquivocationSubmitted(
        address indexed builder,
        uint64 indexed registrationIndex,
        uint64 indexed window,
        address reporter,
        uint256 reporterAmount,
        uint256 penaltyAmount
    );
    event BuilderLeaseCreditClaimed(
        address indexed owner, address indexed recipient, uint256 amount
    );

    /// @notice Returns the immutable deployment and topology row (`BRC1`, exactly 768 bytes).
    /// @dev Readable before activation. The row deliberately repeats neither the reward-class
    ///      rows nor the six lifecycle-facet topology words; the deployment review checks those
    ///      from the constructor preimage.
    /// @return magic_ The fixed `BRC1` magic.
    /// @return settlementChainId_ The settlement-chain identifier.
    /// @return l2ChainId_ The pinned L2 chain identifier bound by equivocation evidence.
    /// @return builderLeaseToken_ The immutable exact-balance builder token.
    /// @return builderLeaseTokenRuntimeHash_ The pinned token runtime hash.
    /// @return builderLeaseTokenDecimals_ The token's pinned decimal count.
    /// @return leasePerWindowAtomic_ The exact independently escrowed window lease.
    /// @return maximumBondAtomic_ The inclusive maximum registration bond.
    /// @return reporterRewardCapAtomic_ The cap paid to one evidence reporter.
    /// @return genesisTimestamp_ The L2 slot-zero timestamp.
    /// @return evidenceDelaySeconds_ The evidence submission delay.
    /// @return reorgMarginSeconds_ The evidence replay margin.
    /// @return firstManagedWindow_ The first managed schedule window.
    /// @return lastManagedWindow_ The derived final managed schedule window.
    /// @return builderPenaltySink_ The immutable slash-penalty beneficiary.
    /// @return rewardClaimWindowSeconds_ The profile reward-claim interval.
    /// @return activator_ The constructor-pinned deployment credential allowed to activate.
    /// @return settlement_ The pinned Settlement (Inbox proxy) address.
    /// @return scheduleOracle_ The pinned ScheduleOracle proxy address.
    /// @return builderProofVerifier_ The immutable stateless proof verifier.
    /// @return builderProofVerifierRuntimeHash_ The pinned verifier runtime hash.
    /// @return builderProofVerifierConfigurationHash_ The pinned verifier configuration hash.
    /// @return economicConfigurationHash_ The derived economic configuration.
    /// @return topologyHash_ The derived noncircular topology identity.
    function builderRegistryConfigV1()
        external
        view
        returns (
            bytes4 magic_,
            uint256 settlementChainId_,
            uint256 l2ChainId_,
            address builderLeaseToken_,
            bytes32 builderLeaseTokenRuntimeHash_,
            uint8 builderLeaseTokenDecimals_,
            uint192 leasePerWindowAtomic_,
            uint192 maximumBondAtomic_,
            uint192 reporterRewardCapAtomic_,
            uint64 genesisTimestamp_,
            uint64 evidenceDelaySeconds_,
            uint64 reorgMarginSeconds_,
            uint64 firstManagedWindow_,
            uint64 lastManagedWindow_,
            address builderPenaltySink_,
            uint64 rewardClaimWindowSeconds_,
            address activator_,
            address settlement_,
            address scheduleOracle_,
            address builderProofVerifier_,
            bytes32 builderProofVerifierRuntimeHash_,
            bytes32 builderProofVerifierConfigurationHash_,
            bytes32 economicConfigurationHash_,
            bytes32 topologyHash_
        );

    /// @notice Returns the immutable builder-registry topology hash.
    /// @dev Readable before activation.
    /// @return topologyHash_ The derived topology commitment.
    function builderRegistryTopologyHashV1() external view returns (bytes32 topologyHash_);

    /// @notice Returns one immutable reward-class row committed by the economic configuration.
    /// @param _classId The exact class identifier in the closed interval one through three.
    /// @return magic_ The fixed `RCV1` magic.
    /// @return economicConfigurationHash_ The registry economic configuration commitment.
    /// @return classId_ The echoed class identifier.
    /// @return fixedWei_ The fixed native reward amount.
    /// @return perExecutionGasWei_ The native reward per execution-gas unit.
    /// @return perPublishedByteWei_ The native reward per published byte.
    /// @return capWei_ The native per-candidate reward cap.
    function rewardClassV1(uint8 _classId)
        external
        view
        returns (
            bytes4 magic_,
            bytes32 economicConfigurationHash_,
            uint8 classId_,
            uint256 fixedWei_,
            uint256 perExecutionGasWei_,
            uint256 perPublishedByteWei_,
            uint256 capWei_
        );

    /// @notice Returns the current stable builder-admission commitment.
    /// @return magic_ The fixed `ADS1` magic.
    /// @return admissionVersion_ The admission mutation version.
    /// @return admissionRoot_ The current 2,048-leaf admission root.
    function admissionStateV1()
        external
        view
        returns (bytes4 magic_, uint64 admissionVersion_, bytes32 admissionRoot_);

    /// @notice Returns the active registry state consumed by schedule sealing.
    /// @return magic_ The fixed `BRS1` magic.
    /// @return schema_ The fixed schema version one.
    /// @return activeCount_ The number of occupied active cells.
    /// @return registryMutationVersion_ The registry-root mutation version.
    /// @return admissionVersion_ The admission-root mutation version.
    /// @return nextRegistrationIndex_ The next uint64 ID or the exhausted uint64-max-plus-one value.
    /// @return registryRoot_ The current 64-cell registry root.
    function scheduleRegistryStateV1()
        external
        view
        returns (
            bytes4 magic_,
            uint8 schema_,
            uint8 activeCount_,
            uint64 registryMutationVersion_,
            uint64 admissionVersion_,
            uint256 nextRegistrationIndex_,
            bytes32 registryRoot_
        );

    /// @notice Registers the caller in the deterministically selected active cell.
    /// @param _baseBondAtomic The separately escrowed ranking bond.
    /// @param _expectedNextRegistrationIndex The exact registration race guard.
    /// @param _expectedActiveIndex The derived lowest vacancy or replacement victim.
    /// @param _witness The exact canonical vacant-registration or movement proof.
    /// @return magic_ The fixed `BRG1` magic.
    /// @return registrationIndex_ The admitted generation identifier.
    /// @return activeIndex_ The occupied active-cell index.
    /// @return effectiveL2Slot_ The exact delayed effective L2 slot.
    /// @return admissionVersion_ The resulting admission version.
    /// @return admissionRoot_ The resulting admission root.
    function registerBuilderV1(
        uint192 _baseBondAtomic,
        uint64 _expectedNextRegistrationIndex,
        uint8 _expectedActiveIndex,
        bytes calldata _witness
    )
        external
        returns (
            bytes4 magic_,
            uint64 registrationIndex_,
            uint8 activeIndex_,
            uint64 effectiveL2Slot_,
            uint64 admissionVersion_,
            bytes32 admissionRoot_
        );

    /// @notice Reserves one independently escrowed builder window for the caller.
    /// @param _expectedRegistrationIndex The caller's exact live generation.
    /// @param _window The managed window to reserve.
    /// @param _witness The prestate-derived normalization and tranche proof.
    /// @return magic_ The fixed `BRV1` magic.
    /// @return registrationIndex_ The echoed generation identifier.
    /// @return window_ The echoed reserved window.
    /// @return registryMutationVersion_ The resulting registry mutation version.
    /// @return registryRoot_ The resulting active registry root.
    function reserveBuilderWindowV1(
        uint64 _expectedRegistrationIndex,
        uint64 _window,
        bytes calldata _witness
    )
        external
        returns (
            bytes4 magic_,
            uint64 registrationIndex_,
            uint64 window_,
            uint64 registryMutationVersion_,
            bytes32 registryRoot_
        );

    /// @notice Permanently closes reservations and appends the caller's delayed exit request.
    /// @param _expectedRegistrationIndex The caller's exact active generation.
    /// @return magic_ The fixed `BRE1` magic.
    /// @return registrationIndex_ The echoed generation identifier.
    /// @return matureWindow_ The first window in which the exit may move.
    /// @return activeIndex_ The current active-cell index.
    function requestBuilderExitV1(uint64 _expectedRegistrationIndex)
        external
        returns (bytes4 magic_, uint64 registrationIndex_, uint64 matureWindow_, uint8 activeIndex_);

    /// @notice Processes the complete bounded prefix of matured exits and active tombstones.
    /// @param _maxMoves The caller-selected move bound in the closed interval one through four.
    /// @param _witness Length-prefixed canonical movement witnesses for the exact derived prefix.
    /// @return magic_ The fixed `BRM1` magic.
    /// @return inspected_ The number of FIFO exit rows inspected.
    /// @return moved_ The number of generations moved.
    /// @return admissionVersion_ The resulting admission version.
    /// @return admissionRoot_ The resulting admission root.
    function processBuilderMaintenanceV1(
        uint8 _maxMoves,
        bytes calldata _witness
    )
        external
        returns (
            bytes4 magic_,
            uint8 inspected_,
            uint8 moved_,
            uint64 admissionVersion_,
            bytes32 admissionRoot_
        );

    /// @notice Converts every stale active reservation of one retained generation to liability.
    /// @param _builder The retained builder address.
    /// @param _expectedRegistrationIndex The builder's exact live generation.
    /// @param _witness The exact normalization proof or canonical single-byte no-op.
    /// @return magic_ The fixed `BRN1` magic.
    /// @return registrationIndex_ The echoed generation identifier.
    /// @return closedCount_ The number of reservations closed.
    /// @return registryMutationVersion_ The resulting registry mutation version.
    /// @return registryRoot_ The resulting registry root.
    function normalizeBuilderTranchesV1(
        address _builder,
        uint64 _expectedRegistrationIndex,
        bytes calldata _witness
    )
        external
        returns (
            bytes4 magic_,
            uint64 registrationIndex_,
            uint8 closedCount_,
            uint64 registryMutationVersion_,
            bytes32 registryRoot_
        );

    /// @notice Releases one authenticated expired liable tranche into builder pull credit.
    /// @param _builder The retained generation owner.
    /// @param _expectedRegistrationIndex The exact retained generation.
    /// @param _window The exact liable window.
    /// @param _witness The exact location-derived tranche and optional registry proof.
    /// @return magic_ The fixed `BTR1` magic.
    /// @return registrationIndex_ The echoed generation identifier.
    /// @return window_ The echoed tranche window.
    /// @return builder_ The credited builder.
    /// @return creditedAmount_ The exact lease amount credited.
    /// @return registryMutationVersion_ The resulting registry mutation version.
    /// @return registryRoot_ The resulting registry root.
    function releaseBuilderTrancheV1(
        address _builder,
        uint64 _expectedRegistrationIndex,
        uint64 _window,
        bytes calldata _witness
    )
        external
        returns (
            bytes4 magic_,
            uint64 registrationIndex_,
            uint64 window_,
            address builder_,
            uint256 creditedAmount_,
            uint64 registryMutationVersion_,
            bytes32 registryRoot_
        );

    /// @notice Releases one fully terminal retained generation into builder pull credit.
    /// @param _builder The retained generation owner.
    /// @param _expectedRegistrationIndex The exact retained generation.
    /// @param _witness The exact location-derived registry/admission proof.
    /// @return magic_ The fixed `BGR1` magic.
    /// @return registrationIndex_ The released generation identifier.
    /// @return builder_ The credited builder.
    /// @return creditedBond_ The released base-bond amount.
    /// @return admissionVersion_ The resulting admission version.
    /// @return admissionRoot_ The resulting admission root.
    function releaseBuilderGenerationV1(
        address _builder,
        uint64 _expectedRegistrationIndex,
        bytes calldata _witness
    )
        external
        returns (
            bytes4 magic_,
            uint64 registrationIndex_,
            address builder_,
            uint256 creditedBond_,
            uint64 admissionVersion_,
            bytes32 admissionRoot_
        );

    /// @notice Claims all builder-token pull credit owned by the caller.
    /// @param _recipient The nonzero non-registry exact-balance recipient.
    /// @return magic_ The fixed `BCL1` magic.
    /// @return recipient_ The transfer recipient.
    /// @return paidAmount_ The exact amount paid.
    function claimBuilderLeaseCreditV1(address _recipient)
        external
        returns (bytes4 magic_, address recipient_, uint256 paidAmount_);

    /// @notice Submits one exact proof of two conflicting retained builder promises.
    /// @dev Both signed headers must carry the Registry's `settlementChainId` and pinned
    ///      `l2ChainId`, the pinned Settlement as verifying contract and the protocol version
    ///      that Settlement currently reports through `settlementStateV1()`; every SST1 mode is
    ///      accepted. The exact `BEV1` return is 288 bytes.
    /// @param _evidence The exact 2,366-byte equivocation evidence encoding.
    /// @return magic_ The fixed `BEV1` magic.
    /// @return registrationIndex_ The slashed generation identifier.
    /// @return window_ The independently slashed window.
    /// @return builder_ The recovered retained builder.
    /// @return l2ChainId_ The pinned L2 chain identifier both signed headers carried.
    /// @return reporterAmount_ The pull credit awarded to the caller.
    /// @return penaltyAmount_ The pull credit awarded to the penalty sink.
    /// @return admissionVersion_ The resulting admission version.
    /// @return admissionRoot_ The resulting admission root.
    function submitBuilderEquivocationV1(bytes calldata _evidence)
        external
        returns (
            bytes4 magic_,
            uint64 registrationIndex_,
            uint64 window_,
            address builder_,
            uint256 l2ChainId_,
            uint256 reporterAmount_,
            uint256 penaltyAmount_,
            uint64 admissionVersion_,
            bytes32 admissionRoot_
        );
}
