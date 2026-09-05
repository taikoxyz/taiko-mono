// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { SlotChainTypes } from "../SlotChainTypes.sol";

/// @title Canonical Slot Chain V2.27 profile, release, and verifier encodings
/// @custom:security-contact security@taiko.xyz
library LibSlotChainProfile {
    uint256 internal constant EXECUTION_PROFILE_MAX_BYTES = 146_848;
    uint256 internal constant EXECUTION_PROFILE_STATIC_WORDS = 282;
    uint256 internal constant EXECUTION_PROFILE_ARTIFACT_OFFSET = 9024;
    uint32 internal constant MIGRATION_MAXIMUM_PROOF_BYTES = 131_072;
    uint32 internal constant SETTLEMENT_VALIDITY_MAXIMUM_PROOF_BYTES = 65_536;
    uint64 internal constant SETTLEMENT_VALIDITY_MAXIMUM_GAS = 30_000_000;
    bytes4 internal constant SETTLEMENT_VALIDITY_VERIFIER_SELECTOR = 0x8c6cb224;
    bytes4 internal constant MIGRATION_VERIFIER_SELECTOR = 0x81a9744d;
    bytes4 internal constant REGISTRATION_MPT_VERIFIER_SELECTOR = 0x33639818;
    uint16 internal constant REGISTRATION_MPT_MAXIMUM_NODES_PER_PATH = 65;
    uint16 internal constant REGISTRATION_MPT_MAXIMUM_TOTAL_NODES = 130;
    uint16 internal constant REGISTRATION_MPT_MAXIMUM_NODE_BYTES = 600;
    uint32 internal constant REGISTRATION_MPT_MAXIMUM_PROOF_BYTES = 78_264;
    uint64 internal constant REGISTRATION_MPT_VERIFICATION_GAS = 11_000_000;
    uint64 internal constant FORCE_SEND_CREATE2_FIXED_GAS = 33_000;
    uint64 internal constant FORCE_SEND_CHILD_GAS = 75_000;
    uint64 internal constant FORCE_SEND_POSTCHECK_RESERVE = 20_000;

    bytes32 internal constant SETTLEMENT_VALIDITY_PUBLIC_INPUT_SCHEMA_HASH =
        keccak256("slot-chain-settlement-validity-public-input-schema-v2");
    bytes32 internal constant FORCE_SEND_COMPILER_BUILD_HASH =
        keccak256("slot-chain-force-send-handwritten-osaka-evm-v1");
    bytes32 internal constant FORCE_SEND_EVM_RULES_HASH =
        keccak256("slot-chain-force-send-eip-6780-osaka-v1");

    // Canonical type strings are consensus inputs and cannot be wrapped without changing their hashes.
    // solhint-disable max-line-length
    bytes32 internal constant REGISTRATION_MPT_PROOF_SCHEMA_HASH = keccak256(
        "MptProofV1=be16(accountNodeCount)||be16(storageNodeCount)||(be16(nodeLength)||canonicalRlpNode)*accountNodeCount||(be16(nodeLength)||canonicalRlpNode)*storageNodeCount;rootToLeaf;EthereumKeccak;canonicalHexPrefix;canonicalRlp;selectedNodesValidated;unselectedInlineOpaque;emptyBranchValue;absenceRejected;valueRequired"
    );

    bytes32 internal constant SETTLEMENT_VALIDITY_VERIFIER_CONFIG_TYPEHASH = keccak256(
        "SettlementValidityVerifierConfigV2(bytes32 verifyingKeyHash,bytes32 proofSystemId,bytes32 publicInputSchemaHash,bytes4 selector,uint32 maximumProofBytes,uint64 verificationGasLimit,uint64 postVerificationReserveGas)"
    );
    bytes32 internal constant SETTLEMENT_VALIDITY_VERIFIER_DESCRIPTOR_TYPEHASH = keccak256(
        "SettlementValidityVerifierDescriptorV2(address verifier,bytes32 runtimeHash,bytes32 configurationHash,bytes32 verifyingKeyHash,bytes32 proofSystemId,bytes32 publicInputSchemaHash,bytes4 selector,uint32 maximumProofBytes,uint64 verificationGasLimit,uint64 postVerificationReserveGas)"
    );
    bytes32 internal constant MIGRATION_VERIFIER_CONFIG_TYPEHASH = keccak256(
        "MigrationTransitionVerifierConfigV2(bytes32 verifyingKeyHash,bytes32 proofSystemId,bytes32 publicInputSchemaHash,bytes4 selector,uint32 maximumProofBytes,uint64 verificationGasLimit)"
    );
    bytes32 internal constant MIGRATION_VERIFIER_DESCRIPTOR_TYPEHASH = keccak256(
        "MigrationTransitionVerifierDescriptorV2(address verifier,bytes32 runtimeHash,bytes32 configurationHash,bytes32 verifyingKeyHash,bytes32 proofSystemId,bytes32 publicInputSchemaHash,bytes4 selector,uint32 maximumProofBytes,uint64 verificationGasLimit)"
    );
    bytes32 internal constant REGISTRATION_MPT_VERIFIER_CONFIG_TYPEHASH = keccak256(
        "RegistrationMptVerifierConfigV2(bytes32 publicInputSchemaHash,bytes32 proofSchemaHash,bytes4 selector,uint16 maximumNodesPerPath,uint16 maximumTotalNodes,uint16 maximumNodeBytes,uint32 maximumProofBytes,uint64 verificationGasLimit)"
    );
    bytes32 internal constant REGISTRATION_MPT_VERIFIER_DESCRIPTOR_TYPEHASH = keccak256(
        "RegistrationMptVerifierDescriptorV2(address verifier,bytes32 runtimeHash,bytes32 configurationHash,bytes32 publicInputSchemaHash,bytes32 proofSchemaHash,bytes4 selector,uint16 maximumNodesPerPath,uint16 maximumTotalNodes,uint16 maximumNodeBytes,uint32 maximumProofBytes,uint64 verificationGasLimit)"
    );
    bytes32 internal constant REGISTRATION_STORAGE_STATEMENT_TYPEHASH = keccak256(
        "RegistrationStorageStatementV2(uint256 settlementChainId,address activeSettlementRouter,address bridgeDomainRegistry,bytes32 routeKey,uint256 destinationChainId,uint64 protocolVersion,uint64 canonicalSequence,bytes32 stateRoot,address terminalDomainRegistrar,bytes32 registrarCodeHash,bytes32 storageTrieKey,bytes32 expectedValue)"
    );
    bytes32 internal constant MIGRATION_TRANSITION_STATEMENT_TYPEHASH = keccak256(
        "MigrationTransitionStatementV2(uint256 settlementChainId,address activeSettlementRouter,bytes32 routerRuntimeHash,bytes32 routerConfigurationHash,uint8 transitionKind,uint64 migrationGeneration,uint64 sourceProtocolVersion,uint64 targetProtocolVersion,uint64 sourceCanonicalSequence,bytes32 executionProfileHash,bytes32 targetManifestHash,bytes32 targetRegistrationHash,bytes32 candidateDigest,bytes32 baseCanonicalHash,bytes32 outputCanonicalHash,address forcedQueue,bytes32 queueRuntimeHash,bytes32 queueConfigurationHash,bytes32 queueRoot,uint64 queueCount,uint64 startCursor,uint64 endCursor,bytes32 forcedDescriptorCommitment,address proofBeneficiary,uint256 anchorNumber,bytes32 anchorHash,bytes32 forceRoot,uint64 forceCutoff,bytes32 sourceDomainId,uint64 sourceRegistrationEpoch,bytes32 sourceBridgeExecutionHash,bytes32 releaseSystemCalldataHash,bytes32 inboxSystemCalldataHash,bytes32 releaseSystemTxHash,bytes32 inboxSystemTxHash,uint8 releaseSystemTxPosition,uint8 inboxSystemTxPosition,bytes32 importedHeaderHash,bytes32 importedStateRoot,bytes32 legacySignalCheckpointHash,bytes32 legacyDeploymentHash,bytes32 legacyArmId,bytes32 legacyLaunchId,bytes32 deploymentCommitment,uint64 preInboxLastAppliedPlusOne,uint64 postInboxLastAppliedPlusOne)"
    );
    bytes32 internal constant INGRESS_AUTHORIZATION_TYPEHASH = keccak256(
        "ProfileIngressAuthorizationV2(uint8 kind,address adapter,bytes32 adapterRuntimeHash,bytes32 adapterConfigurationHash,bytes32 adapterConstructorPoststateCommitment,address activeSettlementRouter,bytes32 routerRuntimeHash,bytes32 routerConfigurationHash,address forcedQueue,bytes32 queueRuntimeHash,bytes32 queueConfigurationHash,bytes32 sourceDomainId,uint64 sourceRegistrationEpoch,bytes32 sourceBridgeExecutionHash,uint256 destinationChainId,bytes32 destinationDomainId,address destinationBridge,bytes32 destinationBridgeExecutionHash,bytes32 destinationInfrastructureHash,uint256 fixedIngressWei,uint256 executionWeiPerAccountedGas,uint256 proofWeiPerAccountedGas,uint256 permanentWeiPerByte,uint256 maximumAcceptedFeeWei)"
    );
    bytes32 internal constant INGRESS_AUTHORIZATION_ROOT_TYPEHASH =
        keccak256("IngressAuthorizationRootV2(uint16 count,bytes32 idsHash)");
    bytes32 internal constant RELEASE_MANIFEST_TYPEHASH = keccak256(
        "ReleaseManifestV2(uint64 protocolVersion,uint256 settlementChainId,uint256 destinationChainId,bytes32 destinationGenesisHash,bytes32 executionProfileHash,bytes32 manifestNamespace,bytes32 destinationNamespace,address anchorV4,bytes32 anchorRuntimeHash,bytes32 destinationDomainId,address destinationBridge,bytes32 destinationBridgeExecutionHash,DestinationBridgeDescriptorV2 destinationBridgeDescriptor,bytes32 destinationInfrastructureHash,bytes32 migrationVerifierDescriptorHash,bytes32 ingressAuthorizationRoot,address nativeLiquidityPool,bytes32 poolRuntimeHash,bytes32 poolConfigurationHash,ComponentDescriptorV2[10] components)ComponentDescriptorV2(address component,bytes32 runtimeHash,bytes32 configHash)DestinationBridgeDescriptorV2(address bridge,bytes32 runtimeHash,bytes32 configurationHash,bytes32 storageLayoutHash,bytes32 bridgeKernelProfileHash,address inboxCreditStore,address terminalAccumulator,address terminalDomainRegistrar,address quotaManager,address nativeLiquidityPool,address bridgeSurplusSink)"
    );

    // solhint-enable max-line-length

    /// @dev ABI-encodes without applying the PVM/Router's full 281-word graph validation.
    /// @param _profile The exact V2.27 execution profile.
    /// @return profileBytes_ The canonical Solidity ABI encoding.
    function encodeExecutionProfileUnchecked(SlotChainTypes.ExecutionProfileV2 memory _profile)
        internal
        pure
        returns (bytes memory profileBytes_)
    {
        bytes memory artifact = _profile.deploymentCodeArtifacts;
        uint256 paddedArtifactLength = (artifact.length + 31) & ~uint256(31);
        profileBytes_ =
            new bytes(32 + EXECUTION_PROFILE_STATIC_WORDS * 32 + 32 + paddedArtifactLength);
        uint256 outerOffset;
        uint256 artifactOffset;
        assembly ("memory-safe") {
            let output := add(profileBytes_, 0x20)
            mstore(output, 0x20)
            mcopy(add(output, 0x20), _profile, mul(281, 0x20))
            mstore(add(add(output, 0x20), mul(281, 0x20)), EXECUTION_PROFILE_ARTIFACT_OFFSET)
            let artifactTail := add(add(output, 0x20), EXECUTION_PROFILE_ARTIFACT_OFFSET)
            mstore(artifactTail, mload(artifact))
            mcopy(add(artifactTail, 0x20), add(artifact, 0x20), mload(artifact))
            outerOffset := mload(add(profileBytes_, 0x20))
            artifactOffset := mload(add(add(profileBytes_, 0x40), mul(281, 0x20)))
        }
        assert(profileBytes_.length >= (EXECUTION_PROFILE_STATIC_WORDS + 2) * 32);
        assert(outerOffset == 32);
        assert(artifactOffset == EXECUTION_PROFILE_ARTIFACT_OFFSET);
    }

    /// @dev Hashes bytes without checking the profile's word graph or canonical ABI grammar.
    /// @param _profileBytes The complete canonical `abi.encode(ExecutionProfileV2)` bytes.
    /// @return executionProfileHash_ The execution-profile commitment.
    function hashExecutionProfileBytesUnchecked(bytes memory _profileBytes)
        internal
        pure
        returns (bytes32 executionProfileHash_)
    {
        uint256 length = _profileBytes.length;
        if (length == 0 || length > EXECUTION_PROFILE_MAX_BYTES) {
            revert InvalidExecutionProfileLength();
        }
        executionProfileHash_ = keccak256(
            bytes.concat(
                bytes("slot-chain-execution-profile-v2"), bytes4(uint32(length)), _profileBytes
            )
        );
    }

    /// @dev Hashes an in-memory profile without applying the full PVM/Router graph validation.
    /// @param _profile The exact V2.27 profile value.
    /// @return executionProfileHash_ The execution-profile commitment.
    function hashExecutionProfileUnchecked(SlotChainTypes.ExecutionProfileV2 memory _profile)
        internal
        pure
        returns (bytes32 executionProfileHash_)
    {
        executionProfileHash_ =
            hashExecutionProfileBytesUnchecked(encodeExecutionProfileUnchecked(_profile));
    }

    /// @dev ABI-encodes the exact static 59-word release manifest.
    /// @param _manifest The release manifest.
    /// @return manifestBytes_ The canonical static ABI projection.
    function encodeReleaseManifest(SlotChainTypes.ReleaseManifestV2 memory _manifest)
        internal
        pure
        returns (bytes memory manifestBytes_)
    {
        _validateReleaseManifest(_manifest);
        manifestBytes_ = new bytes(59 * 32);
        assembly ("memory-safe") {
            let output := add(manifestBytes_, 0x20)
            // The first twelve manifest members precede the nested Bridge descriptor.
            mcopy(output, _manifest, mul(12, 0x20))

            // Memory structs retain nested structs by pointer, whereas their canonical ABI
            // projection flattens the eleven descriptor words in place.
            let bridgeDescriptor := mload(add(_manifest, mul(12, 0x20)))
            mcopy(add(output, mul(12, 0x20)), bridgeDescriptor, mul(11, 0x20))

            // Copy the six scalar members between the Bridge descriptor and component array.
            mcopy(add(output, mul(23, 0x20)), add(_manifest, mul(13, 0x20)), mul(6, 0x20))

            // A fixed memory array of structs stores one pointer per element. Its ABI projection
            // flattens each three-word component descriptor.
            let components := mload(add(_manifest, mul(19, 0x20)))
            for { let i := 0 } lt(i, 10) { i := add(i, 1) } {
                let component := mload(add(components, mul(i, 0x20)))
                mcopy(add(output, mul(add(29, mul(i, 3)), 0x20)), component, mul(3, 0x20))
            }
        }
        assert(manifestBytes_.length == 59 * 32);
    }

    /// @dev Computes the type-hashed release-manifest commitment.
    /// @param _manifest The release manifest.
    /// @return releaseManifestHash_ The release-manifest commitment.
    function hashReleaseManifest(SlotChainTypes.ReleaseManifestV2 memory _manifest)
        internal
        pure
        returns (bytes32 releaseManifestHash_)
    {
        releaseManifestHash_ = keccak256(
            bytes.concat(RELEASE_MANIFEST_TYPEHASH, encodeReleaseManifest(_manifest))
        );
    }

    /// @dev Computes the ordinary verifier's acyclic implementation configuration hash.
    /// @param _descriptor The ordinary settlement validity verifier descriptor.
    /// @return configurationHash_ The independently derived configuration hash.
    function settlementValidityVerifierConfigurationHash(
        SlotChainTypes.SettlementValidityVerifierDescriptorV2 memory _descriptor
    )
        internal
        pure
        returns (bytes32 configurationHash_)
    {
        _validateSettlementValidityVerifierDescriptor(_descriptor);
        configurationHash_ = keccak256(
            abi.encode(
                SETTLEMENT_VALIDITY_VERIFIER_CONFIG_TYPEHASH,
                _descriptor.verifyingKeyHash,
                _descriptor.proofSystemId,
                _descriptor.publicInputSchemaHash,
                _descriptor.selector,
                _descriptor.maximumProofBytes,
                _descriptor.verificationGasLimit,
                _descriptor.postVerificationReserveGas
            )
        );
    }

    /// @dev Computes the complete ordinary settlement verifier descriptor hash.
    /// @param _descriptor The ordinary settlement validity verifier descriptor.
    /// @return descriptorHash_ The type-hashed descriptor commitment.
    function hashSettlementValidityVerifierDescriptor(
        SlotChainTypes.SettlementValidityVerifierDescriptorV2 memory _descriptor
    )
        internal
        pure
        returns (bytes32 descriptorHash_)
    {
        descriptorHash_ = keccak256(
            bytes.concat(
                SETTLEMENT_VALIDITY_VERIFIER_DESCRIPTOR_TYPEHASH,
                encodeSettlementValidityVerifierDescriptor(_descriptor)
            )
        );
    }

    /// @dev Encodes the validated ordinary settlement verifier descriptor as ten ABI words.
    /// @param _descriptor The ordinary settlement validity verifier descriptor.
    /// @return descriptorBytes_ The canonical static descriptor encoding.
    function encodeSettlementValidityVerifierDescriptor(
        SlotChainTypes.SettlementValidityVerifierDescriptorV2 memory _descriptor
    )
        internal
        pure
        returns (bytes memory descriptorBytes_)
    {
        _validateSettlementValidityVerifierDescriptor(_descriptor);
        descriptorBytes_ = abi.encode(_descriptor);
        assert(descriptorBytes_.length == 10 * 32);
    }

    /// @dev Computes the migration verifier's acyclic implementation configuration hash.
    /// @param _descriptor The migration-transition verifier descriptor.
    /// @return configurationHash_ The independently derived configuration hash.
    function migrationVerifierConfigurationHash(
        SlotChainTypes.MigrationTransitionVerifierDescriptorV2 memory _descriptor
    )
        internal
        pure
        returns (bytes32 configurationHash_)
    {
        _validateMigrationVerifierDescriptor(_descriptor);
        configurationHash_ = keccak256(
            abi.encode(
                MIGRATION_VERIFIER_CONFIG_TYPEHASH,
                _descriptor.verifyingKeyHash,
                _descriptor.proofSystemId,
                _descriptor.publicInputSchemaHash,
                _descriptor.selector,
                _descriptor.maximumProofBytes,
                _descriptor.verificationGasLimit
            )
        );
    }

    /// @dev Computes the complete migration-transition verifier descriptor hash.
    /// @param _descriptor The migration-transition verifier descriptor.
    /// @return descriptorHash_ The type-hashed descriptor commitment.
    function hashMigrationVerifierDescriptor(
        SlotChainTypes.MigrationTransitionVerifierDescriptorV2 memory _descriptor
    )
        internal
        pure
        returns (bytes32 descriptorHash_)
    {
        descriptorHash_ = keccak256(
            bytes.concat(
                MIGRATION_VERIFIER_DESCRIPTOR_TYPEHASH,
                encodeMigrationVerifierDescriptor(_descriptor)
            )
        );
    }

    /// @dev Encodes the validated migration-transition verifier descriptor as nine ABI words.
    /// @param _descriptor The migration-transition verifier descriptor.
    /// @return descriptorBytes_ The canonical static descriptor encoding.
    function encodeMigrationVerifierDescriptor(
        SlotChainTypes.MigrationTransitionVerifierDescriptorV2 memory _descriptor
    )
        internal
        pure
        returns (bytes memory descriptorBytes_)
    {
        _validateMigrationVerifierDescriptor(_descriptor);
        descriptorBytes_ = abi.encode(_descriptor);
        assert(descriptorBytes_.length == 9 * 32);
    }

    /// @dev Computes the registration MPT verifier's acyclic implementation configuration hash.
    /// @param _descriptor The registration MPT verifier descriptor.
    /// @return configurationHash_ The independently derived configuration hash.
    function registrationMptVerifierConfigurationHash(
        SlotChainTypes.RegistrationMptVerifierDescriptorV2 memory _descriptor
    )
        internal
        pure
        returns (bytes32 configurationHash_)
    {
        _validateRegistrationMptVerifierDescriptor(_descriptor);
        configurationHash_ = keccak256(
            abi.encode(
                REGISTRATION_MPT_VERIFIER_CONFIG_TYPEHASH,
                _descriptor.publicInputSchemaHash,
                _descriptor.proofSchemaHash,
                _descriptor.selector,
                _descriptor.maximumNodesPerPath,
                _descriptor.maximumTotalNodes,
                _descriptor.maximumNodeBytes,
                _descriptor.maximumProofBytes,
                _descriptor.verificationGasLimit
            )
        );
    }

    /// @dev Computes the complete registration MPT verifier descriptor hash.
    /// @param _descriptor The registration MPT verifier descriptor.
    /// @return descriptorHash_ The type-hashed descriptor commitment.
    function hashRegistrationMptVerifierDescriptor(
        SlotChainTypes.RegistrationMptVerifierDescriptorV2 memory _descriptor
    )
        internal
        pure
        returns (bytes32 descriptorHash_)
    {
        descriptorHash_ = keccak256(
            bytes.concat(
                REGISTRATION_MPT_VERIFIER_DESCRIPTOR_TYPEHASH,
                encodeRegistrationMptVerifierDescriptor(_descriptor)
            )
        );
    }

    /// @dev Encodes the validated registration MPT verifier descriptor as eleven ABI words.
    /// @param _descriptor The registration MPT verifier descriptor.
    /// @return descriptorBytes_ The canonical static descriptor encoding.
    function encodeRegistrationMptVerifierDescriptor(
        SlotChainTypes.RegistrationMptVerifierDescriptorV2 memory _descriptor
    )
        internal
        pure
        returns (bytes memory descriptorBytes_)
    {
        _validateRegistrationMptVerifierDescriptor(_descriptor);
        descriptorBytes_ = abi.encode(_descriptor);
        assert(descriptorBytes_.length == 11 * 32);
    }

    /// @dev Computes the exact destination-registration public statement hash.
    /// @param _statement The derived registration-storage statement.
    /// @return statementHash_ The type-hashed statement commitment.
    function hashRegistrationStorageStatement(
        SlotChainTypes.RegistrationStorageStatementV2 memory _statement
    )
        internal
        pure
        returns (bytes32 statementHash_)
    {
        statementHash_ = keccak256(
            bytes.concat(
                REGISTRATION_STORAGE_STATEMENT_TYPEHASH,
                encodeRegistrationStorageStatement(_statement)
            )
        );
    }

    /// @dev Encodes the exact twelve-word registration-storage public statement.
    /// @param _statement The derived registration-storage statement.
    /// @return statementBytes_ The canonical static statement encoding.
    function encodeRegistrationStorageStatement(
        SlotChainTypes.RegistrationStorageStatementV2 memory _statement
    )
        internal
        pure
        returns (bytes memory statementBytes_)
    {
        statementBytes_ = abi.encode(_statement);
        assert(statementBytes_.length == 12 * 32);
    }

    /// @dev Encodes the static 22-word migration activation prefix.
    /// @param _fixedInput The fixed activation input.
    /// @return fixedBytes_ Its canonical static ABI projection.
    function encodeMigrationActivationFixed(
        SlotChainTypes.MigrationActivationFixedV2 memory _fixedInput
    )
        internal
        pure
        returns (bytes memory fixedBytes_)
    {
        _validateMigrationActivationFixed(_fixedInput);
        fixedBytes_ = new bytes(22 * 32);
        assembly ("memory-safe") {
            let output := add(fixedBytes_, 0x20)
            mcopy(output, _fixedInput, mul(7, 0x20))
            let outputCore := mload(add(_fixedInput, mul(7, 0x20)))
            mcopy(add(output, mul(7, 0x20)), outputCore, mul(10, 0x20))
            mcopy(add(output, mul(17, 0x20)), add(_fixedInput, mul(8, 0x20)), mul(5, 0x20))
        }
        assert(fixedBytes_.length == 22 * 32);
    }

    /// @dev Hashes the canonical 22-word migration activation prefix.
    /// @param _fixedInput The fixed activation input.
    /// @return fixedHash_ The un-domained canonical ABI hash pinned by the vectors.
    function hashMigrationActivationFixed(
        SlotChainTypes.MigrationActivationFixedV2 memory _fixedInput
    )
        internal
        pure
        returns (bytes32 fixedHash_)
    {
        fixedHash_ = keccak256(encodeMigrationActivationFixed(_fixedInput));
    }

    /// @dev Computes the exact migration-transition public statement hash.
    /// @param _statement The L1-derived migration transition statement.
    /// @return statementHash_ The type-hashed statement commitment.
    function hashMigrationTransitionStatement(
        SlotChainTypes.MigrationTransitionStatementV2 memory _statement
    )
        internal
        pure
        returns (bytes32 statementHash_)
    {
        statementHash_ = keccak256(
            bytes.concat(
                MIGRATION_TRANSITION_STATEMENT_TYPEHASH,
                encodeMigrationTransitionStatement(_statement)
            )
        );
    }

    /// @dev Encodes the validated 46-word migration-transition public statement.
    /// @param _statement The L1-derived migration transition statement.
    /// @return statementBytes_ The canonical static statement encoding.
    function encodeMigrationTransitionStatement(
        SlotChainTypes.MigrationTransitionStatementV2 memory _statement
    )
        internal
        pure
        returns (bytes memory statementBytes_)
    {
        _validateMigrationTransitionStatement(_statement);
        statementBytes_ = new bytes(46 * 32);
        assembly ("memory-safe") {
            mcopy(add(statementBytes_, 0x20), _statement, mul(46, 0x20))
        }
        assert(statementBytes_.length == 46 * 32);
    }

    /// @dev Computes one type-hashed ingress authorization ID.
    /// @param _authorization The exact profile authorization row.
    /// @return authorizationId_ The authorization ID.
    function hashIngressAuthorization(
        SlotChainTypes.ProfileIngressAuthorizationV2 memory _authorization
    )
        internal
        pure
        returns (bytes32 authorizationId_)
    {
        authorizationId_ = keccak256(
            bytes.concat(INGRESS_AUTHORIZATION_TYPEHASH, encodeIngressAuthorization(_authorization))
        );
    }

    /// @dev Encodes one validated 24-word profile ingress authorization row.
    /// @param _authorization The exact profile authorization row.
    /// @return authorizationBytes_ The canonical static row encoding.
    function encodeIngressAuthorization(
        SlotChainTypes.ProfileIngressAuthorizationV2 memory _authorization
    )
        internal
        pure
        returns (bytes memory authorizationBytes_)
    {
        _validateIngressAuthorization(_authorization);
        authorizationBytes_ = abi.encode(_authorization);
        assert(authorizationBytes_.length == 24 * 32);
    }

    /// @dev Computes the exact two-row ingress root after validating row kinds and adapter identity.
    /// @param _authorizations The kind-0 and kind-1 authorization rows, in either order.
    /// @return ingressRoot_ The type-hashed authorization root.
    function hashIngressAuthorizationRoot(SlotChainTypes
                .ProfileIngressAuthorizationV2[2] memory _authorizations)
        internal
        pure
        returns (bytes32 ingressRoot_)
    {
        if (
            _authorizations[0].adapter == _authorizations[1].adapter
                || _authorizations[0].kind == _authorizations[1].kind
        ) {
            revert InvalidIngressAuthorizationIds();
        }
        bytes32 _firstAuthorizationId = hashIngressAuthorization(_authorizations[0]);
        bytes32 _secondAuthorizationId = hashIngressAuthorization(_authorizations[1]);
        if (
            _firstAuthorizationId == bytes32(0) || _secondAuthorizationId == bytes32(0)
                || _firstAuthorizationId == _secondAuthorizationId
        ) {
            revert InvalidIngressAuthorizationIds();
        }
        (bytes32 first, bytes32 second) = uint256(_firstAuthorizationId)
                < uint256(_secondAuthorizationId)
            ? (_firstAuthorizationId, _secondAuthorizationId)
            : (_secondAuthorizationId, _firstAuthorizationId);
        bytes32 idsHash = keccak256(bytes.concat(first, second));
        ingressRoot_ =
            keccak256(abi.encode(INGRESS_AUTHORIZATION_ROOT_TYPEHASH, uint16(2), idsHash));
    }

    /// @dev Encodes the static 35-word retained reclamation tuple without its release denyset.
    /// @param _config The retained reclamation configuration.
    /// @return configBytes_ Its canonical static ABI projection.
    function encodeReclamationConfigUnchecked(SlotChainTypes.ReclamationConfigV2 memory _config)
        internal
        pure
        returns (bytes memory configBytes_)
    {
        configBytes_ = new bytes(35 * 32);
        assembly ("memory-safe") {
            let output := add(configBytes_, 0x20)
            mcopy(output, _config, mul(8, 0x20))
            let components := mload(add(_config, mul(8, 0x20)))
            for { let i := 0 } lt(i, 6) { i := add(i, 1) } {
                let component := mload(add(components, mul(i, 0x20)))
                mcopy(add(output, mul(add(8, mul(i, 3)), 0x20)), component, mul(3, 0x20))
            }
            mcopy(add(output, mul(26, 0x20)), add(_config, mul(9, 0x20)), mul(9, 0x20))
        }
        assert(configBytes_.length == 35 * 32);
    }

    /// @dev Computes a destination-local activation receipt ID using its packed-width domain.
    /// @param _receipt The sealed destination activation receipt fields.
    /// @return receiptId_ The destination receipt ID.
    function hashDestinationActivationReceipt(
        SlotChainTypes.DestinationActivationReceiptV2 memory _receipt
    )
        internal
        pure
        returns (bytes32 receiptId_)
    {
        receiptId_ = keccak256(
            abi.encodePacked(
                "slot-chain-destination-activation-receipt-v2",
                _receipt.destinationChainId,
                _receipt.terminalDomainRegistrar,
                _receipt.successorIndex,
                _receipt.oldProtocolVersion,
                _receipt.newProtocolVersion,
                _receipt.oldManifestHash,
                _receipt.newManifestHash,
                _receipt.oldDestinationDomainId,
                _receipt.newDestinationDomainId,
                _receipt.oldDestinationBridge,
                _receipt.newDestinationBridge,
                _receipt.retirementQueueCount,
                _receipt.activatedAtBlock
            )
        );
    }

    /// @dev Validates the semantic predicates attached to the ordinary verifier descriptor.
    /// @param _descriptor The descriptor to validate.
    function _validateSettlementValidityVerifierDescriptor(
        SlotChainTypes.SettlementValidityVerifierDescriptorV2 memory _descriptor
    )
        private
        pure
    {
        if (
            _descriptor.verifier == address(0) || _descriptor.runtimeHash == bytes32(0)
                || _descriptor.configurationHash == bytes32(0)
                || _descriptor.verifyingKeyHash == bytes32(0)
                || _descriptor.proofSystemId == bytes32(0)
                || _descriptor.publicInputSchemaHash != SETTLEMENT_VALIDITY_PUBLIC_INPUT_SCHEMA_HASH
                || _descriptor.selector != SETTLEMENT_VALIDITY_VERIFIER_SELECTOR
                || _descriptor.maximumProofBytes == 0
                || _descriptor.maximumProofBytes > SETTLEMENT_VALIDITY_MAXIMUM_PROOF_BYTES
                || _descriptor.verificationGasLimit == 0
                || _descriptor.verificationGasLimit > SETTLEMENT_VALIDITY_MAXIMUM_GAS
                || _descriptor.postVerificationReserveGas == 0
                || _descriptor.postVerificationReserveGas > SETTLEMENT_VALIDITY_MAXIMUM_GAS
                || _descriptor.configurationHash
                    != _settlementValidityVerifierConfigurationHashUnchecked(_descriptor)
        ) {
            revert InvalidSettlementValidityVerifierDescriptor();
        }
    }

    /// @dev Computes the ordinary verifier configuration without recursively validating it.
    /// @param _descriptor The descriptor whose implementation fields are hashed.
    /// @return configurationHash_ The derived configuration hash.
    function _settlementValidityVerifierConfigurationHashUnchecked(
        SlotChainTypes.SettlementValidityVerifierDescriptorV2 memory _descriptor
    )
        private
        pure
        returns (bytes32 configurationHash_)
    {
        configurationHash_ = keccak256(
            abi.encode(
                SETTLEMENT_VALIDITY_VERIFIER_CONFIG_TYPEHASH,
                _descriptor.verifyingKeyHash,
                _descriptor.proofSystemId,
                _descriptor.publicInputSchemaHash,
                _descriptor.selector,
                _descriptor.maximumProofBytes,
                _descriptor.verificationGasLimit,
                _descriptor.postVerificationReserveGas
            )
        );
    }

    /// @dev Validates the semantic predicates attached to the migration verifier descriptor.
    /// @param _descriptor The descriptor to validate.
    function _validateMigrationVerifierDescriptor(
        SlotChainTypes.MigrationTransitionVerifierDescriptorV2 memory _descriptor
    )
        private
        pure
    {
        if (
            _descriptor.verifier == address(0) || _descriptor.runtimeHash == bytes32(0)
                || _descriptor.configurationHash == bytes32(0)
                || _descriptor.verifyingKeyHash == bytes32(0)
                || _descriptor.proofSystemId == bytes32(0)
                || _descriptor.publicInputSchemaHash != MIGRATION_TRANSITION_STATEMENT_TYPEHASH
                || _descriptor.selector != MIGRATION_VERIFIER_SELECTOR
                || _descriptor.maximumProofBytes == 0
                || _descriptor.maximumProofBytes > MIGRATION_MAXIMUM_PROOF_BYTES
                || _descriptor.verificationGasLimit == 0
                || _descriptor.configurationHash
                    != _migrationVerifierConfigurationHashUnchecked(_descriptor)
        ) {
            revert InvalidMigrationVerifierDescriptor();
        }
    }

    /// @dev Computes the migration verifier configuration without recursively validating it.
    /// @param _descriptor The descriptor whose implementation fields are hashed.
    /// @return configurationHash_ The derived configuration hash.
    function _migrationVerifierConfigurationHashUnchecked(
        SlotChainTypes.MigrationTransitionVerifierDescriptorV2 memory _descriptor
    )
        private
        pure
        returns (bytes32 configurationHash_)
    {
        configurationHash_ = keccak256(
            abi.encode(
                MIGRATION_VERIFIER_CONFIG_TYPEHASH,
                _descriptor.verifyingKeyHash,
                _descriptor.proofSystemId,
                _descriptor.publicInputSchemaHash,
                _descriptor.selector,
                _descriptor.maximumProofBytes,
                _descriptor.verificationGasLimit
            )
        );
    }

    /// @dev Validates every frozen registration MPT verifier parameter and hash layer.
    /// @param _descriptor The descriptor to validate.
    function _validateRegistrationMptVerifierDescriptor(
        SlotChainTypes.RegistrationMptVerifierDescriptorV2 memory _descriptor
    )
        private
        pure
    {
        if (
            _descriptor.verifier == address(0) || _descriptor.runtimeHash == bytes32(0)
                || _descriptor.configurationHash == bytes32(0)
                || _descriptor.publicInputSchemaHash != REGISTRATION_STORAGE_STATEMENT_TYPEHASH
                || _descriptor.proofSchemaHash != REGISTRATION_MPT_PROOF_SCHEMA_HASH
                || _descriptor.selector != REGISTRATION_MPT_VERIFIER_SELECTOR
                || _descriptor.maximumNodesPerPath != REGISTRATION_MPT_MAXIMUM_NODES_PER_PATH
                || _descriptor.maximumTotalNodes != REGISTRATION_MPT_MAXIMUM_TOTAL_NODES
                || _descriptor.maximumNodeBytes != REGISTRATION_MPT_MAXIMUM_NODE_BYTES
                || _descriptor.maximumProofBytes != REGISTRATION_MPT_MAXIMUM_PROOF_BYTES
                || _descriptor.verificationGasLimit != REGISTRATION_MPT_VERIFICATION_GAS
                || _descriptor.configurationHash
                    != _registrationMptVerifierConfigurationHashUnchecked(_descriptor)
        ) {
            revert InvalidRegistrationMptVerifierDescriptor();
        }
    }

    /// @dev Computes the registration verifier configuration without recursively validating it.
    /// @param _descriptor The descriptor whose implementation fields are hashed.
    /// @return configurationHash_ The derived configuration hash.
    function _registrationMptVerifierConfigurationHashUnchecked(
        SlotChainTypes.RegistrationMptVerifierDescriptorV2 memory _descriptor
    )
        private
        pure
        returns (bytes32 configurationHash_)
    {
        configurationHash_ = keccak256(
            abi.encode(
                REGISTRATION_MPT_VERIFIER_CONFIG_TYPEHASH,
                _descriptor.publicInputSchemaHash,
                _descriptor.proofSchemaHash,
                _descriptor.selector,
                _descriptor.maximumNodesPerPath,
                _descriptor.maximumTotalNodes,
                _descriptor.maximumNodeBytes,
                _descriptor.maximumProofBytes,
                _descriptor.verificationGasLimit
            )
        );
    }

    /// @dev Validates the transition-specific fixed activation invariants.
    /// @param _fixedInput The fixed activation input to validate.
    function _validateMigrationActivationFixed(
        SlotChainTypes.MigrationActivationFixedV2 memory _fixedInput
    )
        private
        pure
    {
        bool genesis =
            _fixedInput.transitionKind == uint8(SlotChainTypes.MigrationKind.GENESIS_IMPORT);
        if (
            (!genesis
                    && _fixedInput.transitionKind
                        != uint8(SlotChainTypes.MigrationKind.VERSION_MIGRATION))
                || (_fixedInput.seatGeneration == 0) != genesis
                || (genesis
                    && (_fixedInput.sourceCanonicalSequence != 0
                        || _fixedInput.forceCutoff != 0
                        || _fixedInput.preInboxLastAppliedPlusOne != 0
                        || _fixedInput.outputCore.messageCursor != 0))
        ) {
            revert InvalidMigrationActivationFixed();
        }
    }

    /// @dev Validates the transition-specific migration statement zero/nonzero grammar.
    /// @param _statement The migration statement to validate.
    function _validateMigrationTransitionStatement(
        SlotChainTypes.MigrationTransitionStatementV2 memory _statement
    )
        private
        pure
    {
        bool genesis =
            _statement.transitionKind == uint8(SlotChainTypes.MigrationKind.GENESIS_IMPORT);
        if (
            (!genesis
                    && _statement.transitionKind
                        != uint8(SlotChainTypes.MigrationKind.VERSION_MIGRATION))
                || _statement.targetRegistrationHash == bytes32(0)
                || _statement.releaseSystemTxPosition != 0 || _statement.inboxSystemTxPosition != 1
        ) {
            revert InvalidMigrationTransitionStatement();
        }

        if (genesis) {
            if (
                _statement.importedHeaderHash == bytes32(0)
                    || _statement.importedStateRoot == bytes32(0)
                    || _statement.legacySignalCheckpointHash == bytes32(0)
                    || _statement.legacyDeploymentHash == bytes32(0)
                    || _statement.legacyArmId == bytes32(0)
                    || _statement.legacyLaunchId == bytes32(0)
                    || _statement.sourceCanonicalSequence != 0 || _statement.queueCount != 0
                    || _statement.startCursor != 0 || _statement.endCursor != 0
                    || _statement.forceCutoff != 0 || _statement.queueRoot != _statement.forceRoot
                    || _statement.forcedDescriptorCommitment != _emptyForcedDescriptorCommitment()
                    || _statement.sourceDomainId != bytes32(0)
                    || _statement.sourceRegistrationEpoch != 0
                    || _statement.sourceBridgeExecutionHash != bytes32(0)
                    || _statement.preInboxLastAppliedPlusOne != 0
                    || _statement.postInboxLastAppliedPlusOne != 0
            ) {
                revert InvalidMigrationTransitionStatement();
            }
        } else if (
            _statement.importedHeaderHash != bytes32(0)
                || _statement.importedStateRoot != bytes32(0)
                || _statement.legacySignalCheckpointHash != bytes32(0)
                || _statement.legacyDeploymentHash != bytes32(0)
                || _statement.legacyArmId != bytes32(0) || _statement.legacyLaunchId != bytes32(0)
        ) {
            revert InvalidMigrationTransitionStatement();
        }
    }

    /// @dev Computes the canonical empty forced-descriptor-list commitment.
    /// @return commitment_ The empty list commitment at start cursor zero.
    function _emptyForcedDescriptorCommitment() private pure returns (bytes32 commitment_) {
        commitment_ = keccak256(
            abi.encodePacked("slot-chain-force-descriptor-list-v2", uint64(0), uint16(0), uint8(0))
        );
    }

    /// @dev Validates one kind-specific ingress authorization row.
    /// @param _authorization The authorization row to validate.
    function _validateIngressAuthorization(
        SlotChainTypes.ProfileIngressAuthorizationV2 memory _authorization
    )
        private
        pure
    {
        if (
            _authorization.kind > 1 || _authorization.adapter == address(0)
                || _authorization.adapterRuntimeHash == bytes32(0)
                || _authorization.adapterConfigurationHash == bytes32(0)
                || _authorization.activeSettlementRouter == address(0)
                || _authorization.routerRuntimeHash == bytes32(0)
                || _authorization.routerConfigurationHash == bytes32(0)
                || _authorization.forcedQueue == address(0)
                || _authorization.queueRuntimeHash == bytes32(0)
                || _authorization.queueConfigurationHash == bytes32(0)
                || _authorization.destinationChainId == 0 || _authorization.fixedIngressWei == 0
                || _authorization.executionWeiPerAccountedGas == 0
                || _authorization.proofWeiPerAccountedGas == 0
                || _authorization.permanentWeiPerByte == 0
                || _authorization.maximumAcceptedFeeWei == 0
        ) {
            revert InvalidIngressAuthorization();
        }

        if (_authorization.kind == 0) {
            if (
                _authorization.adapterConstructorPoststateCommitment == bytes32(0)
                    || _authorization.sourceDomainId != bytes32(0)
                    || _authorization.sourceRegistrationEpoch != 0
                    || _authorization.sourceBridgeExecutionHash != bytes32(0)
                    || _authorization.destinationDomainId != bytes32(0)
                    || _authorization.destinationBridge != address(0)
                    || _authorization.destinationBridgeExecutionHash != bytes32(0)
                    || _authorization.destinationInfrastructureHash != bytes32(0)
            ) {
                revert InvalidIngressAuthorization();
            }
        } else if (
            _authorization.adapterConstructorPoststateCommitment != bytes32(0)
                || _authorization.sourceDomainId == bytes32(0)
                || _authorization.sourceRegistrationEpoch == 0
                || _authorization.sourceBridgeExecutionHash == bytes32(0)
                || _authorization.destinationDomainId == bytes32(0)
                || _authorization.destinationBridge == address(0)
                || _authorization.destinationBridgeExecutionHash == bytes32(0)
                || _authorization.destinationInfrastructureHash == bytes32(0)
        ) {
            revert InvalidIngressAuthorization();
        }
    }

    /// @dev Validates all locally derivable release-manifest identities and graph joins.
    /// @param _manifest The manifest to validate.
    function _validateReleaseManifest(SlotChainTypes.ReleaseManifestV2 memory _manifest)
        private
        pure
    {
        SlotChainTypes.DestinationBridgeDescriptorV2 memory bridge =
        _manifest.destinationBridgeDescriptor;
        if (
            _manifest.protocolVersion == 0 || _manifest.settlementChainId == 0
                || _manifest.settlementChainId > type(uint64).max
                || _manifest.destinationChainId == 0
                || _manifest.destinationChainId > type(uint64).max
                || _manifest.destinationGenesisHash == bytes32(0)
                || _manifest.executionProfileHash == bytes32(0)
                || _manifest.manifestNamespace == bytes32(0)
                || _manifest.destinationNamespace == bytes32(0) || _manifest.anchorV4 == address(0)
                || _manifest.anchorRuntimeHash == bytes32(0)
                || _manifest.destinationDomainId == bytes32(0)
                || _manifest.destinationBridge == address(0)
                || _manifest.destinationBridgeExecutionHash == bytes32(0)
                || _manifest.destinationInfrastructureHash == bytes32(0)
                || _manifest.migrationVerifierDescriptorHash == bytes32(0)
                || _manifest.ingressAuthorizationRoot == bytes32(0)
                || _manifest.nativeLiquidityPool == address(0)
                || _manifest.poolRuntimeHash == bytes32(0)
                || _manifest.poolConfigurationHash == bytes32(0)
                || !_validDestinationBridgeDescriptor(bridge)
        ) {
            revert InvalidReleaseManifest();
        }

        bytes32 infrastructureHash = _hashDestinationInfrastructure(_manifest.components);
        bytes32 bridgeExecutionHash = _hashDestinationBridgeExecution(bridge);
        if (
            _manifest.destinationInfrastructureHash != infrastructureHash
                || _manifest.destinationBridgeExecutionHash != bridgeExecutionHash
                || _manifest.components[9].component != _manifest.destinationBridge
                || _manifest.components[8].component != _manifest.nativeLiquidityPool
                || _manifest.components[8].runtimeHash != _manifest.poolRuntimeHash
                || _manifest.components[8].configHash != _manifest.poolConfigurationHash
                || bridge.bridge != _manifest.destinationBridge
                || bridge.runtimeHash != _manifest.components[9].runtimeHash
                || bridge.configurationHash != _manifest.components[9].configHash
                || bridge.inboxCreditStore != _manifest.components[4].component
                || bridge.terminalAccumulator != _manifest.components[7].component
                || bridge.terminalDomainRegistrar != _manifest.components[6].component
                || bridge.nativeLiquidityPool != _manifest.nativeLiquidityPool
                || _manifest.destinationDomainId
                    != _hashDestinationDomain(
                        uint64(_manifest.destinationChainId),
                        _manifest.destinationGenesisHash,
                        _manifest.components,
                        _manifest.destinationBridge,
                        bridgeExecutionHash,
                        infrastructureHash,
                        _manifest.destinationNamespace
                    )
        ) {
            revert InvalidReleaseManifest();
        }

        address helper = _forceSendHelper(_manifest.destinationBridge, bridge.bridgeSurplusSink);
        if (
            helper == address(0) || helper == bridge.bridgeSurplusSink
                || bridge.quotaManager == bridge.bridgeSurplusSink || bridge.quotaManager == helper
        ) {
            revert InvalidReleaseManifest();
        }
        // Reclamation retains component positions 3..8 and the Bridge at position 9.
        // The full profile decoder separately authenticates pauser/signal-service and
        // the privileged denyset; those values are not present in this 59-word tuple.
        for (uint256 i; i < 10; ++i) {
            address component = _manifest.components[i].component;
            if (
                i >= 3
                    && (component == bridge.bridgeSurplusSink
                        || component == helper
                        || component == bridge.quotaManager)
            ) {
                revert InvalidReleaseManifest();
            }
            for (uint256 j = i + 1; j < 10; ++j) {
                if (component == _manifest.components[j].component) {
                    revert InvalidReleaseManifest();
                }
            }
        }
    }

    /// @dev Checks the nonzero intrinsic fields of the Bridge descriptor.
    /// @param _descriptor The descriptor to validate.
    /// @return valid_ True only for a structurally nonzero descriptor.
    function _validDestinationBridgeDescriptor(
        SlotChainTypes.DestinationBridgeDescriptorV2 memory _descriptor
    )
        private
        pure
        returns (bool valid_)
    {
        valid_ = _descriptor.bridge != address(0) && _descriptor.runtimeHash != bytes32(0)
            && _descriptor.configurationHash != bytes32(0)
            && _descriptor.storageLayoutHash != bytes32(0)
            && _descriptor.bridgeKernelProfileHash != bytes32(0)
            && _descriptor.inboxCreditStore != address(0)
            && _descriptor.terminalAccumulator != address(0)
            && _descriptor.terminalDomainRegistrar != address(0)
            && _descriptor.quotaManager != address(0)
            && _descriptor.nativeLiquidityPool != address(0)
            && _descriptor.bridgeSurplusSink != address(0);
    }

    /// @dev Hashes the canonical 408-byte destination Bridge execution descriptor.
    /// @param _descriptor The Bridge descriptor.
    /// @return executionHash_ The destination Bridge execution hash.
    function _hashDestinationBridgeExecution(
        SlotChainTypes.DestinationBridgeDescriptorV2 memory _descriptor
    )
        private
        pure
        returns (bytes32 executionHash_)
    {
        address helper = _forceSendHelper(_descriptor.bridge, _descriptor.bridgeSurplusSink);
        bytes memory identity = abi.encodePacked(
            _descriptor.bridge,
            _descriptor.runtimeHash,
            _descriptor.configurationHash,
            _descriptor.storageLayoutHash,
            _descriptor.bridgeKernelProfileHash
        );
        bytes memory topology = abi.encodePacked(
            _descriptor.inboxCreditStore,
            _descriptor.terminalAccumulator,
            _descriptor.terminalDomainRegistrar
        );
        bytes memory accounts = abi.encodePacked(
            _descriptor.quotaManager,
            _descriptor.nativeLiquidityPool,
            _descriptor.bridgeSurplusSink,
            helper
        );
        bytes memory forceSend = abi.encodePacked(
            _forceSendInitcodeHash(_descriptor.bridgeSurplusSink),
            FORCE_SEND_COMPILER_BUILD_HASH,
            FORCE_SEND_EVM_RULES_HASH,
            FORCE_SEND_CREATE2_FIXED_GAS,
            FORCE_SEND_CHILD_GAS,
            FORCE_SEND_POSTCHECK_RESERVE
        );
        bytes memory encoded = bytes.concat(identity, topology, accounts, forceSend);
        assert(identity.length == 148);
        assert(topology.length == 60);
        assert(accounts.length == 80);
        assert(forceSend.length == 120);
        assert(encoded.length == 408);
        executionHash_ = keccak256(
            bytes.concat(
                bytes("slot-chain-destination-bridge-execution-v4"),
                bytes4(uint32(encoded.length)),
                encoded
            )
        );
    }

    /// @dev Hashes the ten ordered 84-byte destination component rows.
    /// @param _components The exact ten release components.
    /// @return infrastructureHash_ The destination infrastructure hash.
    function _hashDestinationInfrastructure(SlotChainTypes
                .ComponentDescriptorV2[10] memory _components)
        private
        pure
        returns (bytes32 infrastructureHash_)
    {
        bytes memory encoded;
        for (uint256 i; i < 10; ++i) {
            SlotChainTypes.ComponentDescriptorV2 memory component = _components[i];
            if (
                component.component == address(0) || component.runtimeHash == bytes32(0)
                    || component.configHash == bytes32(0)
            ) {
                revert InvalidReleaseManifest();
            }
            encoded = bytes.concat(
                encoded,
                abi.encodePacked(component.component, component.runtimeHash, component.configHash)
            );
        }
        assert(encoded.length == 840);
        infrastructureHash_ = keccak256(
            bytes.concat(
                bytes("slot-chain-destination-infrastructure-v3"),
                bytes4(uint32(encoded.length)),
                encoded
            )
        );
    }

    /// @dev Hashes the fixed destination-domain identity rooted in all ten component positions.
    /// @param _destinationChainId The uint64 destination chain ID.
    /// @param _genesisHash The destination genesis hash.
    /// @param _components The ten ordered release components.
    /// @param _bridge The release-owned destination Bridge.
    /// @param _bridgeExecutionHash The derived Bridge execution hash.
    /// @param _infrastructureHash The derived infrastructure hash.
    /// @param _namespace The destination namespace.
    /// @return domainId_ The destination-domain ID.
    function _hashDestinationDomain(
        uint64 _destinationChainId,
        bytes32 _genesisHash,
        SlotChainTypes.ComponentDescriptorV2[10] memory _components,
        address _bridge,
        bytes32 _bridgeExecutionHash,
        bytes32 _infrastructureHash,
        bytes32 _namespace
    )
        private
        pure
        returns (bytes32 domainId_)
    {
        bytes memory identity = abi.encodePacked(
            "slot-chain-destination-domain-v7",
            _destinationChainId,
            _genesisHash,
            _components[0].component,
            _components[1].component,
            _components[2].component,
            _components[3].component
        );
        bytes memory topology = abi.encodePacked(
            _components[4].component,
            _components[5].component,
            _components[6].component,
            _components[7].component,
            _components[8].component
        );
        bytes memory commitments =
            abi.encodePacked(_bridge, _bridgeExecutionHash, _infrastructureHash, _namespace);
        domainId_ = keccak256(bytes.concat(identity, topology, commitments));
    }

    /// @dev Derives the fixed ForceSend init-code hash for one sink.
    /// @param _sink The value recipient embedded in init code.
    /// @return initcodeHash_ The 22-byte init-code hash.
    function _forceSendInitcodeHash(address _sink) private pure returns (bytes32 initcodeHash_) {
        initcodeHash_ = keccak256(abi.encodePacked(hex"73", _sink, hex"ff"));
    }

    /// @dev Derives the one permitted ForceSend CREATE2 child for a Bridge and sink.
    /// @param _bridge The CREATE2 deployer.
    /// @param _sink The sink embedded in the child init code.
    /// @return helper_ The deterministic helper address.
    function _forceSendHelper(
        address _bridge,
        address _sink
    )
        private
        pure
        returns (address helper_)
    {
        bytes32 salt = keccak256(abi.encodePacked("slot-chain-force-send-create2-salt-v1", _bridge));
        helper_ = address(
            uint160(
                uint256(
                    keccak256(
                        bytes.concat(hex"ff", bytes20(_bridge), salt, _forceSendInitcodeHash(_sink))
                    )
                )
            )
        );
    }

    error InvalidExecutionProfileLength();
    error InvalidIngressAuthorizationIds();
    error InvalidIngressAuthorization();
    error InvalidMigrationActivationFixed();
    error InvalidMigrationTransitionStatement();
    error InvalidMigrationVerifierDescriptor();
    error InvalidRegistrationMptVerifierDescriptor();
    error InvalidReleaseManifest();
    error InvalidSettlementValidityVerifierDescriptor();
}
