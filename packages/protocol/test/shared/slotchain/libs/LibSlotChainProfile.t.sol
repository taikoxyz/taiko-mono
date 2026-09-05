// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { SlotChainTypes } from "../../../../contracts/shared/slotchain/SlotChainTypes.sol";
import {
    LibSlotChainProfile
} from "../../../../contracts/shared/slotchain/libs/LibSlotChainProfile.sol";
import { SlotChainGoldenVectors } from "../vectors/SlotChainGoldenVectors.sol";
import { Test } from "forge-std/src/Test.sol";

contract LibSlotChainProfileTest is Test {
    ProfileHarness private harness;

    function setUp() external {
        harness = new ProfileHarness();
    }

    function test_executionProfile_ExactOuterOffsetTailAndGoldenHash() external view {
        bytes memory encoded = _readHex("execution-profile-v2.27.hex");
        assertEq(encoded.length, SlotChainGoldenVectors.EXECUTION_PROFILE_ABI_LENGTH);

        uint256 outerOffset;
        uint256 artifactOffset;
        uint256 artifactLength;
        assembly ("memory-safe") {
            outerOffset := mload(add(encoded, 0x20))
            artifactOffset := mload(add(encoded, 0x2360))
            artifactLength := mload(add(encoded, 0x2380))
        }
        assertEq(outerOffset, 0x20);
        assertEq(artifactOffset, SlotChainGoldenVectors.EXECUTION_PROFILE_CREATION_OFFSET);
        assertEq(artifactLength, 36);
        assertEq(
            harness.hashExecutionProfileBytesUnchecked(encoded),
            SlotChainGoldenVectors.EXECUTION_PROFILE_HASH
        );

        bytes32 fixtureHash = keccak256(encoded);
        assertEq(keccak256(_encodeProfileFixture(encoded)), fixtureHash);
    }

    function test_executionProfileUncheckedHash_EnforcesOnlyPublishedOuterCap() external {
        vm.expectRevert(LibSlotChainProfile.InvalidExecutionProfileLength.selector);
        harness.hashExecutionProfileBytesUnchecked("");

        bytes memory maximum = new bytes(146_848);
        harness.hashExecutionProfileBytesUnchecked(maximum);

        vm.expectRevert(LibSlotChainProfile.InvalidExecutionProfileLength.selector);
        harness.hashExecutionProfileBytesUnchecked(new bytes(146_849));
    }

    function test_releaseManifest_MatchesExact59WordGoldenFixture() external view {
        bytes memory encoded = _readHex("release-v2.27.hex");
        assertEq(encoded.length, 59 * 32);
        assertEq(keccak256(harness.encodeReleaseManifestBytes(encoded)), keccak256(encoded));
        assertEq(
            harness.hashReleaseManifestBytes(encoded), SlotChainGoldenVectors.RELEASE_MANIFEST_HASH
        );
    }

    function test_releaseManifest_RejectsDuplicateComponentAndQuotaAliases() external {
        SlotChainTypes.ReleaseManifestV2 memory manifest = _releaseManifest();
        manifest.components[0].component = manifest.components[1].component;
        _rebindManifest(manifest);
        vm.expectRevert(LibSlotChainProfile.InvalidReleaseManifest.selector);
        harness.encodeReleaseManifestBytes(abi.encode(manifest));

        manifest = _releaseManifest();
        manifest.destinationBridgeDescriptor.quotaManager = manifest.components[3].component;
        _rebindManifest(manifest);
        vm.expectRevert(LibSlotChainProfile.InvalidReleaseManifest.selector);
        harness.encodeReleaseManifestBytes(abi.encode(manifest));

        manifest = _releaseManifest();
        manifest.destinationBridgeDescriptor.quotaManager =
        manifest.destinationBridgeDescriptor.bridgeSurplusSink;
        _rebindManifest(manifest);
        vm.expectRevert(LibSlotChainProfile.InvalidReleaseManifest.selector);
        harness.encodeReleaseManifestBytes(abi.encode(manifest));

        manifest = _releaseManifest();
        manifest.destinationBridgeDescriptor.quotaManager = _forceSendHelper(manifest);
        _rebindManifest(manifest);
        vm.expectRevert(LibSlotChainProfile.InvalidReleaseManifest.selector);
        harness.encodeReleaseManifestBytes(abi.encode(manifest));

        manifest = _releaseManifest();
        manifest.components[3].component = manifest.destinationBridgeDescriptor.bridgeSurplusSink;
        _rebindManifest(manifest);
        vm.expectRevert(LibSlotChainProfile.InvalidReleaseManifest.selector);
        harness.encodeReleaseManifestBytes(abi.encode(manifest));

        manifest = _releaseManifest();
        manifest.components[3].component = _forceSendHelper(manifest);
        _rebindManifest(manifest);
        vm.expectRevert(LibSlotChainProfile.InvalidReleaseManifest.selector);
        harness.encodeReleaseManifestBytes(abi.encode(manifest));
    }

    function test_verifierDescriptors_MatchAllFrozenGoldenVectors() external view {
        SlotChainTypes.SettlementValidityVerifierDescriptorV2 memory settlement =
            _settlementVerifier();
        assertEq(
            harness.settlementValidityVerifierConfigurationHash(settlement),
            0xe5db5d57f15fbf90f9912736d4fb28a7e746b93645cc60b6263e9680e638d73b
        );
        assertEq(
            harness.hashSettlementValidityVerifierDescriptor(settlement),
            0xd0d223ca1adf67fac282bbf40c7d0d64bee73bc2cae211ffe95a521508b18400
        );

        SlotChainTypes.MigrationTransitionVerifierDescriptorV2 memory migration =
            _migrationVerifier();
        assertEq(
            harness.migrationVerifierConfigurationHash(migration),
            SlotChainGoldenVectors.MIGRATION_VERIFIER_CONFIGURATION_HASH
        );
        assertEq(
            harness.hashMigrationVerifierDescriptor(migration),
            0x5cf0838c9793e6a4ec5d2d0e228ec79df192af5731d5b54ae6e08aadc085f9c8
        );

        SlotChainTypes.RegistrationMptVerifierDescriptorV2 memory registration =
            _registrationVerifier();
        assertEq(
            harness.registrationMptVerifierConfigurationHash(registration),
            SlotChainGoldenVectors.REGISTRATION_MPT_VERIFIER_CONFIGURATION_HASH
        );
        assertEq(
            harness.hashRegistrationMptVerifierDescriptor(registration),
            SlotChainGoldenVectors.REGISTRATION_MPT_VERIFIER_DESCRIPTOR_HASH
        );
    }

    function test_migrationVerifier_RejectsNonNormativePublicInputSchema() external {
        SlotChainTypes.MigrationTransitionVerifierDescriptorV2 memory descriptor =
            _migrationVerifier();
        descriptor.publicInputSchemaHash = bytes32(uint256(1));
        vm.expectRevert(LibSlotChainProfile.InvalidMigrationVerifierDescriptor.selector);
        harness.hashMigrationVerifierDescriptor(descriptor);
    }

    function test_registrationStatement_MatchesGoldenVector() external view {
        SlotChainTypes.RegistrationStorageStatementV2 memory statement =
            SlotChainTypes.RegistrationStorageStatementV2({
                settlementChainId: 1,
                activeSettlementRouter: address(0xAD01),
                bridgeDomainRegistry: address(0xD010),
                routeKey: SlotChainGoldenVectors.REGISTRATION_ROUTE_KEY,
                destinationChainId: 16_788,
                protocolVersion: 2,
                canonicalSequence: 1,
                stateRoot: _repeatByte(0x66),
                terminalDomainRegistrar: address(0x5103),
                registrarCodeHash: 0x4821a06eed7b3c4f52ed51529fc729262bdd9af96220c080fc8f2be686aabf9a,
                storageTrieKey: SlotChainGoldenVectors.REGISTRATION_COMMITMENT_TRIE_KEY,
                expectedValue: SlotChainGoldenVectors.DESTINATION_REGISTRATION_COMMITMENT
            });
        assertEq(abi.encode(statement).length, 12 * 32);
        assertEq(
            harness.hashRegistrationStorageStatementBytes(abi.encode(statement)),
            SlotChainGoldenVectors.REGISTRATION_STORAGE_STATEMENT_HASH
        );
    }

    function test_migrationActivationFixed_MatchesExact22WordGoldenVector() external view {
        SlotChainTypes.MigrationActivationFixedV2 memory fixedInput = _versionActivationFixed();
        assertEq(
            harness.encodeMigrationActivationFixedBytes(abi.encode(fixedInput)).length, 22 * 32
        );
        assertEq(
            harness.hashMigrationActivationFixedBytes(abi.encode(fixedInput)),
            SlotChainGoldenVectors.VERSION_ACTIVATION_FIXED_HASH
        );
    }

    function test_migrationActivationFixed_RejectsCrossKindFields() external {
        SlotChainTypes.MigrationActivationFixedV2 memory fixedInput = _versionActivationFixed();
        fixedInput.transitionKind = uint8(SlotChainTypes.MigrationKind.GENESIS_IMPORT);
        vm.expectRevert(LibSlotChainProfile.InvalidMigrationActivationFixed.selector);
        harness.encodeMigrationActivationFixedBytes(abi.encode(fixedInput));

        fixedInput = _versionActivationFixed();
        fixedInput.seatGeneration = 0;
        vm.expectRevert(LibSlotChainProfile.InvalidMigrationActivationFixed.selector);
        harness.encodeMigrationActivationFixedBytes(abi.encode(fixedInput));
    }

    function test_migrationTransitionStatement_MatchesExact46WordGoldenVector() external view {
        SlotChainTypes.MigrationTransitionStatementV2 memory statement =
            _versionMigrationStatement();
        assertEq(abi.encode(statement).length, 46 * 32);
        assertEq(
            harness.hashMigrationTransitionStatementBytes(abi.encode(statement)),
            SlotChainGoldenVectors.VERSION_MIGRATION_STATEMENT_HASH
        );
    }

    function test_migrationTransitionStatement_RejectsCrossKindFields() external {
        SlotChainTypes.MigrationTransitionStatementV2 memory statement =
            _versionMigrationStatement();
        statement.importedHeaderHash = bytes32(uint256(1));
        vm.expectRevert(LibSlotChainProfile.InvalidMigrationTransitionStatement.selector);
        harness.hashMigrationTransitionStatementBytes(abi.encode(statement));

        statement = _versionMigrationStatement();
        statement.releaseSystemTxPosition = 1;
        vm.expectRevert(LibSlotChainProfile.InvalidMigrationTransitionStatement.selector);
        harness.hashMigrationTransitionStatementBytes(abi.encode(statement));
    }

    function test_ingressAuthorizations_MatchTwoIdsAndOrderIndependentRoot() external view {
        SlotChainTypes.ProfileIngressAuthorizationV2[2] memory rows;
        rows[0] = _ingressAuthorization("ingress0-v2.27.hex");
        rows[1] = _ingressAuthorization("ingress1-v2.27.hex");
        assertEq(
            harness.hashIngressAuthorizationBytes(abi.encode(rows[0])),
            SlotChainGoldenVectors.KIND0_INGRESS_AUTHORIZATION_ID
        );
        assertEq(
            harness.hashIngressAuthorizationBytes(abi.encode(rows[1])),
            SlotChainGoldenVectors.KIND1_INGRESS_AUTHORIZATION_ID
        );
        assertEq(
            harness.hashIngressAuthorizationRootBytes(abi.encode(rows[0]), abi.encode(rows[1])),
            SlotChainGoldenVectors.INGRESS_AUTHORIZATION_ROOT
        );
        (rows[0], rows[1]) = (rows[1], rows[0]);
        assertEq(
            harness.hashIngressAuthorizationRootBytes(abi.encode(rows[0]), abi.encode(rows[1])),
            SlotChainGoldenVectors.INGRESS_AUTHORIZATION_ROOT
        );
    }

    function test_ingressAuthorizationRoot_RejectsDuplicateKindsAndAdapters() external {
        SlotChainTypes.ProfileIngressAuthorizationV2[2] memory rows;
        rows[0] = _ingressAuthorization("ingress0-v2.27.hex");
        rows[1] = rows[0];
        rows[1].adapter = address(0x1234);
        vm.expectRevert(LibSlotChainProfile.InvalidIngressAuthorizationIds.selector);
        harness.hashIngressAuthorizationRootBytes(abi.encode(rows[0]), abi.encode(rows[1]));

        rows[1] = _ingressAuthorization("ingress1-v2.27.hex");
        rows[1].adapter = rows[0].adapter;
        vm.expectRevert(LibSlotChainProfile.InvalidIngressAuthorizationIds.selector);
        harness.hashIngressAuthorizationRootBytes(abi.encode(rows[0]), abi.encode(rows[1]));
    }

    function test_reclamationConfig_HasExact35WordStaticEncoding() external view {
        SlotChainTypes.ReclamationConfigV2 memory config;
        config.protocolVersion = 2;
        config.destinationChainId = 16_788;
        config.releaseManifestHash = SlotChainGoldenVectors.RELEASE_MANIFEST_HASH;
        config.registrationCommitment = SlotChainGoldenVectors.DESTINATION_REGISTRATION_COMMITMENT;
        config.executionProfileHash = SlotChainGoldenVectors.EXECUTION_PROFILE_HASH;
        config.destinationDomainId = SlotChainGoldenVectors.DESTINATION_DOMAIN_ID;
        config.destinationBridge = address(0xB200);
        config.bridgeSurplusSink = address(0xBEEF);
        for (uint256 i; i < config.components.length; ++i) {
            config.components[i] = SlotChainTypes.ReclamationComponentV2({
                account: address(uint160(0x1000 + i)),
                runtimeHash: bytes32(0x2000 + i),
                configurationHash: bytes32(0x3000 + i)
            });
        }
        config.forceSendHelper = address(0xCAFE);
        config.forceSendCreate2Salt = bytes32(uint256(0x4001));
        config.forceSendInitcodeHash = bytes32(uint256(0x4002));
        config.forceSendCompilerBuildHash = bytes32(uint256(0x4003));
        config.forceSendEvmRulesHash = bytes32(uint256(0x4004));
        config.forceSendCreate2FixedGas = 33_000;
        config.forceSendChildGas = 75_000;
        config.forceSendPostcheckReserve = 20_000;
        config.forceSendPrecreateGas = 21_000;

        bytes memory canonical = abi.encode(config);
        assertEq(canonical.length, 35 * 32);
        assertEq(harness.encodeReclamationConfigUncheckedBytes(canonical), canonical);
    }

    function test_destinationActivationReceipt_MatchesGoldenVector() external view {
        SlotChainTypes.DestinationActivationReceiptV2 memory receipt =
            SlotChainTypes.DestinationActivationReceiptV2({
                destinationChainId: 16_788,
                terminalDomainRegistrar: address(0x5103),
                successorIndex: 2,
                oldProtocolVersion: 2,
                newProtocolVersion: 3,
                oldManifestHash: SlotChainGoldenVectors.RELEASE_MANIFEST_HASH,
                newManifestHash: SlotChainGoldenVectors.SUCCESSOR_RELEASE_MANIFEST_HASH,
                oldDestinationDomainId: SlotChainGoldenVectors.DESTINATION_DOMAIN_ID,
                newDestinationDomainId: _repeatByte(0x89),
                oldDestinationBridge: address(0xB200),
                newDestinationBridge: address(0xB201),
                retirementQueueCount: 70,
                activatedAtBlock: 1234
            });
        assertEq(
            harness.hashDestinationActivationReceiptBytes(abi.encode(receipt)),
            SlotChainGoldenVectors.DESTINATION_ACTIVATION_RECEIPT_ID
        );
    }

    function _releaseManifest()
        private
        view
        returns (SlotChainTypes.ReleaseManifestV2 memory manifest_)
    {
        manifest_ = abi.decode(_readHex("release-v2.27.hex"), (SlotChainTypes.ReleaseManifestV2));
    }

    function _ingressAuthorization(string memory _filename)
        private
        view
        returns (SlotChainTypes.ProfileIngressAuthorizationV2 memory authorization_)
    {
        bytes memory encoded = _readHex(_filename);
        assertEq(encoded.length, 24 * 32);
        assembly ("memory-safe") {
            authorization_ := add(encoded, 0x20)
        }
    }

    /// @dev Reinterprets the canonical tuple head in the golden fixture as an in-memory struct,
    /// replacing only its final dynamic offset with the absolute bytes-tail pointer expected by
    /// Solidity's memory layout. This avoids generating an enormous external ABI decoder solely
    /// for the 282-field test fixture.
    function _encodeProfileFixture(bytes memory _encoded)
        private
        pure
        returns (bytes memory encoded_)
    {
        SlotChainTypes.ExecutionProfileV2 memory profile;
        assembly ("memory-safe") {
            profile := add(_encoded, 0x40)
            let artifactSlot := add(profile, mul(281, 0x20))
            mstore(artifactSlot, add(profile, mload(artifactSlot)))
        }
        encoded_ = LibSlotChainProfile.encodeExecutionProfileUnchecked(profile);
    }

    function _rebindManifest(SlotChainTypes.ReleaseManifestV2 memory _manifest) private pure {
        _manifest.destinationInfrastructureHash = _infrastructureHash(_manifest.components);
        _manifest.destinationBridgeExecutionHash =
            _bridgeExecutionHash(_manifest.destinationBridgeDescriptor);
        bytes memory identity = abi.encodePacked(
            "slot-chain-destination-domain-v7",
            uint64(_manifest.destinationChainId),
            _manifest.destinationGenesisHash,
            _manifest.components[0].component,
            _manifest.components[1].component,
            _manifest.components[2].component,
            _manifest.components[3].component
        );
        bytes memory topology = abi.encodePacked(
            _manifest.components[4].component,
            _manifest.components[5].component,
            _manifest.components[6].component,
            _manifest.components[7].component,
            _manifest.components[8].component
        );
        bytes memory commitments = abi.encodePacked(
            _manifest.destinationBridge,
            _manifest.destinationBridgeExecutionHash,
            _manifest.destinationInfrastructureHash,
            _manifest.destinationNamespace
        );
        _manifest.destinationDomainId = keccak256(bytes.concat(identity, topology, commitments));
    }

    function _bridgeExecutionHash(SlotChainTypes.DestinationBridgeDescriptorV2 memory _descriptor)
        private
        pure
        returns (bytes32 hash_)
    {
        address helper = _forceSendHelper(_descriptor.bridge, _descriptor.bridgeSurplusSink);
        bytes memory encoded = bytes.concat(
            abi.encodePacked(
                _descriptor.bridge,
                _descriptor.runtimeHash,
                _descriptor.configurationHash,
                _descriptor.storageLayoutHash,
                _descriptor.bridgeKernelProfileHash
            ),
            abi.encodePacked(
                _descriptor.inboxCreditStore,
                _descriptor.terminalAccumulator,
                _descriptor.terminalDomainRegistrar
            ),
            abi.encodePacked(
                _descriptor.quotaManager,
                _descriptor.nativeLiquidityPool,
                _descriptor.bridgeSurplusSink,
                helper
            ),
            abi.encodePacked(
                _forceSendInitcodeHash(_descriptor.bridgeSurplusSink),
                keccak256("slot-chain-force-send-handwritten-osaka-evm-v1"),
                keccak256("slot-chain-force-send-eip-6780-osaka-v1"),
                uint64(33_000),
                uint64(75_000),
                uint64(20_000)
            )
        );
        assertEq(encoded.length, 408);
        hash_ = keccak256(
            bytes.concat(
                bytes("slot-chain-destination-bridge-execution-v4"),
                bytes4(uint32(encoded.length)),
                encoded
            )
        );
    }

    function _infrastructureHash(SlotChainTypes.ComponentDescriptorV2[10] memory _components)
        private
        pure
        returns (bytes32 hash_)
    {
        bytes memory encoded;
        for (uint256 i; i < 10; ++i) {
            encoded = bytes.concat(
                encoded,
                abi.encodePacked(
                    _components[i].component, _components[i].runtimeHash, _components[i].configHash
                )
            );
        }
        hash_ = keccak256(
            bytes.concat(
                bytes("slot-chain-destination-infrastructure-v3"),
                bytes4(uint32(encoded.length)),
                encoded
            )
        );
    }

    function _forceSendHelper(SlotChainTypes.ReleaseManifestV2 memory _manifest)
        private
        pure
        returns (address)
    {
        return _forceSendHelper(
            _manifest.destinationBridge, _manifest.destinationBridgeDescriptor.bridgeSurplusSink
        );
    }

    function _forceSendHelper(address _bridge, address _sink) private pure returns (address) {
        bytes32 salt = keccak256(abi.encodePacked("slot-chain-force-send-create2-salt-v1", _bridge));
        return address(
            uint160(
                uint256(
                    keccak256(
                        bytes.concat(hex"ff", bytes20(_bridge), salt, _forceSendInitcodeHash(_sink))
                    )
                )
            )
        );
    }

    function _forceSendInitcodeHash(address _sink) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(hex"73", _sink, hex"ff"));
    }

    function _versionActivationFixed()
        private
        pure
        returns (SlotChainTypes.MigrationActivationFixedV2 memory fixed_)
    {
        fixed_.transitionKind = uint8(SlotChainTypes.MigrationKind.VERSION_MIGRATION);
        fixed_.migrationGeneration = 2;
        fixed_.seatGeneration = 2;
        fixed_.sourceProtocolVersion = 2;
        fixed_.targetProtocolVersion = 3;
        fixed_.sourceCanonicalSequence = 2;
        fixed_.candidateDigest = SlotChainGoldenVectors.CANDIDATE_COMMITMENT;
        fixed_.outputCore = SlotChainTypes.CanonicalCoreV2({
            l2BlockNumber: 8001,
            tipHash: _repeatByte(0x77),
            tipSlot: 8001,
            stateRoot: _repeatByte(0x66),
            messageCursor: 66,
            winningDataCommitment: SlotChainGoldenVectors.WINNING_DATA,
            nextBaseFee: 101,
            nextExcessBlobGas: 0,
            terminalRoot: SlotChainGoldenVectors.EMPTY_TERMINAL_ROOT,
            terminalCount: 0
        });
        fixed_.proofBeneficiary = address(0xCAFE);
        fixed_.anchorNumber = 1000;
        fixed_.anchorHash = _repeatByte(0x99);
        fixed_.forceCutoff = 66;
        fixed_.preInboxLastAppliedPlusOne = 8001;
    }

    function _settlementVerifier()
        private
        pure
        returns (SlotChainTypes.SettlementValidityVerifierDescriptorV2 memory descriptor_)
    {
        descriptor_ = SlotChainTypes.SettlementValidityVerifierDescriptorV2({
            verifier: address(0x86BBC473a4908e9189B0cCbE25Fcc95Fa93c61FA),
            runtimeHash: 0xeed2a10592205b308e012b44fe52748cbafc6e0722318965c80a391c40e4693c,
            configurationHash: 0xe5db5d57f15fbf90f9912736d4fb28a7e746b93645cc60b6263e9680e638d73b,
            verifyingKeyHash: 0x318023e78771de1bce30f281284ab1f8ec27bc2ebecba107266662f957caa0da,
            proofSystemId: 0x47da2ce657cd889911a96af1b5c8af03dd3e7f05c62c6784b4707ac25932a4ed,
            publicInputSchemaHash: 0xb9313bdbe8b2203bcda0a1d140fb1c0446a7424de6440cde31317eafb654cac4,
            selector: 0x8c6cb224,
            maximumProofBytes: 65_536,
            verificationGasLimit: 2_000_000,
            postVerificationReserveGas: 500_000
        });
    }

    function _versionMigrationStatement()
        private
        pure
        returns (SlotChainTypes.MigrationTransitionStatementV2 memory statement_)
    {
        statement_.settlementChainId = 1;
        statement_.activeSettlementRouter = address(0xAD01);
        statement_.routerRuntimeHash =
        0x4927dde52c089beefab390dec1f67ae6ced29ac0a79cb5c6f313e83c773e4583;
        statement_.routerConfigurationHash =
        0xd67b78fb3c09ef318b5480d12df9cf7389a5a1b8300f5653385bd6e46751b067;
        statement_.transitionKind = uint8(SlotChainTypes.MigrationKind.VERSION_MIGRATION);
        statement_.migrationGeneration = 2;
        statement_.sourceProtocolVersion = 2;
        statement_.targetProtocolVersion = 3;
        statement_.sourceCanonicalSequence = 2;
        statement_.executionProfileHash = SlotChainGoldenVectors.EXECUTION_PROFILE_HASH;
        statement_.targetManifestHash = SlotChainGoldenVectors.SUCCESSOR_RELEASE_MANIFEST_HASH;
        statement_.targetRegistrationHash =
        SlotChainGoldenVectors.SUCCESSOR_TARGET_REGISTRATION_HASH;
        statement_.candidateDigest = SlotChainGoldenVectors.CANDIDATE_COMMITMENT;
        statement_.baseCanonicalHash = SlotChainGoldenVectors.BASE_CANONICAL;
        statement_.outputCanonicalHash =
        0xe0a906feff55df19e14080e17e06867e7900dba0114206e1be5defafcc3b4a7f;
        statement_.forcedQueue = address(0xF000);
        statement_.queueRuntimeHash = _repeatByte(0x5A);
        statement_.queueConfigurationHash = SlotChainGoldenVectors.FORCED_QUEUE_CONFIG_HASH;
        statement_.queueRoot = SlotChainGoldenVectors.FORCED_ROOT;
        statement_.queueCount = 70;
        statement_.startCursor = 2;
        statement_.endCursor = 66;
        statement_.forcedDescriptorCommitment = SlotChainGoldenVectors.FORCED_DESCRIPTORS;
        statement_.proofBeneficiary = address(0xCAFE);
        statement_.anchorNumber = 1000;
        statement_.anchorHash = _repeatByte(0x99);
        statement_.forceRoot = SlotChainGoldenVectors.FORCED_ROOT;
        statement_.forceCutoff = 66;
        statement_.sourceDomainId = SlotChainGoldenVectors.SOURCE_DOMAIN_ID;
        statement_.sourceRegistrationEpoch = 7;
        statement_.sourceBridgeExecutionHash = SlotChainGoldenVectors.BRIDGE_EXECUTION_HASH;
        statement_.releaseSystemCalldataHash =
        0xcc05d3346a01ab81094992cab48e9a82ea71b44ef1edf4bcc3c68b0e1a687473;
        statement_.inboxSystemCalldataHash =
        0x65332d0b3230b33c0ae8bddd8a1f3be8473739f865e73fc8e52f4f99cecc89d7;
        statement_.releaseSystemTxHash =
        0x5a9876d4b17a6eb4eb9e0de596c683babe76b6300cae797f23c793fdb071c829;
        statement_.inboxSystemTxHash =
        0xe572d2122c13b62bd9e0b30bf0d1ba1b583f4f4bbb29177668bf7738a57773e7;
        statement_.releaseSystemTxPosition = 0;
        statement_.inboxSystemTxPosition = 1;
        statement_.deploymentCommitment = SlotChainGoldenVectors.VERSION_DEPLOYMENT_COMMITMENT;
        statement_.preInboxLastAppliedPlusOne = 8001;
        statement_.postInboxLastAppliedPlusOne = 8002;
    }

    function _migrationVerifier()
        private
        pure
        returns (SlotChainTypes.MigrationTransitionVerifierDescriptorV2 memory descriptor_)
    {
        descriptor_ = SlotChainTypes.MigrationTransitionVerifierDescriptorV2({
            verifier: address(0x6001),
            runtimeHash: _repeatByte(0x71),
            configurationHash: SlotChainGoldenVectors.MIGRATION_VERIFIER_CONFIGURATION_HASH,
            verifyingKeyHash: _repeatByte(0x72),
            proofSystemId: _repeatByte(0x73),
            publicInputSchemaHash: SlotChainGoldenVectors.MIGRATION_TRANSITION_STATEMENT_TYPEHASH,
            selector: 0x81a9744d,
            maximumProofBytes: 131_072,
            verificationGasLimit: 4_000_000
        });
    }

    function _registrationVerifier()
        private
        pure
        returns (SlotChainTypes.RegistrationMptVerifierDescriptorV2 memory descriptor_)
    {
        descriptor_ = SlotChainTypes.RegistrationMptVerifierDescriptorV2({
            verifier: address(0x6002),
            runtimeHash: _repeatByte(0x95),
            configurationHash: SlotChainGoldenVectors.REGISTRATION_MPT_VERIFIER_CONFIGURATION_HASH,
            publicInputSchemaHash: SlotChainGoldenVectors.REGISTRATION_STORAGE_STATEMENT_TYPEHASH,
            proofSchemaHash: SlotChainGoldenVectors.REGISTRATION_MPT_PROOF_SCHEMA_HASH,
            selector: 0x33639818,
            maximumNodesPerPath: 65,
            maximumTotalNodes: 130,
            maximumNodeBytes: 600,
            maximumProofBytes: 78_264,
            verificationGasLimit: 11_000_000
        });
    }

    function _readHex(string memory _filename) private view returns (bytes memory data_) {
        data_ = vm.parseBytes(
            vm.trim(vm.readFile(string.concat("test/shared/slotchain/vectors/", _filename)))
        );
    }

    function _repeatByte(uint8 _value) private pure returns (bytes32 result_) {
        result_ = bytes32(type(uint256).max / 255 * _value);
    }
}

contract ProfileHarness {
    function hashExecutionProfileBytesUnchecked(bytes memory _profile)
        external
        pure
        returns (bytes32)
    {
        return LibSlotChainProfile.hashExecutionProfileBytesUnchecked(_profile);
    }

    function encodeReleaseManifestBytes(bytes memory _encoded)
        external
        pure
        returns (bytes memory)
    {
        return LibSlotChainProfile.encodeReleaseManifest(
            abi.decode(_encoded, (SlotChainTypes.ReleaseManifestV2))
        );
    }

    function hashReleaseManifestBytes(bytes memory _encoded) external pure returns (bytes32) {
        return LibSlotChainProfile.hashReleaseManifest(
            abi.decode(_encoded, (SlotChainTypes.ReleaseManifestV2))
        );
    }

    function settlementValidityVerifierConfigurationHash(
        SlotChainTypes.SettlementValidityVerifierDescriptorV2 memory _descriptor
    )
        external
        pure
        returns (bytes32)
    {
        return LibSlotChainProfile.settlementValidityVerifierConfigurationHash(_descriptor);
    }

    function hashSettlementValidityVerifierDescriptor(
        SlotChainTypes.SettlementValidityVerifierDescriptorV2 memory _descriptor
    )
        external
        pure
        returns (bytes32)
    {
        return LibSlotChainProfile.hashSettlementValidityVerifierDescriptor(_descriptor);
    }

    function migrationVerifierConfigurationHash(
        SlotChainTypes.MigrationTransitionVerifierDescriptorV2 memory _descriptor
    )
        external
        pure
        returns (bytes32)
    {
        return LibSlotChainProfile.migrationVerifierConfigurationHash(_descriptor);
    }

    function hashMigrationVerifierDescriptor(
        SlotChainTypes.MigrationTransitionVerifierDescriptorV2 memory _descriptor
    )
        external
        pure
        returns (bytes32)
    {
        return LibSlotChainProfile.hashMigrationVerifierDescriptor(_descriptor);
    }

    function registrationMptVerifierConfigurationHash(
        SlotChainTypes.RegistrationMptVerifierDescriptorV2 memory _descriptor
    )
        external
        pure
        returns (bytes32)
    {
        return LibSlotChainProfile.registrationMptVerifierConfigurationHash(_descriptor);
    }

    function hashRegistrationMptVerifierDescriptor(
        SlotChainTypes.RegistrationMptVerifierDescriptorV2 memory _descriptor
    )
        external
        pure
        returns (bytes32)
    {
        return LibSlotChainProfile.hashRegistrationMptVerifierDescriptor(_descriptor);
    }

    function hashRegistrationStorageStatementBytes(bytes memory _encoded)
        external
        pure
        returns (bytes32)
    {
        SlotChainTypes.RegistrationStorageStatementV2 memory statement;
        assembly ("memory-safe") {
            statement := add(_encoded, 0x20)
        }
        return LibSlotChainProfile.hashRegistrationStorageStatement(statement);
    }

    function encodeMigrationActivationFixedBytes(bytes memory _encoded)
        external
        pure
        returns (bytes memory)
    {
        return LibSlotChainProfile.encodeMigrationActivationFixed(
            abi.decode(_encoded, (SlotChainTypes.MigrationActivationFixedV2))
        );
    }

    function hashMigrationActivationFixedBytes(bytes memory _encoded)
        external
        pure
        returns (bytes32)
    {
        return LibSlotChainProfile.hashMigrationActivationFixed(
            abi.decode(_encoded, (SlotChainTypes.MigrationActivationFixedV2))
        );
    }

    function hashMigrationTransitionStatementBytes(bytes memory _encoded)
        external
        pure
        returns (bytes32)
    {
        SlotChainTypes.MigrationTransitionStatementV2 memory statement;
        assembly ("memory-safe") {
            statement := add(_encoded, 0x20)
        }
        return LibSlotChainProfile.hashMigrationTransitionStatement(statement);
    }

    function hashIngressAuthorizationBytes(bytes memory _encoded) external pure returns (bytes32) {
        SlotChainTypes.ProfileIngressAuthorizationV2 memory authorization;
        assembly ("memory-safe") {
            authorization := add(_encoded, 0x20)
        }
        return LibSlotChainProfile.hashIngressAuthorization(authorization);
    }

    function hashIngressAuthorizationRootBytes(
        bytes memory _first,
        bytes memory _second
    )
        external
        pure
        returns (bytes32)
    {
        SlotChainTypes.ProfileIngressAuthorizationV2 memory first;
        SlotChainTypes.ProfileIngressAuthorizationV2 memory second;
        assembly ("memory-safe") {
            first := add(_first, 0x20)
            second := add(_second, 0x20)
        }
        SlotChainTypes.ProfileIngressAuthorizationV2[2] memory authorizations = [first, second];
        return LibSlotChainProfile.hashIngressAuthorizationRoot(authorizations);
    }

    function encodeReclamationConfigUncheckedBytes(bytes memory _encoded)
        external
        pure
        returns (bytes memory)
    {
        return LibSlotChainProfile.encodeReclamationConfigUnchecked(
            abi.decode(_encoded, (SlotChainTypes.ReclamationConfigV2))
        );
    }

    function hashDestinationActivationReceiptBytes(bytes memory _encoded)
        external
        pure
        returns (bytes32)
    {
        SlotChainTypes.DestinationActivationReceiptV2 memory receipt;
        assembly ("memory-safe") {
            receipt := add(_encoded, 0x20)
        }
        return LibSlotChainProfile.hashDestinationActivationReceipt(receipt);
    }
}
