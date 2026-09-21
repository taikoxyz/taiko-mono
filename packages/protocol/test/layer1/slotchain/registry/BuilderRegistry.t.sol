// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {
    IBuilderRegistry
} from "../../../../contracts/layer1/slotchain/iface/IBuilderRegistry.sol";
import {
    BuilderRegistry as BuilderRegistryFacade,
    BuilderRegistryLogicV1 as BuilderRegistry
} from "../../../../contracts/layer1/slotchain/impl/BuilderRegistry.sol";
import {
    BuilderRegistryLeaseLifecycleFacetV1
} from "../../../../contracts/layer1/slotchain/impl/BuilderRegistryLeaseLifecycleFacetV1.sol";
import {
    BuilderRegistryProofVerifierV1
} from "../../../../contracts/layer1/slotchain/impl/BuilderRegistryProofVerifierV1.sol";
import {
    BuilderRegistrySeatLifecycleFacetV1
} from "../../../../contracts/layer1/slotchain/impl/BuilderRegistrySeatLifecycleFacetV1.sol";
import { SlotChainTypes } from "../../../../contracts/shared/slotchain/SlotChainTypes.sol";
import { LibExactCall } from "../../../../contracts/shared/slotchain/libs/LibExactCall.sol";
import {
    BuilderLeaseTokenMock,
    BuilderLifecycleFacetMock,
    BuilderProofVerifierMock,
    BuilderRegistryDeployHarness,
    BuilderRegistryMerkleTracker,
    BuilderScheduleOracleMock,
    BuilderSettlementMock
} from "./BuilderRegistryTestHelpers.sol";
import { Test } from "forge-std/src/Test.sol";

abstract contract BuilderRegistryTestBase is Test {
    using BuilderRegistryMerkleTracker for BuilderRegistryMerkleTracker.Tree;

    bytes4 internal constant BRC1 = 0x42524331;
    bytes4 internal constant ADS1 = 0x41445331;
    bytes4 internal constant BRS1 = 0x42525331;
    bytes4 internal constant RCV1 = 0x52435631;
    bytes4 internal constant BRG1 = 0x42524731;
    bytes4 internal constant BRV1 = 0x42525631;
    bytes4 internal constant BRE1 = 0x42524531;
    bytes4 internal constant BRM1 = 0x42524d31;
    bytes4 internal constant BRN1 = 0x42524e31;
    bytes4 internal constant BTR1 = 0x42545231;
    bytes4 internal constant BGR1 = 0x42475231;
    bytes4 internal constant BCL1 = 0x42434c31;
    bytes4 internal constant BEV1 = 0x42455631;
    bytes4 internal constant BRF1 = 0x42524631;
    bytes4 internal constant BRK1 = 0x42524b31;
    bytes4 internal constant BRA1 = 0x42524131;
    bytes4 internal constant SST1 = 0x53535431;

    bytes32 internal constant STORAGE_LAYOUT_HASH =
        0x5b676bdd8dd5b37f6353a4b46a59d7d24f6b0cc66b28cf1222b3deafe36402bd;
    bytes32 internal constant SEAT_SELECTOR_SET_HASH =
        0x92e9dd5f246684dbc6137c40eb276993130005222bc31be614359dbc1164bbf5;
    bytes32 internal constant LEASE_SELECTOR_SET_HASH =
        0x895e8723291f0a1f397a981815290e003eab16a87807eadc3b3bc0d805b8fb78;
    bytes32 internal constant SEAT_CONFIGURATION_HASH =
        0x5844c0d5e26f8e8006907c41fcf7c121537202827fa671a15099730c1dd38d6b;
    bytes32 internal constant LEASE_CONFIGURATION_HASH =
        0x768f741248a8cd1b1fc84f9134261736305ad3d373ac5a5b346057a7c1b9680a;

    bytes4 internal constant REWARD_CLASS_SELECTOR = 0x3d273ee7;
    bytes4 internal constant SETTLEMENT_STATE_SELECTOR = 0x5c449b11;
    bytes4 internal constant SCHEDULE_WINDOW_RELEASE_SELECTOR = 0xf4cd9a5e;

    uint8 internal constant TOKEN_DECIMALS = 18;
    uint192 internal constant LEASE = 1000;
    uint192 internal constant MAXIMUM_BOND = 1_000_000;
    uint192 internal constant REPORTER_CAP = 100;
    uint64 internal constant GENESIS = 1_000_000;
    uint64 internal constant EVIDENCE_DELAY = 10_000;
    uint64 internal constant REORG_MARGIN = 2000;
    uint64 internal constant FIRST_MANAGED_WINDOW = 0;
    uint64 internal constant CLAIM_WINDOW = 86_400;
    uint64 internal constant CURRENT_WINDOW = 100;
    uint64 internal constant CURRENT_SLOT = CURRENT_WINDOW * 384 + 37;
    uint256 internal constant L2_CHAIN_ID = 167_000;
    uint64 internal constant PROTOCOL_VERSION = 7;

    address internal constant PENALTY_SINK = address(0xBEEF);

    IBuilderRegistry internal registry;
    BuilderLeaseTokenMock internal token;
    BuilderSettlementMock internal settlement;
    BuilderScheduleOracleMock internal schedule;
    BuilderRegistryProofVerifierV1 internal proofVerifier;
    BuilderRegistrySeatLifecycleFacetV1 internal seatFacet;
    BuilderRegistryLeaseLifecycleFacetV1 internal leaseFacet;
    BuilderRegistryDeployHarness internal deployer;
    IBuilderRegistry.BuilderRewardClassConfigV1[3] internal rewardClasses;

    struct FacetGraph {
        address seat;
        bytes32 seatRuntimeHash;
        bytes32 seatConfigurationHash;
        address lease;
        bytes32 leaseRuntimeHash;
        bytes32 leaseConfigurationHash;
    }

    function setUp() public virtual {
        vm.warp(uint256(GENESIS) + CURRENT_SLOT);
        _setRewardClasses();
        token = new BuilderLeaseTokenMock(TOKEN_DECIMALS);
        settlement = new BuilderSettlementMock();
        schedule = new BuilderScheduleOracleMock();
        proofVerifier = new BuilderRegistryProofVerifierV1();
        seatFacet = new BuilderRegistrySeatLifecycleFacetV1();
        leaseFacet = new BuilderRegistryLeaseLifecycleFacetV1();
        deployer = new BuilderRegistryDeployHarness();
        settlement.setResponse(SETTLEMENT_STATE_SELECTOR, _settlementState(PROTOCOL_VERSION, 1));
        address deployed = deployer.deploy(_registryInitCode(PENALTY_SINK));
        registry = IBuilderRegistry(deployed);
        deployer.activate(deployed);
    }

    function _setRewardClasses() internal {
        rewardClasses[0] = IBuilderRegistry.BuilderRewardClassConfigV1({
            classId: 1,
            nameHash: keccak256("class-1"),
            fixedWei: 10,
            perExecutionGasWei: 1,
            perPublishedByteWei: 2,
            capWei: 1_000_000
        });
        rewardClasses[1] = IBuilderRegistry.BuilderRewardClassConfigV1({
            classId: 2,
            nameHash: keccak256("class-2"),
            fixedWei: 20,
            perExecutionGasWei: 3,
            perPublishedByteWei: 4,
            capWei: 2_000_000
        });
        rewardClasses[2] = IBuilderRegistry.BuilderRewardClassConfigV1({
            classId: 3,
            nameHash: keccak256("class-3"),
            fixedWei: 30,
            perExecutionGasWei: 5,
            perPublishedByteWei: 6,
            capWei: 3_000_000
        });
    }

    function _registryInitCode(address _penaltySink)
        internal
        view
        returns (bytes memory initCode_)
    {
        return _registryInitCodeWithVerifier(
            _penaltySink,
            address(proofVerifier),
            address(proofVerifier).codehash,
            proofVerifier.componentConfigHashV2()
        );
    }

    function _registryInitCodeWithVerifier(
        address _penaltySink,
        address _verifier,
        bytes32 _verifierRuntimeHash,
        bytes32 _verifierConfigurationHash
    )
        internal
        view
        returns (bytes memory initCode_)
    {
        FacetGraph memory facets = _defaultFacetGraph();
        return _registryInitCodeWithFacets(
            _penaltySink, _verifier, _verifierRuntimeHash, _verifierConfigurationHash, facets
        );
    }

    function _registryInitCodeWithFacets(
        address _penaltySink,
        address _verifier,
        bytes32 _verifierRuntimeHash,
        bytes32 _verifierConfigurationHash,
        FacetGraph memory _facets
    )
        internal
        view
        returns (bytes memory initCode_)
    {
        // Word 0 is the pinned activator; the 43-word static config tuple follows (1,408 bytes).
        bytes memory args = new bytes(1408);
        _writeTestWord(args, 0, bytes32(uint256(uint160(address(deployer)))));
        _writeTestWord(args, 1, bytes32(block.chainid));
        _writeTestWord(args, 2, bytes32(L2_CHAIN_ID));
        _writeTestWord(args, 3, bytes32(uint256(uint160(address(token)))));
        _writeTestWord(args, 4, address(token).codehash);
        _writeTestWord(args, 5, bytes32(uint256(TOKEN_DECIMALS)));
        _writeTestWord(args, 6, bytes32(uint256(LEASE)));
        _writeTestWord(args, 7, bytes32(uint256(MAXIMUM_BOND)));
        _writeTestWord(args, 8, bytes32(uint256(REPORTER_CAP)));
        _writeTestWord(args, 9, bytes32(uint256(GENESIS)));
        _writeTestWord(args, 10, bytes32(uint256(EVIDENCE_DELAY)));
        _writeTestWord(args, 11, bytes32(uint256(REORG_MARGIN)));
        _writeTestWord(args, 12, bytes32(uint256(FIRST_MANAGED_WINDOW)));
        _writeTestWord(args, 13, bytes32(uint256(uint160(_penaltySink))));
        _writeTestWord(args, 14, bytes32(uint256(CLAIM_WINDOW)));
        _writeTestWord(args, 15, bytes32(uint256(uint160(address(settlement)))));
        _writeTestWord(args, 16, bytes32(uint256(uint160(address(schedule)))));
        _writeTestWord(args, 17, bytes32(uint256(uint160(_verifier))));
        _writeTestWord(args, 18, _verifierRuntimeHash);
        _writeTestWord(args, 19, _verifierConfigurationHash);
        _writeTestWord(args, 20, bytes32(uint256(uint160(_facets.seat))));
        _writeTestWord(args, 21, _facets.seatRuntimeHash);
        _writeTestWord(args, 22, _facets.seatConfigurationHash);
        _writeTestWord(args, 23, bytes32(uint256(uint160(_facets.lease))));
        _writeTestWord(args, 24, _facets.leaseRuntimeHash);
        _writeTestWord(args, 25, _facets.leaseConfigurationHash);
        for (uint256 i; i < 3; ++i) {
            IBuilderRegistry.BuilderRewardClassConfigV1 memory row = rewardClasses[i];
            uint256 cursor = 26 + i * 6;
            _writeTestWord(args, cursor, bytes32(uint256(row.classId)));
            _writeTestWord(args, cursor + 1, row.nameHash);
            _writeTestWord(args, cursor + 2, bytes32(row.fixedWei));
            _writeTestWord(args, cursor + 3, bytes32(row.perExecutionGasWei));
            _writeTestWord(args, cursor + 4, bytes32(row.perPublishedByteWei));
            _writeTestWord(args, cursor + 5, bytes32(row.capWei));
        }
        initCode_ = bytes.concat(vm.getCode("BuilderRegistry.sol:BuilderRegistry"), args);
        assertEq(initCode_.length - vm.getCode("BuilderRegistry.sol:BuilderRegistry").length, 1408);
    }

    function _writeTestWord(bytes memory _encoded, uint256 _index, bytes32 _value) internal pure {
        assembly ("memory-safe") {
            mstore(add(add(_encoded, 32), mul(_index, 32)), _value)
        }
    }

    function _defaultFacetGraph() internal view returns (FacetGraph memory facets_) {
        facets_.seat = address(seatFacet);
        facets_.seatRuntimeHash = address(seatFacet).codehash;
        facets_.seatConfigurationHash = SEAT_CONFIGURATION_HASH;
        facets_.lease = address(leaseFacet);
        facets_.leaseRuntimeHash = address(leaseFacet).codehash;
        facets_.leaseConfigurationHash = LEASE_CONFIGURATION_HASH;
    }

    /// @dev Exact 128-byte SST1 row `(magic, protocolVersion, mode, activatedAtBlock)`.
    function _settlementState(
        uint64 _protocolVersion,
        uint8 _mode
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encode(SST1, _protocolVersion, _mode, uint64(_mode == 0 ? 0 : 12_345));
    }

    function _emptyCell() internal pure returns (SlotChainTypes.RegistryCellV1 memory cell_) {
        cell_.tombstonedAtL2Slot = type(uint64).max;
    }

    function _cell(
        address _builder,
        uint192 _bond,
        uint64 _registrationIndex,
        bytes32 _trancheRoot
    )
        internal
        pure
        returns (SlotChainTypes.RegistryCellV1 memory cell_)
    {
        cell_ = SlotChainTypes.RegistryCellV1({
            builder: _builder,
            bond: _bond,
            registrationIndex: _registrationIndex,
            effectiveL2Slot: CURRENT_SLOT + 8 * 384,
            trancheRoot: _trancheRoot,
            tombstonedAtL2Slot: type(uint64).max
        });
    }

    function _fundAndApprove(address _builder, uint256 _amount) internal {
        token.mint(_builder, _amount);
        vm.prank(_builder);
        token.approve(address(registry), type(uint256).max);
    }

    function _registerVacant(
        BuilderRegistryMerkleTracker.Tree memory _registryTree,
        BuilderRegistryMerkleTracker.Tree memory _admissionTree,
        BuilderRegistryMerkleTracker.Tree memory _trancheTree,
        address _builder,
        uint192 _bond,
        uint64 _registrationIndex,
        uint8 _activeIndex
    )
        internal
        virtual
        returns (SlotChainTypes.RegistryCellV1 memory cell_)
    {
        bytes memory witness = bytes.concat(
            BuilderRegistryMerkleTracker.encodeProof(_registryTree.proof(_activeIndex)),
            BuilderRegistryMerkleTracker.encodeProof(_admissionTree.proof(_activeIndex))
        );
        uint256 registryBalanceBefore = token.rawBalance(address(registry));
        _fundAndApprove(_builder, _bond);
        vm.prank(_builder);
        (bool ok, bytes memory raw) = address(registry)
            .call(
                abi.encodeCall(
                    IBuilderRegistry.registerBuilderV1,
                    (_bond, _registrationIndex, _activeIndex, witness)
                )
            );
        assertTrue(ok);
        assertEq(raw.length, 192);

        cell_ = _cell(_builder, _bond, _registrationIndex, _trancheTree.root());
        _registryTree.update(
            _activeIndex, BuilderRegistryMerkleTracker.registryLeaf(_activeIndex, true, cell_)
        );
        _admissionTree.update(
            _activeIndex, BuilderRegistryMerkleTracker.admissionLeaf(_activeIndex, true, 1, cell_)
        );
        assertEq(bytes4(_returnWord(raw, 0)), BRG1);
        assertEq(uint64(uint256(_returnWord(raw, 1))), _registrationIndex);
        assertEq(uint8(uint256(_returnWord(raw, 2))), _activeIndex);
        assertEq(uint64(uint256(_returnWord(raw, 3))), CURRENT_SLOT + 8 * 384);
        assertEq(uint64(uint256(_returnWord(raw, 4))), _registrationIndex + 1);
        assertEq(_returnWord(raw, 5), _admissionTree.root());
        assertEq(token.rawBalance(address(registry)), registryBalanceBefore + _bond);
    }

    function _returnWord(bytes memory _raw, uint256 _index) internal pure returns (bytes32 word_) {
        assembly ("memory-safe") {
            word_ := mload(add(add(_raw, 0x20), mul(_index, 0x20)))
        }
    }

    function _assertInitialRoots(
        BuilderRegistryMerkleTracker.Tree memory _registryTree,
        BuilderRegistryMerkleTracker.Tree memory _admissionTree
    )
        internal
        view
    {
        (bytes4 aMagic, uint64 admissionVersion, bytes32 admissionRoot) =
            registry.admissionStateV1();
        (
            bytes4 rMagic,
            uint8 schema,
            uint8 activeCount,
            uint64 registryVersion,
            uint64 registryAdmissionVersion,
            uint256 nextRegistrationIndex,
            bytes32 registryRoot
        ) = registry.scheduleRegistryStateV1();
        assertEq(aMagic, ADS1);
        assertEq(admissionVersion, 0);
        assertEq(admissionRoot, _admissionTree.root());
        assertEq(rMagic, BRS1);
        assertEq(schema, 1);
        assertEq(activeCount, 0);
        assertEq(registryVersion, 0);
        assertEq(registryAdmissionVersion, 0);
        assertEq(nextRegistrationIndex, 0);
        assertEq(registryRoot, _registryTree.root());
    }

    function _stateDigest(address _account) internal view virtual returns (bytes32 digest_) {
        (bool okA, bytes memory admission) =
            address(registry).staticcall(abi.encodeCall(IBuilderRegistry.admissionStateV1, ()));
        (bool okR, bytes memory scheduleState) = address(registry)
            .staticcall(abi.encodeCall(IBuilderRegistry.scheduleRegistryStateV1, ()));
        assertTrue(okA && okR);
        digest_ = keccak256(
            abi.encode(
                admission,
                scheduleState,
                token.rawBalance(address(registry)),
                token.rawBalance(_account)
            )
        );
    }

    function _mutationCalldataMatrix(address _recipient)
        internal
        pure
        returns (bytes[] memory calls_)
    {
        calls_ = new bytes[](9);
        calls_[0] = abi.encodeCall(
            IBuilderRegistry.registerBuilderV1, (uint192(LEASE), uint64(0), uint8(0), bytes(""))
        );
        calls_[1] = abi.encodeCall(
            IBuilderRegistry.reserveBuilderWindowV1, (uint64(0), uint64(CURRENT_WINDOW), bytes(""))
        );
        calls_[2] = abi.encodeCall(IBuilderRegistry.requestBuilderExitV1, (uint64(0)));
        calls_[3] =
            abi.encodeCall(IBuilderRegistry.processBuilderMaintenanceV1, (uint8(1), bytes("")));
        calls_[4] = abi.encodeCall(
            IBuilderRegistry.normalizeBuilderTranchesV1, (_recipient, uint64(0), bytes(""))
        );
        calls_[5] = abi.encodeCall(
            IBuilderRegistry.releaseBuilderTrancheV1,
            (_recipient, uint64(0), uint64(CURRENT_WINDOW), bytes(""))
        );
        calls_[6] = abi.encodeCall(
            IBuilderRegistry.releaseBuilderGenerationV1, (_recipient, uint64(0), bytes(""))
        );
        calls_[7] = abi.encodeCall(IBuilderRegistry.claimBuilderLeaseCreditV1, (_recipient));
        calls_[8] = abi.encodeCall(IBuilderRegistry.submitBuilderEquivocationV1, (bytes("")));
    }

    function _operationLockValue() internal view returns (uint8 lock_) {
        bytes32 packed = vm.load(address(registry), bytes32(uint256(5)));
        lock_ = uint8(uint256(packed) >> 160);
    }
}

contract BuilderRegistryTest is BuilderRegistryTestBase {
    using BuilderRegistryMerkleTracker for BuilderRegistryMerkleTracker.Tree;

    struct TrancheRingContext {
        BuilderRegistryMerkleTracker.Tree registryTree;
        BuilderRegistryMerkleTracker.Tree admissionTree;
        BuilderRegistryMerkleTracker.Tree trancheTree;
        SlotChainTypes.RegistryCellV1 cell;
        SlotChainTypes.TrancheLeafV1 tranche;
        address builder;
        uint16 trancheIndex;
        uint64 wrappedWindow;
    }

    struct MovementBoundaryContext {
        BuilderRegistryMerkleTracker.Tree registryTree;
        BuilderRegistryMerkleTracker.Tree admissionTree;
        BuilderRegistryMerkleTracker.Tree trancheTree;
        SlotChainTypes.RegistryCellV1[2] cells;
        address[2] builders;
    }

    struct ActiveTrancheReleaseContext {
        BuilderRegistryMerkleTracker.Tree registryTree;
        BuilderRegistryMerkleTracker.Tree admissionTree;
        BuilderRegistryMerkleTracker.Tree trancheTree;
        SlotChainTypes.RegistryCellV1 cell;
        SlotChainTypes.TrancheLeafV1 tranche;
        address builder;
        bytes releaseWitness;
        bytes32 reservedLeafHash;
    }

    struct FullTableContext {
        BuilderRegistryMerkleTracker.Tree registryTree;
        BuilderRegistryMerkleTracker.Tree admissionTree;
        BuilderRegistryMerkleTracker.Tree trancheTree;
        address victim;
        address newcomer;
    }

    struct ExitLifecycleContext {
        BuilderRegistryMerkleTracker.Tree registryTree;
        BuilderRegistryMerkleTracker.Tree admissionTree;
        BuilderRegistryMerkleTracker.Tree trancheTree;
        SlotChainTypes.RegistryCellV1 cell;
        address builder;
        uint64 matureWindow;
    }

    struct ReservationContext {
        BuilderRegistryMerkleTracker.Tree registryTree;
        BuilderRegistryMerkleTracker.Tree admissionTree;
        BuilderRegistryMerkleTracker.Tree trancheTree;
        address builder;
    }

    function test_selectorAndFixedReturnWidthsAreFrozen() external view {
        assertEq(IBuilderRegistry.builderRegistryConfigV1.selector, bytes4(0x66f0bd82));
        assertEq(IBuilderRegistry.builderRegistryTopologyHashV1.selector, bytes4(0xa571e34b));
        assertEq(IBuilderRegistry.admissionStateV1.selector, bytes4(0x4a9dfa3f));
        assertEq(IBuilderRegistry.scheduleRegistryStateV1.selector, bytes4(0xad95cea1));
        assertEq(IBuilderRegistry.registerBuilderV1.selector, bytes4(0x5fc42c69));
        assertEq(IBuilderRegistry.reserveBuilderWindowV1.selector, bytes4(0x46a53315));
        assertEq(IBuilderRegistry.requestBuilderExitV1.selector, bytes4(0xc8f20b55));
        assertEq(IBuilderRegistry.processBuilderMaintenanceV1.selector, bytes4(0x0e1ffc68));
        assertEq(IBuilderRegistry.normalizeBuilderTranchesV1.selector, bytes4(0x5e7c8afe));
        assertEq(IBuilderRegistry.releaseBuilderTrancheV1.selector, bytes4(0xf8668bb9));
        assertEq(IBuilderRegistry.releaseBuilderGenerationV1.selector, bytes4(0xe7bae370));
        assertEq(IBuilderRegistry.claimBuilderLeaseCreditV1.selector, bytes4(0x8f73793c));
        assertEq(IBuilderRegistry.submitBuilderEquivocationV1.selector, bytes4(0x979c1f72));
        assertEq(BuilderRegistryFacade.activateRegistryV1.selector, bytes4(0xe46a18ce));
        assertEq(BuilderRegistryFacade.registryActivationV1.selector, bytes4(0xa2dee6ae));

        _assertStaticReturnLength(IBuilderRegistry.builderRegistryConfigV1.selector, 768);
        _assertStaticReturnLength(IBuilderRegistry.builderRegistryTopologyHashV1.selector, 32);
        _assertStaticReturnLength(BuilderRegistryFacade.registryActivationV1.selector, 96);
        _assertStaticReturnLength(IBuilderRegistry.admissionStateV1.selector, 96);
        _assertStaticReturnLength(IBuilderRegistry.scheduleRegistryStateV1.selector, 224);
    }

    function test_facetDescriptorsAndIndependentConfigurationHashesAreExact() external view {
        bytes memory seatSelectors = abi.encodePacked(
            uint8(1),
            uint8(3),
            IBuilderRegistry.registerBuilderV1.selector,
            IBuilderRegistry.requestBuilderExitV1.selector,
            IBuilderRegistry.processBuilderMaintenanceV1.selector
        );
        bytes memory leaseSelectors = abi.encodePacked(
            uint8(2),
            uint8(4),
            IBuilderRegistry.reserveBuilderWindowV1.selector,
            IBuilderRegistry.normalizeBuilderTranchesV1.selector,
            IBuilderRegistry.releaseBuilderTrancheV1.selector,
            IBuilderRegistry.releaseBuilderGenerationV1.selector
        );
        bytes32 derivedSeatSelectorHash = keccak256(
            abi.encodePacked(
                "slot-chain-builder-registry-facet-selectors-v1",
                uint16(seatSelectors.length),
                seatSelectors
            )
        );
        bytes32 derivedLeaseSelectorHash = keccak256(
            abi.encodePacked(
                "slot-chain-builder-registry-facet-selectors-v1",
                uint16(leaseSelectors.length),
                leaseSelectors
            )
        );
        assertEq(derivedSeatSelectorHash, SEAT_SELECTOR_SET_HASH);
        assertEq(derivedLeaseSelectorHash, LEASE_SELECTOR_SET_HASH);
        assertEq(
            keccak256(
                abi.encodePacked(
                    "slot-chain-builder-registry-lifecycle-facet-config-v1",
                    uint8(1),
                    STORAGE_LAYOUT_HASH,
                    derivedSeatSelectorHash
                )
            ),
            SEAT_CONFIGURATION_HASH
        );
        assertEq(
            keccak256(
                abi.encodePacked(
                    "slot-chain-builder-registry-lifecycle-facet-config-v1",
                    uint8(2),
                    STORAGE_LAYOUT_HASH,
                    derivedLeaseSelectorHash
                )
            ),
            LEASE_CONFIGURATION_HASH
        );
        _assertFacetDescriptor(
            address(seatFacet), 1, SEAT_SELECTOR_SET_HASH, SEAT_CONFIGURATION_HASH
        );
        _assertFacetDescriptor(
            address(leaseFacet), 2, LEASE_SELECTOR_SET_HASH, LEASE_CONFIGURATION_HASH
        );
    }

    function test_directFacetCallsRejectEveryMutationOutsideRegistryContext() external {
        bytes[] memory calls = _mutationCalldataMatrix(address(this));
        bool[9] memory seatOwned = [true, false, true, true, false, false, false, false, false];
        bool[9] memory leaseOwned = [false, true, false, false, true, true, true, false, false];
        bytes4 unsupported = BuilderRegistrySeatLifecycleFacetV1.UnsupportedFacetSelector.selector;
        for (uint256 i; i < calls.length; ++i) {
            _assertTargetRevertsSelector(
                address(seatFacet),
                calls[i],
                seatOwned[i] ? BuilderRegistry.RegistryInactive.selector : unsupported
            );
            _assertTargetRevertsSelector(
                address(leaseFacet),
                calls[i],
                leaseOwned[i] ? BuilderRegistry.RegistryInactive.selector : unsupported
            );
        }
    }

    function test_changedFacetCodeFailsClosedButFacadeCoreRemainsLocal() external {
        bytes32 beforeDigest = _stateDigest(address(this));
        vm.etch(address(seatFacet), hex"00");
        _assertCallRevertsSelector(
            _mutationCalldataMatrix(address(this))[0],
            BuilderRegistryFacade.LifecycleFacetCodeChanged.selector
        );
        assertEq(_stateDigest(address(this)), beforeDigest);
        assertEq(_operationLockValue(), 0);

        vm.etch(address(leaseFacet), hex"00");
        _assertCallRevertsSelector(
            _mutationCalldataMatrix(address(this))[1],
            BuilderRegistryFacade.LifecycleFacetCodeChanged.selector
        );
        assertEq(_stateDigest(address(this)), beforeDigest);
        assertEq(_operationLockValue(), 0);

        _assertCallRevertsSelector(
            abi.encodeCall(IBuilderRegistry.claimBuilderLeaseCreditV1, (address(this))),
            BuilderRegistry.EmptyBuilderCredit.selector
        );
        _assertCallRevertsSelector(
            abi.encodeCall(IBuilderRegistry.submitBuilderEquivocationV1, (bytes(""))),
            BuilderRegistry.InvalidEquivocationEvidence.selector
        );
        assertEq(_operationLockValue(), 0);
    }

    function test_dispatchBubblesExactReturnAndRevertAndRejects225Bytes() external {
        bytes memory registerCall = _mutationCalldataMatrix(address(this))[0];

        registry = _deployWithSeatMock(224, false);
        (bool ok, bytes memory returndata) = address(registry).call(registerCall);
        assertTrue(ok);
        assertEq(returndata.length, 224);
        assertEq(bytes4(returndata), bytes4(0xfeedbeef));
        assertEq(_operationLockValue(), 0);

        registry = _deployWithSeatMock(36, true);
        (ok, returndata) = address(registry).call(registerCall);
        assertFalse(ok);
        assertEq(returndata, bytes.concat(bytes4(0xfeedbeef), bytes32(uint256(0x1234))));
        assertEq(_operationLockValue(), 0);

        registry = _deployWithSeatMock(225, false);
        _assertCallRevertsSelector(
            registerCall, BuilderRegistryFacade.LifecycleFacetReturnDataTooLarge.selector
        );
        assertEq(_operationLockValue(), 0);
    }

    function test_constructorRejectsEveryFacetDescriptorSubstitution() external {
        for (uint8 fault = 1; fault <= 7; ++fault) {
            BuilderLifecycleFacetMock faultySeat = new BuilderLifecycleFacetMock(1, fault, 0, false);
            FacetGraph memory facets = _defaultFacetGraph();
            facets.seat = address(faultySeat);
            facets.seatRuntimeHash = address(faultySeat).codehash;
            bytes memory initCode = _registryInitCodeWithFacets(
                PENALTY_SINK,
                address(proofVerifier),
                address(proofVerifier).codehash,
                proofVerifier.componentConfigHashV2(),
                facets
            );
            // Faults 1-6 corrupt the BRF1 descriptor; fault 7 corrupts the component config read.
            vm.expectPartialRevert(
                fault == 7
                    ? LibExactCall.ExactConfigurationMismatch.selector
                    : BuilderRegistryFacade.InvalidLifecycleFacetConfiguration.selector
            );
            deployer.deploy(initCode);
        }
    }

    function test_initialRootsAndConfigAreExact() external view {
        BuilderRegistryMerkleTracker.Tree memory registryTree =
            BuilderRegistryMerkleTracker.emptyRegistryTree();
        BuilderRegistryMerkleTracker.Tree memory admissionTree =
            BuilderRegistryMerkleTracker.emptyAdmissionTree();
        _assertInitialRoots(registryTree, admissionTree);

        (bool ok, bytes memory raw) =
            address(registry).staticcall(abi.encodeWithSelector(0x66f0bd82));
        assertTrue(ok);
        assertEq(raw.length, 768);
        assertEq(bytes4(raw), BRC1);
        bytes32 encodedTopologyHash;
        assembly ("memory-safe") {
            encodedTopologyHash := mload(add(raw, 768))
        }
        assertEq(registry.builderRegistryTopologyHashV1(), encodedTopologyHash);
        assertEq(uint256(_word(raw, 2)), L2_CHAIN_ID);
        assertEq(address(uint160(uint256(_word(raw, 16)))), address(deployer));
        assertEq(address(uint160(uint256(_word(raw, 17)))), address(settlement));
        assertEq(address(uint160(uint256(_word(raw, 18)))), address(schedule));
    }

    function test_economicAndTopologyHashesMatchIndependentByteOracle() external view {
        (bool ok, bytes memory raw) =
            address(registry).staticcall(abi.encodeWithSelector(0x66f0bd82));
        assertTrue(ok);
        assertEq(address(uint160(uint256(_word(raw, 19)))), address(proofVerifier));
        assertEq(_word(raw, 20), address(proofVerifier).codehash);
        assertEq(_word(raw, 21), proofVerifier.componentConfigHashV2());
        bytes32 economicHash = _word(raw, 22);
        bytes32 topologyHash = _word(raw, 23);
        uint64 lastManagedWindow = uint64(uint256(_word(raw, 13)));
        assertEq(economicHash, _independentEconomicHash(LEASE, rewardClasses[0].nameHash));
        assertEq(
            topologyHash, _independentTopologyHash(lastManagedWindow, economicHash, PENALTY_SINK)
        );
        assertNotEq(economicHash, _independentEconomicHash(LEASE + 1, rewardClasses[0].nameHash));
        assertNotEq(economicHash, _independentEconomicHash(LEASE, keccak256("mutated-class")));
        assertNotEq(
            topologyHash, _independentTopologyHash(lastManagedWindow, economicHash, address(0xDEAD))
        );
    }

    function test_constructorRejectsEconomicRuntimeClassAndWindowBoundaries() external {
        _expectConstructorWordRevert(0, 0, BuilderRegistryFacade.InvalidRegistryActivator.selector);
        _expectConstructorWordRevert(
            1, block.chainid + 1, BuilderRegistry.InvalidBuilderRegistryConfiguration.selector
        );
        _expectConstructorWordRevert(
            2, 0, BuilderRegistry.InvalidBuilderRegistryConfiguration.selector
        );
        _expectConstructorWordRevert(
            4, uint256(keccak256("wrong-token-runtime")), LibExactCall.ExactRuntimeMismatch.selector
        );
        _expectConstructorWordRevert(
            5, TOKEN_DECIMALS + 1, BuilderRegistry.BuilderTokenDecimalsMismatch.selector
        );
        _expectConstructorWordRevert(
            6, 0, BuilderRegistry.InvalidBuilderRegistryConfiguration.selector
        );
        _expectConstructorWordRevert(
            6, MAXIMUM_BOND + 1, BuilderRegistry.InvalidBuilderRegistryConfiguration.selector
        );
        _expectConstructorWordRevert(
            8, LEASE / 5 + 1, BuilderRegistry.InvalidBuilderRegistryConfiguration.selector
        );
        _expectConstructorWordRevert(
            12, type(uint64).max, BuilderRegistry.InvalidManagedWindowRange.selector
        );
        _expectConstructorWordRevert(
            15, 0, BuilderRegistry.InvalidBuilderRegistryConfiguration.selector
        );
        _expectConstructorWordRevert(
            15,
            uint256(uint160(address(schedule))),
            BuilderRegistry.InvalidBuilderRegistryConfiguration.selector
        );
        _expectConstructorWordRevert(
            16, 0, BuilderRegistry.InvalidBuilderRegistryConfiguration.selector
        );
        _expectConstructorWordRevert(
            17, 0, BuilderRegistry.InvalidBuilderRegistryConfiguration.selector
        );
        _expectConstructorWordRevert(
            18,
            uint256(keccak256("wrong-verifier-runtime")),
            LibExactCall.ExactRuntimeMismatch.selector
        );
        _expectConstructorWordRevert(
            19,
            uint256(keccak256("wrong-verifier-configuration")),
            BuilderRegistry.InvalidBuilderProofVerifier.selector
        );
        _expectConstructorWordRevert(
            20, 0, BuilderRegistryFacade.InvalidLifecycleFacetConfiguration.selector
        );
        _expectConstructorWordRevert(
            21, uint256(keccak256("wrong-seat-runtime")), LibExactCall.ExactRuntimeMismatch.selector
        );
        _expectConstructorWordRevert(
            22,
            uint256(keccak256("wrong-seat-configuration")),
            BuilderRegistryFacade.InvalidLifecycleFacetConfiguration.selector
        );
        _expectConstructorWordRevert(
            23, 0, BuilderRegistryFacade.InvalidLifecycleFacetConfiguration.selector
        );
        _expectConstructorWordRevert(
            24,
            uint256(keccak256("wrong-lease-runtime")),
            LibExactCall.ExactRuntimeMismatch.selector
        );
        _expectConstructorWordRevert(
            25,
            uint256(keccak256("wrong-lease-configuration")),
            BuilderRegistryFacade.InvalidLifecycleFacetConfiguration.selector
        );
        _expectConstructorWordRevert(
            26, 0, BuilderRegistry.InvalidRewardClassConfiguration.selector
        );
        _expectConstructorWordRevert(
            27, 0, BuilderRegistry.InvalidRewardClassConfiguration.selector
        );
    }

    function test_constructorLiabilityResidenceAccepts267AndRejects268() external {
        bytes memory accepted = _registryInitCode(PENALTY_SINK);
        _writeConstructorWord(accepted, 10, uint256(248 * 384));
        _writeConstructorWord(accepted, 11, 0);
        address deployed = deployer.deploy(accepted);
        assertGt(deployed.code.length, 0);

        address expectedRegistry = _nextRegistryAddress();
        bytes memory rejected = _registryInitCode(PENALTY_SINK);
        _writeConstructorWord(rejected, 10, uint256(248 * 384 + 1));
        _writeConstructorWord(rejected, 11, 0);
        vm.expectRevert(BuilderRegistry.InvalidLiabilityResidence.selector);
        deployer.deploy(rejected);
        assertEq(expectedRegistry.code.length, 0);
    }

    function test_constructorRejectsSelfPenaltySink() external {
        address expectedRegistry = _nextRegistryAddress();
        bytes memory initCode = _registryInitCode(PENALTY_SINK);
        _writeConstructorWord(initCode, 13, uint256(uint160(expectedRegistry)));

        vm.expectRevert(BuilderRegistry.InvalidBuilderRegistryConfiguration.selector);
        deployer.deploy(initCode);
        assertEq(expectedRegistry.code.length, 0);
    }

    function test_constructorRejectsRegistryAsProofVerifier() external {
        address expectedRegistry = _nextRegistryAddress();
        bytes memory initCode = _registryInitCode(PENALTY_SINK);
        _writeConstructorWord(initCode, 17, uint256(uint160(expectedRegistry)));

        vm.expectRevert(BuilderRegistryFacade.InvalidLifecycleFacetConfiguration.selector);
        deployer.deploy(initCode);
        assertEq(expectedRegistry.code.length, 0);
    }

    function test_activateRegistryV1_OneShotByPinnedActivatorOnly() external {
        deployer = new BuilderRegistryDeployHarness();
        BuilderRegistryFacade inactive =
            BuilderRegistryFacade(deployer.deploy(_registryInitCode(PENALTY_SINK)));
        (bytes4 magic, address activator, uint8 state) = inactive.registryActivationV1();
        assertEq(magic, BRA1);
        assertEq(activator, address(deployer));
        assertEq(state, 0);

        // Pre-activation read allowlist: BRC1, the topology hash and the activation row read;
        // every functional read and mutation rejects with RegistryInactive.
        (bool configOk, bytes memory configRaw) = address(inactive)
            .staticcall(abi.encodePacked(IBuilderRegistry.builderRegistryConfigV1.selector));
        assertTrue(configOk);
        assertEq(configRaw.length, 768);
        assertEq(_word(configRaw, 23), inactive.builderRegistryTopologyHashV1());
        bytes memory registerCall = _mutationCalldataMatrix(address(this))[0];
        _assertTargetRevertsSelector(
            address(inactive), registerCall, BuilderRegistry.RegistryInactive.selector
        );
        _assertTargetRevertsSelector(
            address(inactive),
            abi.encodePacked(IBuilderRegistry.admissionStateV1.selector),
            BuilderRegistry.RegistryInactive.selector
        );
        vm.expectRevert(BuilderRegistryFacade.UnauthorizedRegistryActivator.selector);
        inactive.activateRegistryV1();

        vm.recordLogs();
        assertEq(deployer.activate(address(inactive)), BRK1);
        assertEq(vm.getRecordedLogs().length, 0);
        (magic, activator, state) = inactive.registryActivationV1();
        assertEq(magic, BRA1);
        assertEq(activator, address(deployer));
        assertEq(state, 1);

        vm.expectRevert(BuilderRegistryFacade.RegistryAlreadyActivated.selector);
        deployer.activate(address(inactive));
        (bool ok, bytes memory returndata) = address(inactive).call(registerCall);
        assertFalse(ok);
        assertNotEq(bytes4(returndata), BuilderRegistry.RegistryInactive.selector);
    }

    function test_rewardClassV1ExactRowsAndStrictCalldata() external view {
        bytes32 configurationHash = registry.componentConfigHashV2();
        for (uint8 classId = 1; classId <= 3; ++classId) {
            (bool ok, bytes memory raw) =
                address(registry).staticcall(abi.encodeWithSelector(REWARD_CLASS_SELECTOR, classId));
            assertTrue(ok);
            assertEq(raw.length, 224);
            (
                bytes4 magic,
                bytes32 returnedConfigurationHash,
                uint8 returnedClass,
                uint256 fixedWei,
                uint256 perExecutionGasWei,
                uint256 perPublishedByteWei,
                uint256 capWei
            ) = abi.decode(raw, (bytes4, bytes32, uint8, uint256, uint256, uint256, uint256));
            IBuilderRegistry.BuilderRewardClassConfigV1 memory expected = rewardClasses[classId - 1];
            assertEq(magic, RCV1);
            assertEq(returnedConfigurationHash, configurationHash);
            assertEq(returnedClass, classId);
            assertEq(fixedWei, expected.fixedWei);
            assertEq(perExecutionGasWei, expected.perExecutionGasWei);
            assertEq(perPublishedByteWei, expected.perPublishedByteWei);
            assertEq(capWei, expected.capWei);
        }

        _assertStaticCallFails(abi.encodeWithSelector(REWARD_CLASS_SELECTOR, uint256(0)));
        _assertStaticCallFails(abi.encodeWithSelector(REWARD_CLASS_SELECTOR, uint256(4)));
        _assertStaticCallFails(
            abi.encodePacked(REWARD_CLASS_SELECTOR, bytes31(hex"01"), bytes1(uint8(1)))
        );
        _assertStaticCallFails(
            bytes.concat(abi.encodeWithSelector(REWARD_CLASS_SELECTOR, uint8(1)), hex"00")
        );
    }

    function test_firstAndSixtyFourthBuilderOccupyBoundaryCells() external {
        BuilderRegistryMerkleTracker.Tree memory registryTree =
            BuilderRegistryMerkleTracker.emptyRegistryTree();
        BuilderRegistryMerkleTracker.Tree memory admissionTree =
            BuilderRegistryMerkleTracker.emptyAdmissionTree();
        BuilderRegistryMerkleTracker.Tree memory trancheTree =
            BuilderRegistryMerkleTracker.emptyTrancheTree();
        _assertInitialRoots(registryTree, admissionTree);

        for (uint8 i; i < 64; ++i) {
            address builder = vm.addr(uint256(i) + 1);
            _registerVacant(registryTree, admissionTree, trancheTree, builder, LEASE, i, i);
        }

        (
            bytes4 magic,
            uint8 schema,
            uint8 count,
            uint64 registryVersion,
            uint64 admissionVersion,
            uint256 nextRegistrationIndex,
            bytes32 registryRoot
        ) = registry.scheduleRegistryStateV1();
        assertEq(magic, BRS1);
        assertEq(schema, 1);
        assertEq(count, 64);
        assertEq(registryVersion, 64);
        assertEq(admissionVersion, 64);
        assertEq(nextRegistrationIndex, 64);
        assertEq(registryRoot, BuilderRegistryMerkleTracker.root(registryTree));
        (, uint64 aVersion, bytes32 admissionRoot) = registry.admissionStateV1();
        assertEq(aVersion, 64);
        assertEq(admissionRoot, BuilderRegistryMerkleTracker.root(admissionTree));
        assertEq(token.rawBalance(address(registry)), uint256(64) * LEASE);
    }

    function test_entryRunwayAcceptsLastEligibleSlotAndRejectsTheNextSlot() external {
        BuilderRegistryMerkleTracker.Tree memory registryTree =
            BuilderRegistryMerkleTracker.emptyRegistryTree();
        BuilderRegistryMerkleTracker.Tree memory admissionTree =
            BuilderRegistryMerkleTracker.emptyAdmissionTree();
        uint64 lastManagedWindow = uint64(uint256(_word(_configBytes(), 13)));
        uint256 entryDelaySlots = uint256(8) * 384;
        uint256 lastEligibleSlot = (uint256(lastManagedWindow) + 1) * 384 - 1 - entryDelaySlots;
        vm.warp(uint256(GENESIS) + lastEligibleSlot);

        address acceptedBuilder = vm.addr(1);
        _fundAndApprove(acceptedBuilder, LEASE);
        bytes memory witness = bytes.concat(
            BuilderRegistryMerkleTracker.encodeProof(registryTree.proof(0)),
            BuilderRegistryMerkleTracker.encodeProof(admissionTree.proof(0))
        );
        vm.prank(acceptedBuilder);
        (,, uint8 activeIndex, uint64 effectiveL2Slot,,) =
            registry.registerBuilderV1(LEASE, 0, 0, witness);
        assertEq(activeIndex, 0);
        assertEq(effectiveL2Slot, lastEligibleSlot + entryDelaySlots);
        assertEq(uint256(effectiveL2Slot) / 384, lastManagedWindow);

        vm.warp(uint256(GENESIS) + lastEligibleSlot + 1);
        address rejectedBuilder = vm.addr(2);
        _fundAndApprove(rejectedBuilder, LEASE);
        bytes32 beforeRejected = _stateDigest(rejectedBuilder);
        vm.expectRevert(BuilderRegistry.BuilderEntryBeyondManagedRange.selector);
        vm.prank(rejectedBuilder);
        registry.registerBuilderV1(LEASE, 1, 1, hex"");
        assertEq(_stateDigest(rejectedBuilder), beforeRejected);
    }

    function test_registerRejectsRaceBoundsAndMalformedWitnessWithFullRollback() external {
        BuilderRegistryMerkleTracker.Tree memory registryTree =
            BuilderRegistryMerkleTracker.emptyRegistryTree();
        BuilderRegistryMerkleTracker.Tree memory admissionTree =
            BuilderRegistryMerkleTracker.emptyAdmissionTree();
        address builder = vm.addr(1);
        _fundAndApprove(builder, MAXIMUM_BOND * 4);
        bytes memory witness = bytes.concat(
            BuilderRegistryMerkleTracker.encodeProof(registryTree.proof(0)),
            BuilderRegistryMerkleTracker.encodeProof(admissionTree.proof(0))
        );
        bytes32 beforeDigest = _stateDigest(builder);

        vm.startPrank(builder);
        vm.expectRevert(BuilderRegistry.InvalidBuilderRegistration.selector);
        registry.registerBuilderV1(LEASE - 1, 0, 0, witness);
        assertEq(_stateDigest(builder), beforeDigest);
        vm.expectRevert(BuilderRegistry.InvalidBuilderRegistration.selector);
        registry.registerBuilderV1(MAXIMUM_BOND + 1, 0, 0, witness);
        assertEq(_stateDigest(builder), beforeDigest);
        vm.expectRevert(BuilderRegistry.InvalidBuilderRegistration.selector);
        registry.registerBuilderV1(LEASE, 1, 0, witness);
        assertEq(_stateDigest(builder), beforeDigest);
        vm.expectRevert(BuilderRegistry.ActiveIndexRace.selector);
        registry.registerBuilderV1(LEASE, 0, 1, witness);
        assertEq(_stateDigest(builder), beforeDigest);
        vm.expectRevert(BuilderRegistry.InvalidVacantRegistrationWitness.selector);
        registry.registerBuilderV1(LEASE, 0, 0, bytes.concat(witness, hex"00"));
        assertEq(_stateDigest(builder), beforeDigest);
        vm.stopPrank();
    }

    function testFuzz_registrationAcceptsEveryInclusiveUint192Bond(uint192 _rawBond) external {
        uint192 bond = uint192(bound(_rawBond, LEASE, MAXIMUM_BOND));
        BuilderRegistryMerkleTracker.Tree memory registryTree =
            BuilderRegistryMerkleTracker.emptyRegistryTree();
        BuilderRegistryMerkleTracker.Tree memory admissionTree =
            BuilderRegistryMerkleTracker.emptyAdmissionTree();
        BuilderRegistryMerkleTracker.Tree memory trancheTree =
            BuilderRegistryMerkleTracker.emptyTrancheTree();
        address builder = vm.addr(1);
        SlotChainTypes.RegistryCellV1 memory cell =
            _registerVacant(registryTree, admissionTree, trancheTree, builder, bond, 0, 0);
        assertEq(cell.bond, bond);
        assertEq(token.rawBalance(address(registry)), bond);
        (,,,,,, bytes32 root) = registry.scheduleRegistryStateV1();
        assertEq(root, registryTree.root());
        (, uint64 admissionVersion, bytes32 admissionRoot) = registry.admissionStateV1();
        assertEq(admissionVersion, 1);
        assertEq(admissionRoot, admissionTree.root());
    }

    function test_registrationAcceptsUint64MaxOnceThenPermanentlyExhaustsIdentifierSpace()
        external
    {
        BuilderRegistryMerkleTracker.Tree memory registryTree =
            BuilderRegistryMerkleTracker.emptyRegistryTree();
        BuilderRegistryMerkleTracker.Tree memory admissionTree =
            BuilderRegistryMerkleTracker.emptyAdmissionTree();
        bytes memory witness = bytes.concat(
            BuilderRegistryMerkleTracker.encodeProof(registryTree.proof(0)),
            BuilderRegistryMerkleTracker.encodeProof(admissionTree.proof(0))
        );
        vm.store(address(registry), bytes32(uint256(6861)), bytes32(uint256(type(uint64).max)));

        address finalBuilder = vm.addr(1);
        _fundAndApprove(finalBuilder, LEASE);
        vm.prank(finalBuilder);
        (
            bytes4 magic,
            uint64 registrationIndex,
            uint8 activeIndex,
            uint64 effectiveL2Slot,
            uint64 admissionVersion,
            bytes32 admissionRoot
        ) = registry.registerBuilderV1(LEASE, type(uint64).max, 0, witness);
        assertEq(magic, BRG1);
        assertEq(registrationIndex, type(uint64).max);
        assertEq(activeIndex, 0);
        assertEq(effectiveL2Slot, CURRENT_SLOT + 8 * 384);
        assertEq(admissionVersion, 1);
        assertTrue(admissionRoot != bytes32(0));
        (,,,,, uint256 nextRegistrationIndex,) = registry.scheduleRegistryStateV1();
        assertEq(nextRegistrationIndex, uint256(type(uint64).max) + 1);

        address rejectedBuilder = vm.addr(2);
        _fundAndApprove(rejectedBuilder, LEASE);
        bytes32 beforeExhausted = _stateDigest(rejectedBuilder);
        vm.expectRevert(BuilderRegistry.InvalidBuilderRegistration.selector);
        vm.prank(rejectedBuilder);
        registry.registerBuilderV1(LEASE, type(uint64).max, 1, hex"");
        assertEq(_stateDigest(rejectedBuilder), beforeExhausted);
    }

    function test_registerFeeTokenAndFalseReturnRollbackRootsAndCustody() external {
        BuilderRegistryMerkleTracker.Tree memory registryTree =
            BuilderRegistryMerkleTracker.emptyRegistryTree();
        BuilderRegistryMerkleTracker.Tree memory admissionTree =
            BuilderRegistryMerkleTracker.emptyAdmissionTree();
        address builder = vm.addr(1);
        _fundAndApprove(builder, LEASE);
        bytes memory witness = bytes.concat(
            BuilderRegistryMerkleTracker.encodeProof(registryTree.proof(0)),
            BuilderRegistryMerkleTracker.encodeProof(admissionTree.proof(0))
        );
        bytes32 beforeDigest = _stateDigest(builder);

        token.setTransferMode(7);
        vm.expectRevert(BuilderRegistry.BuilderTokenIncomingDeltaMismatch.selector);
        vm.prank(builder);
        registry.registerBuilderV1(LEASE, 0, 0, witness);
        assertEq(_stateDigest(builder), beforeDigest);

        token.setTransferMode(2);
        vm.expectRevert(BuilderRegistry.BuilderTokenTransferFailed.selector);
        vm.prank(builder);
        registry.registerBuilderV1(LEASE, 0, 0, witness);
        assertEq(_stateDigest(builder), beforeDigest);
    }

    function test_registerAcceptsEmptyOptionalBoolAndRejectsAllMalformedTokenReturns() external {
        BuilderRegistryMerkleTracker.Tree memory registryTree =
            BuilderRegistryMerkleTracker.emptyRegistryTree();
        BuilderRegistryMerkleTracker.Tree memory admissionTree =
            BuilderRegistryMerkleTracker.emptyAdmissionTree();
        BuilderRegistryMerkleTracker.Tree memory trancheTree =
            BuilderRegistryMerkleTracker.emptyTrancheTree();
        address builder = vm.addr(1);
        _fundAndApprove(builder, uint256(LEASE) * 8);
        bytes memory witness = bytes.concat(
            BuilderRegistryMerkleTracker.encodeProof(registryTree.proof(0)),
            BuilderRegistryMerkleTracker.encodeProof(admissionTree.proof(0))
        );
        bytes32 beforeDigest = _stateDigest(builder);

        uint8[4] memory badBalanceModes = [uint8(3), 4, 5, 6];
        for (uint256 i; i < badBalanceModes.length; ++i) {
            token.setBalanceMode(badBalanceModes[i]);
            if (badBalanceModes[i] <= 4) {
                vm.expectPartialRevert(LibExactCall.ExactReturnLengthMismatch.selector);
            } else {
                vm.expectPartialRevert(LibExactCall.ExactCallFailed.selector);
            }
            vm.prank(builder);
            registry.registerBuilderV1(LEASE, 0, 0, witness);
            assertEq(_stateDigest(builder), beforeDigest);
        }
        token.setBalanceMode(0);

        uint8[5] memory badTransferModes = [uint8(2), 3, 4, 5, 6];
        for (uint256 i; i < badTransferModes.length; ++i) {
            token.setTransferMode(badTransferModes[i]);
            vm.expectRevert(BuilderRegistry.BuilderTokenTransferFailed.selector);
            vm.prank(builder);
            registry.registerBuilderV1(LEASE, 0, 0, witness);
            assertEq(_stateDigest(builder), beforeDigest);
        }

        // ERC-20's optional bool permits an empty successful return, but custody deltas remain
        // exact and independently authenticated after the transfer.
        token.setTransferMode(1);
        _registerVacant(registryTree, admissionTree, trancheTree, builder, LEASE, 0, 0);
    }

    function test_registerRejectsNestedTokenEntryButOuterTransferCanComplete() external {
        BuilderRegistryMerkleTracker.Tree memory registryTree =
            BuilderRegistryMerkleTracker.emptyRegistryTree();
        BuilderRegistryMerkleTracker.Tree memory admissionTree =
            BuilderRegistryMerkleTracker.emptyAdmissionTree();
        BuilderRegistryMerkleTracker.Tree memory trancheTree =
            BuilderRegistryMerkleTracker.emptyTrancheTree();
        address builder = vm.addr(1);
        token.configureReentryMatrix(
            address(registry),
            _mutationCalldataMatrix(builder),
            BuilderRegistry.RegistryOperationReentry.selector
        );
        _registerVacant(registryTree, admissionTree, trancheTree, builder, LEASE, 0, 0);
        assertEq(_operationLockValue(), 0);
    }

    function test_forcedTokenDeficitFailsClosedWhileForcedSurplusRemainsUnclaimable() external {
        BuilderRegistryMerkleTracker.Tree memory registryTree =
            BuilderRegistryMerkleTracker.emptyRegistryTree();
        BuilderRegistryMerkleTracker.Tree memory admissionTree =
            BuilderRegistryMerkleTracker.emptyAdmissionTree();
        BuilderRegistryMerkleTracker.Tree memory trancheTree =
            BuilderRegistryMerkleTracker.emptyTrancheTree();
        address builder = vm.addr(1);
        _registerVacant(registryTree, admissionTree, trancheTree, builder, LEASE, 0, 0);
        bytes memory witness = bytes.concat(
            hex"00",
            BuilderRegistryMerkleTracker.encodeProof(
                trancheTree.proof(uint16(CURRENT_WINDOW % 512))
            ),
            BuilderRegistryMerkleTracker.encodeProof(registryTree.proof(0))
        );
        _fundAndApprove(builder, LEASE);

        address thief = address(0xD1EF1C17);
        token.forceTransfer(address(registry), thief, 1);
        bytes32 deficitDigest = _stateDigest(builder);
        vm.expectRevert(BuilderRegistry.BuilderTokenInsolvent.selector);
        vm.prank(builder);
        registry.reserveBuilderWindowV1(0, CURRENT_WINDOW, witness);
        assertEq(_stateDigest(builder), deficitDigest);

        token.forceTransfer(thief, address(registry), 1);
        token.mint(address(registry), 777);
        vm.prank(builder);
        registry.reserveBuilderWindowV1(0, CURRENT_WINDOW, witness);
        assertEq(token.rawBalance(address(registry)), uint256(LEASE) * 2 + 777);

        vm.expectRevert(BuilderRegistry.EmptyBuilderCredit.selector);
        registry.claimBuilderLeaseCreditV1(address(this));
        assertEq(token.rawBalance(address(registry)), uint256(LEASE) * 2 + 777);
    }

    function test_reservationChangesOnlyRegistryCommitmentAndIsIdempotent() external {
        ReservationContext memory context = _prepareReservationContext();

        vm.prank(context.builder);
        (, uint64 index, uint64 window, uint64 version, bytes32 root) =
            registry.reserveBuilderWindowV1(0, CURRENT_WINDOW, hex"00");
        assertEq(index, 0);
        assertEq(window, CURRENT_WINDOW);
        assertEq(version, 2);
        assertEq(root, context.registryTree.root());
        assertEq(token.rawBalance(address(registry)), uint256(LEASE) * 2);
    }

    function _prepareReservationContext() private returns (ReservationContext memory context_) {
        context_.registryTree = BuilderRegistryMerkleTracker.emptyRegistryTree();
        context_.admissionTree = BuilderRegistryMerkleTracker.emptyAdmissionTree();
        context_.trancheTree = BuilderRegistryMerkleTracker.emptyTrancheTree();
        context_.builder = vm.addr(1);
        _registerVacant(
            context_.registryTree,
            context_.admissionTree,
            context_.trancheTree,
            context_.builder,
            LEASE,
            0,
            0
        );
        (, uint64 admissionVersionBefore, bytes32 admissionRootBefore) = registry.admissionStateV1();
        bytes memory witness = bytes.concat(
            hex"00",
            BuilderRegistryMerkleTracker.encodeProof(
                context_.trancheTree.proof(uint16(CURRENT_WINDOW % 512))
            ),
            BuilderRegistryMerkleTracker.encodeProof(context_.registryTree.proof(0))
        );
        _fundAndApprove(context_.builder, LEASE);

        vm.prank(context_.builder);
        (bytes4 magic, uint64 index, uint64 window, uint64 version, bytes32 root) =
            registry.reserveBuilderWindowV1(0, CURRENT_WINDOW, witness);
        SlotChainTypes.TrancheLeafV1 memory reserved = SlotChainTypes.TrancheLeafV1({
            index: uint16(CURRENT_WINDOW % 512),
            window: CURRENT_WINDOW,
            state: uint8(SlotChainTypes.TrancheState.RESERVED),
            amount: LEASE,
            liableUntil: GENESIS + 384 * (CURRENT_WINDOW + 1) + EVIDENCE_DELAY + REORG_MARGIN
        });
        context_.trancheTree
            .update(
                uint16(CURRENT_WINDOW % 512), BuilderRegistryMerkleTracker.trancheLeaf(reserved)
            );
        SlotChainTypes.RegistryCellV1 memory updatedCell =
            _cell(context_.builder, LEASE, 0, context_.trancheTree.root());
        context_.registryTree
            .update(0, BuilderRegistryMerkleTracker.registryLeaf(0, true, updatedCell));
        assertEq(magic, BRV1);
        assertEq(index, 0);
        assertEq(window, CURRENT_WINDOW);
        assertEq(version, 2);
        assertEq(root, context_.registryTree.root());
        (, uint64 admissionVersionAfter, bytes32 admissionRootAfter) = registry.admissionStateV1();
        assertEq(admissionVersionAfter, admissionVersionBefore);
        assertEq(admissionRootAfter, admissionRootBefore);
        assertEq(token.rawBalance(address(registry)), uint256(LEASE) * 2);
    }

    function test_reservationTokenCallbackRejectsAllNineNestedMutationsAndClearsLock() external {
        BuilderRegistryMerkleTracker.Tree memory registryTree =
            BuilderRegistryMerkleTracker.emptyRegistryTree();
        BuilderRegistryMerkleTracker.Tree memory admissionTree =
            BuilderRegistryMerkleTracker.emptyAdmissionTree();
        BuilderRegistryMerkleTracker.Tree memory trancheTree =
            BuilderRegistryMerkleTracker.emptyTrancheTree();
        address builder = vm.addr(1);
        _registerVacant(registryTree, admissionTree, trancheTree, builder, LEASE, 0, 0);
        bytes memory witness = bytes.concat(
            hex"00",
            BuilderRegistryMerkleTracker.encodeProof(
                trancheTree.proof(uint16(CURRENT_WINDOW % 512))
            ),
            BuilderRegistryMerkleTracker.encodeProof(registryTree.proof(0))
        );
        _fundAndApprove(builder, LEASE);
        token.configureReentryMatrix(
            address(registry),
            _mutationCalldataMatrix(builder),
            BuilderRegistry.RegistryOperationReentry.selector
        );

        vm.prank(builder);
        (bytes4 magic, uint64 index, uint64 window,,) =
            registry.reserveBuilderWindowV1(0, CURRENT_WINDOW, witness);
        assertEq(magic, BRV1);
        assertEq(index, 0);
        assertEq(window, CURRENT_WINDOW);
        assertEq(token.rawBalance(address(registry)), uint256(LEASE) * 2);
        assertEq(_operationLockValue(), 0);
    }

    function test_reservationRejectsAheadBoundAndDrainingSettlementWithRollback() external {
        BuilderRegistryMerkleTracker.Tree memory registryTree =
            BuilderRegistryMerkleTracker.emptyRegistryTree();
        BuilderRegistryMerkleTracker.Tree memory admissionTree =
            BuilderRegistryMerkleTracker.emptyAdmissionTree();
        BuilderRegistryMerkleTracker.Tree memory trancheTree =
            BuilderRegistryMerkleTracker.emptyTrancheTree();
        address builder = vm.addr(1);
        _registerVacant(registryTree, admissionTree, trancheTree, builder, LEASE, 0, 0);
        bytes32 beforeDigest = _stateDigest(builder);

        vm.expectRevert(BuilderRegistry.InvalidBuilderReservation.selector);
        vm.prank(builder);
        registry.reserveBuilderWindowV1(0, CURRENT_WINDOW + 17, hex"00");
        assertEq(_stateDigest(builder), beforeDigest);

        settlement.setResponse(SETTLEMENT_STATE_SELECTOR, _settlementState(PROTOCOL_VERSION, 0));
        vm.expectRevert(BuilderRegistry.SettlementDraining.selector);
        vm.prank(builder);
        registry.reserveBuilderWindowV1(0, CURRENT_WINDOW, hex"00");
        assertEq(_stateDigest(builder), beforeDigest);

        settlement.setResponse(SETTLEMENT_STATE_SELECTOR, _settlementState(PROTOCOL_VERSION, 3));
        vm.expectRevert(BuilderRegistry.SettlementStateMalformed.selector);
        vm.prank(builder);
        registry.reserveBuilderWindowV1(0, CURRENT_WINDOW, hex"00");
        assertEq(_stateDigest(builder), beforeDigest);

        settlement.setResponse(
            SETTLEMENT_STATE_SELECTOR,
            abi.encode(bytes4(0x53535432), PROTOCOL_VERSION, uint8(1), uint64(12_345))
        );
        vm.expectRevert(BuilderRegistry.SettlementStateMalformed.selector);
        vm.prank(builder);
        registry.reserveBuilderWindowV1(0, CURRENT_WINDOW, hex"00");
        assertEq(_stateDigest(builder), beforeDigest);

        // Recovery mode (2) passes the SST1 gate exactly like NORMAL: the reservation proceeds
        // to witness validation instead of rejecting on the Settlement mode.
        settlement.setResponse(SETTLEMENT_STATE_SELECTOR, _settlementState(PROTOCOL_VERSION, 2));
        vm.expectRevert(BuilderRegistry.InvalidReservationWitness.selector);
        vm.prank(builder);
        registry.reserveBuilderWindowV1(0, CURRENT_WINDOW, hex"00");
        assertEq(_stateDigest(builder), beforeDigest);
    }

    function test_reservationReadsSettlementStateAndRollsBackEveryBoundedPeerFault() external {
        BuilderRegistryMerkleTracker.Tree memory registryTree =
            BuilderRegistryMerkleTracker.emptyRegistryTree();
        BuilderRegistryMerkleTracker.Tree memory admissionTree =
            BuilderRegistryMerkleTracker.emptyAdmissionTree();
        BuilderRegistryMerkleTracker.Tree memory trancheTree =
            BuilderRegistryMerkleTracker.emptyTrancheTree();
        address builder = vm.addr(1);
        _registerVacant(registryTree, admissionTree, trancheTree, builder, LEASE, 0, 0);
        bytes32 beforeDigest = _stateDigest(builder);

        uint8[5] memory badPeerModes = [uint8(1), 2, 3, 4, 5];
        for (uint256 i; i < badPeerModes.length; ++i) {
            settlement.setMode(SETTLEMENT_STATE_SELECTOR, badPeerModes[i]);
            if (badPeerModes[i] <= 2) {
                vm.expectPartialRevert(LibExactCall.ExactCallFailed.selector);
            } else {
                vm.expectPartialRevert(LibExactCall.ExactReturnLengthMismatch.selector);
            }
            vm.prank(builder);
            registry.reserveBuilderWindowV1(0, CURRENT_WINDOW, hex"");
            assertEq(_stateDigest(builder), beforeDigest);
        }
        settlement.setMode(SETTLEMENT_STATE_SELECTOR, 0);
    }

    function test_trancheRingRejectsNonterminalWrapThenPermitsReleasedLeafReuse() external {
        TrancheRingContext memory context = _prepareTrancheRingContext();
        bytes memory wrappedWitness = bytes.concat(
            hex"00",
            BuilderRegistryMerkleTracker.encodeProof(
                context.trancheTree.proof(context.trancheIndex)
            ),
            BuilderRegistryMerkleTracker.encodeProof(context.registryTree.proof(0))
        );
        bytes32 beforeCollision = _stateDigest(context.builder);
        vm.expectRevert(BuilderRegistry.TrancheRingCollision.selector);
        vm.prank(context.builder);
        registry.reserveBuilderWindowV1(0, context.wrappedWindow, wrappedWitness);
        assertEq(_stateDigest(context.builder), beforeCollision);

        _releaseAndReuseWrappedTranche(context);
    }

    function _prepareTrancheRingContext() private returns (TrancheRingContext memory context_) {
        context_.registryTree = BuilderRegistryMerkleTracker.emptyRegistryTree();
        context_.admissionTree = BuilderRegistryMerkleTracker.emptyAdmissionTree();
        context_.trancheTree = BuilderRegistryMerkleTracker.emptyTrancheTree();
        context_.builder = vm.addr(1);
        context_.cell = _registerVacant(
            context_.registryTree,
            context_.admissionTree,
            context_.trancheTree,
            context_.builder,
            LEASE,
            0,
            0
        );
        context_.trancheIndex = uint16(CURRENT_WINDOW % 512);
        bytes memory reserveWitness = bytes.concat(
            hex"00",
            BuilderRegistryMerkleTracker.encodeProof(
                context_.trancheTree.proof(context_.trancheIndex)
            ),
            BuilderRegistryMerkleTracker.encodeProof(context_.registryTree.proof(0))
        );
        _fundAndApprove(context_.builder, LEASE);
        vm.prank(context_.builder);
        registry.reserveBuilderWindowV1(0, CURRENT_WINDOW, reserveWitness);
        context_.tranche = SlotChainTypes.TrancheLeafV1({
            index: context_.trancheIndex,
            window: CURRENT_WINDOW,
            state: uint8(SlotChainTypes.TrancheState.RESERVED),
            amount: LEASE,
            liableUntil: GENESIS + 384 * (CURRENT_WINDOW + 1) + EVIDENCE_DELAY + REORG_MARGIN
        });
        context_.trancheTree
            .update(
                context_.trancheIndex, BuilderRegistryMerkleTracker.trancheLeaf(context_.tranche)
            );
        context_.cell.trancheRoot = context_.trancheTree.root();
        context_.registryTree
            .update(0, BuilderRegistryMerkleTracker.registryLeaf(0, true, context_.cell));

        context_.wrappedWindow = CURRENT_WINDOW + 512;
        vm.warp(uint256(GENESIS) + uint256(context_.wrappedWindow) * 384);
        bytes memory normalizeWitness = bytes.concat(
            hex"01",
            abi.encodePacked(CURRENT_WINDOW),
            BuilderRegistryMerkleTracker.encodeProof(
                context_.trancheTree.proof(context_.trancheIndex)
            ),
            BuilderRegistryMerkleTracker.encodeProof(context_.registryTree.proof(0))
        );
        registry.normalizeBuilderTranchesV1(context_.builder, 0, normalizeWitness);
        context_.tranche.state = uint8(SlotChainTypes.TrancheState.LIABLE);
        context_.trancheTree
            .update(
                context_.trancheIndex, BuilderRegistryMerkleTracker.trancheLeaf(context_.tranche)
            );
        context_.cell.trancheRoot = context_.trancheTree.root();
        context_.registryTree
            .update(0, BuilderRegistryMerkleTracker.registryLeaf(0, true, context_.cell));
    }

    function _releaseAndReuseWrappedTranche(TrancheRingContext memory _context) private {
        schedule.setResponse(
            SCHEDULE_WINDOW_RELEASE_SELECTOR,
            _scheduleWindowRelease(CURRENT_WINDOW, 3, CURRENT_WINDOW + 1, bytes32(0))
        );
        bytes memory releaseWitness = bytes.concat(
            BuilderRegistryMerkleTracker.encodeProof(
                _context.trancheTree.proof(_context.trancheIndex)
            ),
            BuilderRegistryMerkleTracker.encodeProof(_context.registryTree.proof(0))
        );
        registry.releaseBuilderTrancheV1(_context.builder, 0, CURRENT_WINDOW, releaseWitness);
        _context.tranche.state = uint8(SlotChainTypes.TrancheState.RELEASED);
        _context.tranche.amount = 0;
        _context.trancheTree
            .update(
                _context.trancheIndex, BuilderRegistryMerkleTracker.trancheLeaf(_context.tranche)
            );
        _context.cell.trancheRoot = _context.trancheTree.root();
        _context.registryTree
            .update(0, BuilderRegistryMerkleTracker.registryLeaf(0, true, _context.cell));

        bytes memory wrappedWitness = bytes.concat(
            hex"00",
            BuilderRegistryMerkleTracker.encodeProof(
                _context.trancheTree.proof(_context.trancheIndex)
            ),
            BuilderRegistryMerkleTracker.encodeProof(_context.registryTree.proof(0))
        );
        _fundAndApprove(_context.builder, LEASE);
        vm.prank(_context.builder);
        (bytes4 magic, uint64 index, uint64 window, uint64 version, bytes32 root) =
            registry.reserveBuilderWindowV1(0, _context.wrappedWindow, wrappedWitness);
        _context.tranche.window = _context.wrappedWindow;
        _context.tranche.state = uint8(SlotChainTypes.TrancheState.RESERVED);
        _context.tranche.amount = LEASE;
        _context.tranche.liableUntil =
            GENESIS + 384 * (_context.wrappedWindow + 1) + EVIDENCE_DELAY + REORG_MARGIN;
        _context.trancheTree
            .update(
                _context.trancheIndex, BuilderRegistryMerkleTracker.trancheLeaf(_context.tranche)
            );
        _context.cell.trancheRoot = _context.trancheTree.root();
        _context.registryTree
            .update(0, BuilderRegistryMerkleTracker.registryLeaf(0, true, _context.cell));
        assertEq(magic, BRV1);
        assertEq(index, 0);
        assertEq(window, _context.wrappedWindow);
        assertEq(version, 5);
        assertEq(root, _context.registryTree.root());
    }

    function test_normalizeAndReleaseActiveTrancheUseStrictDeadlineAndExactSWR1() external {
        ActiveTrancheReleaseContext memory context = _prepareActiveTrancheRelease();
        _assertActiveTrancheReleaseGuards(context);
        _releaseActiveTranche(context);
    }

    function _prepareActiveTrancheRelease()
        private
        returns (ActiveTrancheReleaseContext memory context_)
    {
        context_.registryTree = BuilderRegistryMerkleTracker.emptyRegistryTree();
        context_.admissionTree = BuilderRegistryMerkleTracker.emptyAdmissionTree();
        context_.trancheTree = BuilderRegistryMerkleTracker.emptyTrancheTree();
        context_.builder = vm.addr(1);
        context_.cell = _registerVacant(
            context_.registryTree,
            context_.admissionTree,
            context_.trancheTree,
            context_.builder,
            LEASE,
            0,
            0
        );
        bytes memory reserveWitness = bytes.concat(
            hex"00",
            BuilderRegistryMerkleTracker.encodeProof(
                context_.trancheTree.proof(uint16(CURRENT_WINDOW % 512))
            ),
            BuilderRegistryMerkleTracker.encodeProof(context_.registryTree.proof(0))
        );
        _fundAndApprove(context_.builder, LEASE);
        vm.prank(context_.builder);
        registry.reserveBuilderWindowV1(0, CURRENT_WINDOW, reserveWitness);

        context_.tranche = SlotChainTypes.TrancheLeafV1({
            index: uint16(CURRENT_WINDOW % 512),
            window: CURRENT_WINDOW,
            state: uint8(SlotChainTypes.TrancheState.RESERVED),
            amount: LEASE,
            liableUntil: GENESIS + 384 * (CURRENT_WINDOW + 1) + EVIDENCE_DELAY + REORG_MARGIN
        });
        context_.trancheTree
            .update(
                context_.tranche.index, BuilderRegistryMerkleTracker.trancheLeaf(context_.tranche)
            );
        context_.cell.trancheRoot = context_.trancheTree.root();
        context_.registryTree
            .update(0, BuilderRegistryMerkleTracker.registryLeaf(0, true, context_.cell));

        vm.warp(uint256(GENESIS) + uint256(CURRENT_WINDOW + 1) * 384);
        bytes memory normalizeWitness = bytes.concat(
            hex"01",
            abi.encodePacked(CURRENT_WINDOW),
            BuilderRegistryMerkleTracker.encodeProof(
                context_.trancheTree.proof(context_.tranche.index)
            ),
            BuilderRegistryMerkleTracker.encodeProof(context_.registryTree.proof(0))
        );
        (bytes4 magic, uint64 registrationIndex, uint8 closedCount, uint64 version, bytes32 root) =
            registry.normalizeBuilderTranchesV1(context_.builder, 0, normalizeWitness);
        context_.reservedLeafHash = BuilderRegistryMerkleTracker.trancheLeaf(context_.tranche);
        context_.tranche.state = uint8(SlotChainTypes.TrancheState.LIABLE);
        context_.trancheTree
            .update(
                context_.tranche.index, BuilderRegistryMerkleTracker.trancheLeaf(context_.tranche)
            );
        context_.cell.trancheRoot = context_.trancheTree.root();
        context_.registryTree
            .update(0, BuilderRegistryMerkleTracker.registryLeaf(0, true, context_.cell));
        assertEq(magic, BRN1);
        assertEq(registrationIndex, 0);
        assertEq(closedCount, 1);
        assertEq(version, 3);
        assertEq(root, context_.registryTree.root());
        (, uint64 admissionVersion, bytes32 admissionRoot) = registry.admissionStateV1();
        assertEq(admissionVersion, 1);
        assertEq(admissionRoot, context_.admissionTree.root());

        context_.releaseWitness = bytes.concat(
            BuilderRegistryMerkleTracker.encodeProof(
                context_.trancheTree.proof(context_.tranche.index)
            ),
            BuilderRegistryMerkleTracker.encodeProof(context_.registryTree.proof(0))
        );
    }

    function _assertActiveTrancheReleaseGuards(ActiveTrancheReleaseContext memory _context)
        private
    {
        vm.warp(_context.tranche.liableUntil);
        vm.expectRevert(BuilderRegistry.BuilderTrancheNotReleasable.selector);
        registry.releaseBuilderTrancheV1(
            _context.builder, 0, CURRENT_WINDOW, _context.releaseWitness
        );

        vm.warp(uint256(_context.tranche.liableUntil) + 1);
        uint64 lastManagedWindow = uint64(uint256(_word(_configBytes(), 13)));
        bytes32 beforeSemanticRejects = _stateDigest(_context.builder);
        schedule.setResponse(
            SCHEDULE_WINDOW_RELEASE_SELECTOR,
            _scheduleWindowRelease(CURRENT_WINDOW, 3, CURRENT_WINDOW + 1, bytes32(uint256(1)))
        );
        vm.expectRevert(BuilderRegistry.ScheduleWindowNotExpired.selector);
        registry.releaseBuilderTrancheV1(
            _context.builder, 0, CURRENT_WINDOW, _context.releaseWitness
        );
        assertEq(_stateDigest(_context.builder), beforeSemanticRejects);

        uint64[3] memory badCursors = [CURRENT_WINDOW, CURRENT_WINDOW - 1, lastManagedWindow + 1];
        for (uint256 i; i < badCursors.length; ++i) {
            schedule.setResponse(
                SCHEDULE_WINDOW_RELEASE_SELECTOR,
                _scheduleWindowRelease(CURRENT_WINDOW, 3, badCursors[i], bytes32(0))
            );
            vm.expectRevert(BuilderRegistry.ScheduleWindowNotExpired.selector);
            registry.releaseBuilderTrancheV1(
                _context.builder, 0, CURRENT_WINDOW, _context.releaseWitness
            );
            assertEq(_stateDigest(_context.builder), beforeSemanticRejects);
        }

        uint8[5] memory badPeerModes = [uint8(1), 2, 3, 4, 5];
        for (uint256 i; i < badPeerModes.length; ++i) {
            schedule.setMode(SCHEDULE_WINDOW_RELEASE_SELECTOR, badPeerModes[i]);
            if (badPeerModes[i] <= 2) {
                vm.expectPartialRevert(LibExactCall.ExactCallFailed.selector);
            } else {
                vm.expectPartialRevert(LibExactCall.ExactReturnLengthMismatch.selector);
            }
            registry.releaseBuilderTrancheV1(
                _context.builder, 0, CURRENT_WINDOW, _context.releaseWitness
            );
            assertEq(_stateDigest(_context.builder), beforeSemanticRejects);
        }
        schedule.setMode(SCHEDULE_WINDOW_RELEASE_SELECTOR, 0);
    }

    function _releaseActiveTranche(ActiveTrancheReleaseContext memory _context) private {
        schedule.setResponse(
            SCHEDULE_WINDOW_RELEASE_SELECTOR,
            _scheduleWindowRelease(CURRENT_WINDOW, 3, CURRENT_WINDOW + 1, bytes32(0))
        );
        uint256 balanceBefore = token.rawBalance(address(registry));
        (
            bytes4 magic,
            uint64 registrationIndex,
            uint64 releasedWindow,
            address releasedBuilder,
            uint256 creditedAmount,
            uint64 version,
            bytes32 root
        ) = registry.releaseBuilderTrancheV1(
            _context.builder, 0, CURRENT_WINDOW, _context.releaseWitness
        );
        _context.tranche.state = uint8(SlotChainTypes.TrancheState.RELEASED);
        _context.tranche.amount = 0;
        _context.trancheTree
            .update(
                _context.tranche.index, BuilderRegistryMerkleTracker.trancheLeaf(_context.tranche)
            );
        _context.cell.trancheRoot = _context.trancheTree.root();
        _context.registryTree
            .update(0, BuilderRegistryMerkleTracker.registryLeaf(0, true, _context.cell));
        assertTrue(
            _context.reservedLeafHash != BuilderRegistryMerkleTracker.trancheLeaf(_context.tranche)
        );
        assertEq(magic, BTR1);
        assertEq(registrationIndex, 0);
        assertEq(releasedWindow, CURRENT_WINDOW);
        assertEq(releasedBuilder, _context.builder);
        assertEq(creditedAmount, LEASE);
        assertEq(version, 4);
        assertEq(root, _context.registryTree.root());
        assertEq(token.rawBalance(address(registry)), balanceBefore);

        vm.prank(_context.builder);
        (,, uint256 paidAmount) = registry.claimBuilderLeaseCreditV1(_context.builder);
        assertEq(paidAmount, LEASE);
        assertEq(token.rawBalance(_context.builder), LEASE);
        assertEq(token.rawBalance(address(registry)), LEASE);
    }

    function test_normalizationNoopIsSoleByteAndTerminalPathRequiresExactSentinel() external {
        BuilderRegistryMerkleTracker.Tree memory registryTree =
            BuilderRegistryMerkleTracker.emptyRegistryTree();
        BuilderRegistryMerkleTracker.Tree memory admissionTree =
            BuilderRegistryMerkleTracker.emptyAdmissionTree();
        BuilderRegistryMerkleTracker.Tree memory trancheTree =
            BuilderRegistryMerkleTracker.emptyTrancheTree();
        address builder = vm.addr(1);
        _registerVacant(registryTree, admissionTree, trancheTree, builder, LEASE, 0, 0);

        (bytes4 magic, uint64 index, uint8 closed, uint64 version, bytes32 root) =
            registry.normalizeBuilderTranchesV1(builder, 0, hex"00");
        assertEq(magic, BRN1);
        assertEq(index, 0);
        assertEq(closed, 0);
        assertEq(version, 1);
        assertEq(root, registryTree.root());
        vm.expectRevert(BuilderRegistry.InvalidNormalizationWitness.selector);
        registry.normalizeBuilderTranchesV1(builder, 0, hex"");
        vm.expectRevert(BuilderRegistry.InvalidNormalizationWitness.selector);
        registry.normalizeBuilderTranchesV1(builder, 0, hex"0000");

        uint64 lastManagedWindow = uint64(uint256(_word(_configBytes(), 13)));
        vm.warp(uint256(GENESIS) + uint256(lastManagedWindow + 1) * 384);
        schedule.setResponse(
            SCHEDULE_WINDOW_RELEASE_SELECTOR,
            _scheduleWindowRelease(lastManagedWindow, 3, lastManagedWindow + 1, bytes32(0))
        );
        bytes32 beforeWrongSentinel = _stateDigest(builder);
        vm.expectRevert(BuilderRegistry.ScheduleWindowNotExpired.selector);
        registry.normalizeBuilderTranchesV1(builder, 0, hex"00");
        assertEq(_stateDigest(builder), beforeWrongSentinel);

        schedule.setResponse(
            SCHEDULE_WINDOW_RELEASE_SELECTOR,
            _scheduleWindowRelease(lastManagedWindow, 3, type(uint64).max, bytes32(0))
        );
        (magic, index, closed, version, root) =
            registry.normalizeBuilderTranchesV1(builder, 0, hex"00");
        assertEq(magic, BRN1);
        assertEq(index, 0);
        assertEq(closed, 0);
        assertEq(version, 1);
        assertEq(root, registryTree.root());
    }

    function test_terminalActiveGenerationReleaseRequiresExactSentinelAndClearsBothRoots()
        external
    {
        address builder = _releaseTerminalActiveGeneration();
        _assertTerminalReleaseClaimBehavior(builder);
    }

    function _releaseTerminalActiveGeneration() private returns (address builder_) {
        BuilderRegistryMerkleTracker.Tree memory registryTree =
            BuilderRegistryMerkleTracker.emptyRegistryTree();
        BuilderRegistryMerkleTracker.Tree memory admissionTree =
            BuilderRegistryMerkleTracker.emptyAdmissionTree();
        BuilderRegistryMerkleTracker.Tree memory trancheTree =
            BuilderRegistryMerkleTracker.emptyTrancheTree();
        builder_ = vm.addr(1);
        _registerVacant(registryTree, admissionTree, trancheTree, builder_, LEASE, 0, 0);
        uint64 lastManagedWindow = uint64(uint256(_word(_configBytes(), 13)));
        vm.warp(uint256(GENESIS) + uint256(lastManagedWindow + 1) * 384);
        bytes memory witness = bytes.concat(
            BuilderRegistryMerkleTracker.encodeProof(registryTree.proof(0)),
            BuilderRegistryMerkleTracker.encodeProof(admissionTree.proof(0))
        );
        bytes32 beforeDigest = _stateDigest(builder_);

        schedule.setResponse(
            SCHEDULE_WINDOW_RELEASE_SELECTOR,
            _scheduleWindowRelease(lastManagedWindow, 3, lastManagedWindow, bytes32(0))
        );
        vm.expectRevert(BuilderRegistry.ScheduleWindowNotExpired.selector);
        registry.releaseBuilderGenerationV1(builder_, 0, witness);
        assertEq(_stateDigest(builder_), beforeDigest);

        schedule.setResponse(
            SCHEDULE_WINDOW_RELEASE_SELECTOR,
            _scheduleWindowRelease(lastManagedWindow, 3, type(uint64).max, bytes32(0))
        );
        (bytes4 magic, uint64 index, address released, uint256 bond, uint64 version, bytes32 root) =
            registry.releaseBuilderGenerationV1(builder_, 0, witness);
        assertEq(magic, BGR1);
        assertEq(index, 0);
        assertEq(released, builder_);
        assertEq(bond, LEASE);
        assertEq(version, 2);
        assertEq(root, BuilderRegistryMerkleTracker.emptyAdmissionTree().root());
        (,,,,,, bytes32 registryRoot) = registry.scheduleRegistryStateV1();
        assertEq(registryRoot, BuilderRegistryMerkleTracker.emptyRegistryTree().root());
        assertEq(token.rawBalance(address(registry)), LEASE);
    }

    function _assertTerminalReleaseClaimBehavior(address _builder) private {
        address recipient = address(0xCAFE);
        bytes32 postRelease = _stateDigest(_builder);
        vm.expectRevert(BuilderRegistry.InvalidBuilderCreditRecipient.selector);
        vm.prank(_builder);
        registry.claimBuilderLeaseCreditV1(address(0));
        vm.expectRevert(BuilderRegistry.InvalidBuilderCreditRecipient.selector);
        vm.prank(_builder);
        registry.claimBuilderLeaseCreditV1(address(registry));
        assertEq(_stateDigest(_builder), postRelease);

        uint8[4] memory badBalanceModes = [uint8(3), 4, 5, 6];
        for (uint256 i; i < badBalanceModes.length; ++i) {
            token.setBalanceMode(badBalanceModes[i]);
            if (badBalanceModes[i] <= 4) {
                vm.expectPartialRevert(LibExactCall.ExactReturnLengthMismatch.selector);
            } else {
                vm.expectPartialRevert(LibExactCall.ExactCallFailed.selector);
            }
            vm.prank(_builder);
            registry.claimBuilderLeaseCreditV1(recipient);
            assertEq(_stateDigest(_builder), postRelease);
        }
        token.setBalanceMode(0);

        uint8[5] memory badTransferModes = [uint8(2), 3, 4, 5, 6];
        for (uint256 i; i < badTransferModes.length; ++i) {
            token.setTransferMode(badTransferModes[i]);
            vm.expectRevert(BuilderRegistry.BuilderTokenTransferFailed.selector);
            vm.prank(_builder);
            registry.claimBuilderLeaseCreditV1(recipient);
            assertEq(_stateDigest(_builder), postRelease);
        }

        token.setTransferMode(7);
        vm.expectRevert(BuilderRegistry.BuilderTokenOutgoingDeltaMismatch.selector);
        vm.prank(_builder);
        registry.claimBuilderLeaseCreditV1(recipient);
        assertEq(_stateDigest(_builder), postRelease);
        assertEq(token.rawBalance(recipient), 0);

        token.configureReentryMatrix(
            address(registry),
            _mutationCalldataMatrix(recipient),
            BuilderRegistry.RegistryOperationReentry.selector
        );
        vm.prank(_builder);
        (bytes4 claimMagic, address paidRecipient, uint256 paidAmount) =
            registry.claimBuilderLeaseCreditV1(recipient);
        assertEq(claimMagic, BCL1);
        assertEq(paidRecipient, recipient);
        assertEq(paidAmount, LEASE);
        assertEq(token.rawBalance(recipient), LEASE);
        assertEq(token.rawBalance(address(registry)), 0);
        assertEq(_operationLockValue(), 0);
    }

    function test_fullTableTieReplacesGreatestIndexThenReleasesBondAsPullCredit() external {
        FullTableContext memory context = _prepareFullTable();
        _rejectInsufficientTiedReplacement(context);
        _replaceGreatestTiedIndex(context);
        _releaseTiedVictimAndClaim(context);
    }

    function _prepareFullTable() private returns (FullTableContext memory context_) {
        context_.registryTree = BuilderRegistryMerkleTracker.emptyRegistryTree();
        context_.admissionTree = BuilderRegistryMerkleTracker.emptyAdmissionTree();
        context_.trancheTree = BuilderRegistryMerkleTracker.emptyTrancheTree();
        for (uint8 i; i < 64; ++i) {
            _registerVacant(
                context_.registryTree,
                context_.admissionTree,
                context_.trancheTree,
                vm.addr(uint256(i) + 1),
                LEASE,
                i,
                i
            );
        }
        context_.victim = vm.addr(64);
        context_.newcomer = vm.addr(65);
    }

    function _rejectInsufficientTiedReplacement(FullTableContext memory _context) private {
        _fundAndApprove(_context.newcomer, uint256(LEASE) + 1);
        bytes32 beforeRejected = _stateDigest(_context.newcomer);
        vm.expectRevert(BuilderRegistry.InsufficientReplacementBond.selector);
        vm.prank(_context.newcomer);
        registry.registerBuilderV1(LEASE, 64, 63, hex"");
        assertEq(_stateDigest(_context.newcomer), beforeRejected);
    }

    function _replaceGreatestTiedIndex(FullTableContext memory _context) private {
        bytes memory moveWitness;
        {
            SlotChainTypes.RegistryCellV1 memory victimCell =
                _cell(_context.victim, LEASE, 63, _context.trancheTree.root());
            SlotChainTypes.RegistryCellV1 memory newcomerCell =
                _cell(_context.newcomer, LEASE + 1, 64, _context.trancheTree.root());
            bytes memory registryPath =
                BuilderRegistryMerkleTracker.encodeProof(_context.registryTree.proof(63));
            bytes memory liabilityPath =
                BuilderRegistryMerkleTracker.encodeProof(_context.admissionTree.proof(64));
            _context.admissionTree
                .update(64, BuilderRegistryMerkleTracker.admissionLeaf(64, true, 2, victimCell));
            bytes memory activePath =
                BuilderRegistryMerkleTracker.encodeProof(_context.admissionTree.proof(63));
            _context.admissionTree
                .update(63, BuilderRegistryMerkleTracker.admissionLeaf(63, true, 1, newcomerCell));
            _context.registryTree
                .update(63, BuilderRegistryMerkleTracker.registryLeaf(63, true, newcomerCell));
            moveWitness = bytes.concat(hex"00", registryPath, liabilityPath, activePath);
        }

        vm.prank(_context.newcomer);
        (
            bytes4 magic,
            uint64 registrationIndex,
            uint8 activeIndex,
            uint64 effectiveSlot,
            uint64 admissionVersion,
            bytes32 admissionRoot
        ) = registry.registerBuilderV1(LEASE + 1, 64, 63, moveWitness);
        assertEq(magic, BRG1);
        assertEq(registrationIndex, 64);
        assertEq(activeIndex, 63);
        assertEq(effectiveSlot, CURRENT_SLOT + 8 * 384);
        assertEq(admissionVersion, 65);
        assertEq(admissionRoot, _context.admissionTree.root());
        assertEq(token.rawBalance(address(registry)), uint256(65) * LEASE + 1);
    }

    function _releaseTiedVictimAndClaim(FullTableContext memory _context) private {
        bytes memory releaseWitness =
            BuilderRegistryMerkleTracker.encodeProof(_context.admissionTree.proof(64));
        SlotChainTypes.RegistryCellV1 memory emptyCell;
        _context.admissionTree
            .update(64, BuilderRegistryMerkleTracker.admissionLeaf(64, false, 0, emptyCell));
        (
            bytes4 magic,
            uint64 registrationIndex,
            address releasedBuilder,
            uint256 creditedBond,
            uint64 admissionVersion,
            bytes32 admissionRoot
        ) = registry.releaseBuilderGenerationV1(_context.victim, 63, releaseWitness);
        assertEq(magic, BGR1);
        assertEq(registrationIndex, 63);
        assertEq(releasedBuilder, _context.victim);
        assertEq(creditedBond, LEASE);
        assertEq(admissionVersion, 66);
        assertEq(admissionRoot, _context.admissionTree.root());
        assertEq(token.rawBalance(address(registry)), uint256(65) * LEASE + 1);

        token.mint(address(registry), 777);
        address recipient = address(0xCAFE);
        vm.prank(_context.victim);
        (bytes4 claimMagic, address paidRecipient, uint256 paidAmount) =
            registry.claimBuilderLeaseCreditV1(recipient);
        assertEq(claimMagic, BCL1);
        assertEq(paidRecipient, recipient);
        assertEq(paidAmount, LEASE);
        assertEq(token.rawBalance(recipient), LEASE);
        assertEq(token.rawBalance(address(registry)), uint256(64) * LEASE + 1 + 777);
    }

    function test_fullTableSelectsUniqueMinimumBondRegardlessOfCallerHint() external {
        FullTableContext memory context = _prepareUniqueMinimumTable();
        _rejectWrongUniqueMinimumHint(context);
        _replaceUniqueMinimum(context);
    }

    function _prepareUniqueMinimumTable() private returns (FullTableContext memory context_) {
        context_.registryTree = BuilderRegistryMerkleTracker.emptyRegistryTree();
        context_.admissionTree = BuilderRegistryMerkleTracker.emptyAdmissionTree();
        context_.trancheTree = BuilderRegistryMerkleTracker.emptyTrancheTree();
        for (uint8 i; i < 64; ++i) {
            uint192 bond = i == 0 ? LEASE : LEASE + 10;
            _registerVacant(
                context_.registryTree,
                context_.admissionTree,
                context_.trancheTree,
                vm.addr(uint256(i) + 1),
                bond,
                i,
                i
            );
        }
        context_.victim = vm.addr(1);
        context_.newcomer = vm.addr(65);
    }

    function _rejectWrongUniqueMinimumHint(FullTableContext memory _context) private {
        _fundAndApprove(_context.newcomer, LEASE + 1);
        bytes32 beforeWrongHint = _stateDigest(_context.newcomer);
        vm.expectRevert(BuilderRegistry.ActiveIndexRace.selector);
        vm.prank(_context.newcomer);
        registry.registerBuilderV1(LEASE + 1, 64, 63, hex"");
        assertEq(_stateDigest(_context.newcomer), beforeWrongHint);
    }

    function _replaceUniqueMinimum(FullTableContext memory _context) private {
        bytes memory moveWitness;
        {
            SlotChainTypes.RegistryCellV1 memory victimCell =
                _cell(_context.victim, LEASE, 0, _context.trancheTree.root());
            SlotChainTypes.RegistryCellV1 memory newcomerCell =
                _cell(_context.newcomer, LEASE + 1, 64, _context.trancheTree.root());
            bytes memory registryPath =
                BuilderRegistryMerkleTracker.encodeProof(_context.registryTree.proof(0));
            bytes memory liabilityPath =
                BuilderRegistryMerkleTracker.encodeProof(_context.admissionTree.proof(64));
            _context.admissionTree
                .update(64, BuilderRegistryMerkleTracker.admissionLeaf(64, true, 2, victimCell));
            bytes memory activePath =
                BuilderRegistryMerkleTracker.encodeProof(_context.admissionTree.proof(0));
            _context.admissionTree
                .update(0, BuilderRegistryMerkleTracker.admissionLeaf(0, true, 1, newcomerCell));
            _context.registryTree
                .update(0, BuilderRegistryMerkleTracker.registryLeaf(0, true, newcomerCell));
            moveWitness = bytes.concat(hex"00", registryPath, liabilityPath, activePath);
        }

        vm.prank(_context.newcomer);
        (bytes4 magic, uint64 registrationIndex, uint8 activeIndex,,, bytes32 admissionRoot) =
            registry.registerBuilderV1(LEASE + 1, 64, 0, moveWitness);
        assertEq(magic, BRG1);
        assertEq(registrationIndex, 64);
        assertEq(activeIndex, 0);
        assertEq(admissionRoot, _context.admissionTree.root());
    }

    function test_exitMovesAtExactMaturityButNotOneWindowBefore() external {
        ExitLifecycleContext memory context = _prepareExitLifecycle();
        _moveExitAtMaturity(context);
        _releaseExitAndReuseAddress(context);
    }

    function _prepareExitLifecycle() private returns (ExitLifecycleContext memory context_) {
        context_.registryTree = BuilderRegistryMerkleTracker.emptyRegistryTree();
        context_.admissionTree = BuilderRegistryMerkleTracker.emptyAdmissionTree();
        context_.trancheTree = BuilderRegistryMerkleTracker.emptyTrancheTree();
        context_.builder = vm.addr(1);
        context_.cell = _registerVacant(
            context_.registryTree,
            context_.admissionTree,
            context_.trancheTree,
            context_.builder,
            LEASE,
            0,
            0
        );

        vm.prank(context_.builder);
        (bytes4 exitMagic, uint64 registrationIndex, uint64 matureWindow, uint8 activeIndex) =
            registry.requestBuilderExitV1(0);
        context_.matureWindow = matureWindow;
        assertEq(exitMagic, BRE1);
        assertEq(registrationIndex, 0);
        assertEq(matureWindow, CURRENT_WINDOW + 268);
        assertEq(activeIndex, 0);

        vm.warp(uint256(GENESIS) + uint256(matureWindow - 1) * 384 + 383);
        (bytes4 maintenanceMagic, uint8 inspected, uint8 moved, uint64 version, bytes32 root) =
            registry.processBuilderMaintenanceV1(1, bytes(""));
        assertEq(maintenanceMagic, BRM1);
        assertEq(inspected, 1);
        assertEq(moved, 0);
        assertEq(version, 1);
        assertEq(root, context_.admissionTree.root());
    }

    function _moveExitAtMaturity(ExitLifecycleContext memory _context) private {
        vm.warp(uint256(GENESIS) + uint256(_context.matureWindow) * 384);
        bytes memory registryPath =
            BuilderRegistryMerkleTracker.encodeProof(_context.registryTree.proof(0));
        bytes memory liabilityPath =
            BuilderRegistryMerkleTracker.encodeProof(_context.admissionTree.proof(64));
        SlotChainTypes.RegistryCellV1 memory emptyCell;
        _context.registryTree
            .update(0, BuilderRegistryMerkleTracker.registryLeaf(0, false, emptyCell));
        _context.admissionTree
            .update(64, BuilderRegistryMerkleTracker.admissionLeaf(64, true, 2, _context.cell));
        bytes memory activePath =
            BuilderRegistryMerkleTracker.encodeProof(_context.admissionTree.proof(0));
        _context.admissionTree
            .update(0, BuilderRegistryMerkleTracker.admissionLeaf(0, false, 0, emptyCell));
        bytes memory moveWitness = bytes.concat(hex"00", registryPath, liabilityPath, activePath);
        bytes memory maintenanceWitness =
            bytes.concat(bytes4(uint32(moveWitness.length)), moveWitness);

        (bytes4 maintenanceMagic, uint8 inspected, uint8 moved, uint64 version, bytes32 root) =
            registry.processBuilderMaintenanceV1(1, maintenanceWitness);
        assertEq(maintenanceMagic, BRM1);
        assertEq(inspected, 1);
        assertEq(moved, 1);
        assertEq(version, 2);
        assertEq(root, _context.admissionTree.root());
        (,,,,,, bytes32 committedRegistryRoot) = registry.scheduleRegistryStateV1();
        assertEq(committedRegistryRoot, _context.registryTree.root());
    }

    function _releaseExitAndReuseAddress(ExitLifecycleContext memory _context) private {
        _releaseExitedGeneration(_context);
        _reuseReleasedAddress(_context);
    }

    function _releaseExitedGeneration(ExitLifecycleContext memory _context) private {
        // The liability release clears the reverse live-address guard. After claiming its exact
        // base-bond credit, the same ECDSA address may enter a fresh monotonic generation through
        // the lowest vacancy; neither address identity nor the old cell is a permanent tombstone.
        bytes memory releaseWitness =
            BuilderRegistryMerkleTracker.encodeProof(_context.admissionTree.proof(64));
        bytes32 liabilityTailSlot = vm.load(address(registry), bytes32(uint256(428)));
        uint64 derivedReleaseWindow = uint64(uint256(liabilityTailSlot) >> 64);
        assertEq(derivedReleaseWindow, uint64(35));
        uint64 forcedBoundary = _context.matureWindow + 1;
        uint256 releaseWindowMask = uint256(type(uint64).max) << 64;
        vm.store(
            address(registry),
            bytes32(uint256(428)),
            bytes32(
                (uint256(liabilityTailSlot) & ~releaseWindowMask) | (uint256(forcedBoundary) << 64)
            )
        );
        bytes32 beforeBoundary = _stateDigest(_context.builder);
        vm.expectRevert(BuilderRegistry.BuilderGenerationNotReleasable.selector);
        registry.releaseBuilderGenerationV1(_context.builder, 0, releaseWitness);
        assertEq(_stateDigest(_context.builder), beforeBoundary);
        vm.warp(uint256(GENESIS) + uint256(forcedBoundary) * 384);
        SlotChainTypes.RegistryCellV1 memory emptyCell;
        _context.admissionTree
            .update(64, BuilderRegistryMerkleTracker.admissionLeaf(64, false, 0, emptyCell));
        (
            bytes4 releaseMagic,
            uint64 releasedIndex,
            address releasedBuilder,
            uint256 releasedBond,,
        ) = registry.releaseBuilderGenerationV1(_context.builder, 0, releaseWitness);
        assertEq(releaseMagic, BGR1);
        assertEq(releasedIndex, 0);
        assertEq(releasedBuilder, _context.builder);
        assertEq(releasedBond, LEASE);
        vm.prank(_context.builder);
        registry.claimBuilderLeaseCreditV1(_context.builder);
    }

    function _reuseReleasedAddress(ExitLifecycleContext memory _context) private {
        bytes memory registrationWitness = bytes.concat(
            BuilderRegistryMerkleTracker.encodeProof(_context.registryTree.proof(0)),
            BuilderRegistryMerkleTracker.encodeProof(_context.admissionTree.proof(0))
        );
        vm.prank(_context.builder);
        (bytes4 registrationMagic, uint64 reusedIndex, uint8 reusedActiveIndex,,,) =
            registry.registerBuilderV1(LEASE, 1, 0, registrationWitness);
        assertEq(registrationMagic, BRG1);
        assertEq(reusedIndex, 1);
        assertEq(reusedActiveIndex, 0);
    }

    function test_exitFifoAcceptsMaxMinusOneSequenceAndRejectsExhaustedSentinel() external {
        BuilderRegistryMerkleTracker.Tree memory registryTree =
            BuilderRegistryMerkleTracker.emptyRegistryTree();
        BuilderRegistryMerkleTracker.Tree memory admissionTree =
            BuilderRegistryMerkleTracker.emptyAdmissionTree();
        BuilderRegistryMerkleTracker.Tree memory trancheTree =
            BuilderRegistryMerkleTracker.emptyTrancheTree();
        address firstBuilder = vm.addr(1);
        address secondBuilder = vm.addr(2);
        _registerVacant(registryTree, admissionTree, trancheTree, firstBuilder, LEASE, 0, 0);
        _registerVacant(registryTree, admissionTree, trancheTree, secondBuilder, LEASE, 1, 1);

        // Storage-layout-only reachability hook: bits 64..127 of slot 6862 are the packed
        // uint64 nextExitSequence. The production transition itself remains black-box asserted.
        vm.store(
            address(registry), bytes32(uint256(6862)), bytes32(uint256(type(uint64).max - 1) << 64)
        );
        vm.prank(firstBuilder);
        (bytes4 magic, uint64 index, uint64 matureWindow, uint8 activeIndex) =
            registry.requestBuilderExitV1(0);
        assertEq(magic, BRE1);
        assertEq(index, 0);
        assertEq(matureWindow, CURRENT_WINDOW + 268);
        assertEq(activeIndex, 0);

        bytes32 beforeExhausted = _stateDigest(secondBuilder);
        vm.expectRevert(BuilderRegistry.InvalidBuilderExit.selector);
        vm.prank(secondBuilder);
        registry.requestBuilderExitV1(1);
        assertEq(_stateDigest(secondBuilder), beforeExhausted);
    }

    function test_movementSequences1071And1072UseLastThenFirstLiabilityPositions() external {
        MovementBoundaryContext memory context = _prepareMovementBoundaryContext();
        bytes memory firstMove = _emptyActiveMove(
            context.registryTree, context.admissionTree, 0, 1135, context.cells[0]
        );
        bytes memory secondMove = _emptyActiveMove(
            context.registryTree, context.admissionTree, 1, 64, context.cells[1]
        );
        assertEq(firstMove.length, 897);
        assertEq(secondMove.length, 897);
        bytes memory witness = bytes.concat(
            bytes4(uint32(firstMove.length)),
            firstMove,
            bytes4(uint32(secondMove.length)),
            secondMove
        );

        (bytes4 magic, uint8 inspected, uint8 moved, uint64 version, bytes32 root) =
            registry.processBuilderMaintenanceV1(2, witness);
        assertEq(magic, BRM1);
        assertEq(inspected, 2);
        assertEq(moved, 2);
        assertEq(version, 3);
        assertEq(root, context.admissionTree.root());
        (,,,,,, bytes32 registryRoot) = registry.scheduleRegistryStateV1();
        assertEq(registryRoot, context.registryTree.root());

        _releaseMovementBoundary(context);
    }

    function _prepareMovementBoundaryContext()
        private
        returns (MovementBoundaryContext memory context_)
    {
        context_.registryTree = BuilderRegistryMerkleTracker.emptyRegistryTree();
        context_.admissionTree = BuilderRegistryMerkleTracker.emptyAdmissionTree();
        context_.trancheTree = BuilderRegistryMerkleTracker.emptyTrancheTree();
        context_.builders = [vm.addr(1), vm.addr(2)];
        context_.cells[0] = _registerVacant(
            context_.registryTree,
            context_.admissionTree,
            context_.trancheTree,
            context_.builders[0],
            LEASE,
            0,
            0
        );
        context_.cells[1] = _registerVacant(
            context_.registryTree,
            context_.admissionTree,
            context_.trancheTree,
            context_.builders[1],
            LEASE,
            1,
            1
        );
        vm.prank(context_.builders[0]);
        (, uint64 firstIndex, uint64 matureWindow,) = registry.requestBuilderExitV1(0);
        vm.prank(context_.builders[1]);
        (, uint64 secondIndex, uint64 secondMatureWindow,) = registry.requestBuilderExitV1(1);
        assertEq(firstIndex, 0);
        assertEq(secondIndex, 1);
        assertEq(secondMatureWindow, matureWindow);
        vm.warp(uint256(GENESIS) + uint256(matureWindow) * 384);

        bytes32 packedCounters = vm.load(address(registry), bytes32(uint256(6862)));
        vm.store(
            address(registry),
            bytes32(uint256(6862)),
            bytes32((uint256(packedCounters) & ~uint256(type(uint64).max)) | uint256(uint64(1071)))
        );
    }

    function _releaseMovementBoundary(MovementBoundaryContext memory _context) private {
        SlotChainTypes.RegistryCellV1 memory emptyCell;

        // Releasing against the exact two boundary positions proves that the sequence mapping was
        // last=64+1071 followed by wrapped-first=64, rather than merely matching a final root.
        bytes memory firstRelease =
            BuilderRegistryMerkleTracker.encodeProof(_context.admissionTree.proof(1135));
        _context.admissionTree
            .update(1135, BuilderRegistryMerkleTracker.admissionLeaf(1135, false, 0, emptyCell));
        registry.releaseBuilderGenerationV1(_context.builders[0], 0, firstRelease);
        bytes memory secondRelease =
            BuilderRegistryMerkleTracker.encodeProof(_context.admissionTree.proof(64));
        _context.admissionTree
            .update(64, BuilderRegistryMerkleTracker.admissionLeaf(64, false, 0, emptyCell));
        registry.releaseBuilderGenerationV1(_context.builders[1], 1, secondRelease);
        (, uint64 finalVersion, bytes32 finalRoot) = registry.admissionStateV1();
        assertEq(finalVersion, 5);
        assertEq(finalRoot, _context.admissionTree.root());
    }

    function test_maintenanceCapsFourMovesAndResetsBudgetOnlyInNextWindow() external {
        BuilderRegistryMerkleTracker.Tree memory registryTree =
            BuilderRegistryMerkleTracker.emptyRegistryTree();
        BuilderRegistryMerkleTracker.Tree memory admissionTree =
            BuilderRegistryMerkleTracker.emptyAdmissionTree();
        BuilderRegistryMerkleTracker.Tree memory trancheTree =
            BuilderRegistryMerkleTracker.emptyTrancheTree();
        SlotChainTypes.RegistryCellV1[5] memory cells;
        uint64 matureWindow;
        for (uint8 i; i < 5; ++i) {
            address builder = vm.addr(uint256(i) + 1);
            cells[i] =
                _registerVacant(registryTree, admissionTree, trancheTree, builder, LEASE, i, i);
            vm.prank(builder);
            (,, matureWindow,) = registry.requestBuilderExitV1(i);
        }
        vm.warp(uint256(GENESIS) + uint256(matureWindow) * 384);

        bytes memory firstFourWitness;
        for (uint8 i; i < 4; ++i) {
            bytes memory move =
                _emptyActiveMove(registryTree, admissionTree, i, uint16(64 + i), cells[i]);
            firstFourWitness = bytes.concat(firstFourWitness, bytes4(uint32(move.length)), move);
        }
        {
            (bytes4 magic, uint8 inspected, uint8 moved, uint64 version, bytes32 root) =
                registry.processBuilderMaintenanceV1(4, firstFourWitness);
            assertEq(magic, BRM1);
            assertEq(inspected, 5);
            assertEq(moved, 4);
            assertEq(version, 6);
            assertEq(root, admissionTree.root());
        }

        {
            (bytes4 magic, uint8 inspected, uint8 moved, uint64 version, bytes32 root) =
                registry.processBuilderMaintenanceV1(1, bytes(""));
            assertEq(magic, BRM1);
            assertEq(inspected, 0);
            assertEq(moved, 0);
            assertEq(version, 6);
            assertEq(root, admissionTree.root());
        }

        vm.warp(uint256(GENESIS) + uint256(matureWindow + 1) * 384);
        bytes memory fifthMove = _emptyActiveMove(registryTree, admissionTree, 4, 68, cells[4]);
        bytes memory fifthWitness = bytes.concat(bytes4(uint32(fifthMove.length)), fifthMove);
        {
            (bytes4 magic, uint8 inspected, uint8 moved, uint64 version, bytes32 root) =
                registry.processBuilderMaintenanceV1(1, fifthWitness);
            assertEq(magic, BRM1);
            assertEq(inspected, 1);
            assertEq(moved, 1);
            assertEq(version, 7);
            assertEq(root, admissionTree.root());
        }
        (,,,,,, bytes32 registryRoot) = registry.scheduleRegistryStateV1();
        assertEq(registryRoot, registryTree.root());
    }

    function test_allDynamicEntrypointsRejectTrailingOuterCalldata() external {
        bytes[] memory calls = new bytes[](7);
        calls[0] = abi.encodeCall(
            IBuilderRegistry.registerBuilderV1, (LEASE, uint64(0), uint8(0), bytes(""))
        );
        calls[1] = abi.encodeCall(
            IBuilderRegistry.reserveBuilderWindowV1, (uint64(0), CURRENT_WINDOW, bytes(""))
        );
        calls[2] =
            abi.encodeCall(IBuilderRegistry.processBuilderMaintenanceV1, (uint8(1), bytes("")));
        calls[3] = abi.encodeCall(
            IBuilderRegistry.normalizeBuilderTranchesV1, (address(this), uint64(0), bytes(""))
        );
        calls[4] = abi.encodeCall(
            IBuilderRegistry.releaseBuilderTrancheV1,
            (address(this), uint64(0), CURRENT_WINDOW, bytes(""))
        );
        calls[5] = abi.encodeCall(
            IBuilderRegistry.releaseBuilderGenerationV1, (address(this), uint64(0), bytes(""))
        );
        calls[6] = abi.encodeCall(IBuilderRegistry.submitBuilderEquivocationV1, (bytes("")));

        for (uint256 i; i < calls.length; ++i) {
            _assertCallRevertsSelector(
                bytes.concat(calls[i], hex"00"), BuilderRegistry.NonCanonicalCalldata.selector
            );
        }
    }

    function test_dynamicEntrypointsRejectBadOffsetAndNonzeroTailPadding() external {
        bytes memory badOffset = abi.encodeCall(
            IBuilderRegistry.registerBuilderV1, (LEASE, uint64(0), uint8(0), bytes(""))
        );
        badOffset = bytes.concat(badOffset, bytes32(0));
        _writeWord(badOffset, 100, 160);
        _assertCallRevertsSelector(badOffset, BuilderRegistry.NonCanonicalCalldata.selector);

        bytes memory dirtyPadding =
            abi.encodeCall(IBuilderRegistry.processBuilderMaintenanceV1, (uint8(1), hex"00"));
        dirtyPadding[dirtyPadding.length - 1] = 0x01;
        _assertCallRevertsSelector(dirtyPadding, BuilderRegistry.NonCanonicalCalldata.selector);
    }

    function _assertStaticReturnLength(bytes4 _selector, uint256 _length) private view {
        (bool ok, bytes memory raw) = address(registry).staticcall(abi.encodePacked(_selector));
        assertTrue(ok);
        assertEq(raw.length, _length);
    }

    function _emptyActiveMove(
        BuilderRegistryMerkleTracker.Tree memory _registryTree,
        BuilderRegistryMerkleTracker.Tree memory _admissionTree,
        uint8 _activeIndex,
        uint16 _liabilityPosition,
        SlotChainTypes.RegistryCellV1 memory _cell
    )
        internal
        pure
        virtual
        returns (bytes memory move_)
    {
        SlotChainTypes.RegistryCellV1 memory emptyCell;
        bytes memory registryPath =
            BuilderRegistryMerkleTracker.encodeProof(_registryTree.proof(_activeIndex));
        _registryTree.update(
            _activeIndex, BuilderRegistryMerkleTracker.registryLeaf(_activeIndex, false, emptyCell)
        );
        bytes memory liabilityPath =
            BuilderRegistryMerkleTracker.encodeProof(_admissionTree.proof(_liabilityPosition));
        _admissionTree.update(
            _liabilityPosition,
            BuilderRegistryMerkleTracker.admissionLeaf(_liabilityPosition, true, 2, _cell)
        );
        bytes memory activePath =
            BuilderRegistryMerkleTracker.encodeProof(_admissionTree.proof(_activeIndex));
        _admissionTree.update(
            _activeIndex,
            BuilderRegistryMerkleTracker.admissionLeaf(_activeIndex, false, 0, emptyCell)
        );
        move_ = bytes.concat(hex"00", registryPath, liabilityPath, activePath);
        assert(move_.length == 897);
    }

    function _configBytes() private view returns (bytes memory raw_) {
        (bool ok, bytes memory raw) = address(registry)
            .staticcall(abi.encodePacked(IBuilderRegistry.builderRegistryConfigV1.selector));
        assertTrue(ok);
        assertEq(raw.length, 768);
        return raw;
    }

    function _scheduleWindowRelease(
        uint64 _window,
        uint8 _state,
        uint64 _cursor,
        bytes32 _root
    )
        private
        pure
        returns (bytes memory)
    {
        return abi.encode(bytes4(0x53575231), _window, _state, _cursor, _root);
    }

    function _assertStaticCallFails(bytes memory _calldata) private view {
        (bool ok,) = address(registry).staticcall(_calldata);
        assertFalse(ok);
    }

    function _assertFacetDescriptor(
        address _facet,
        uint8 _expectedKind,
        bytes32 _expectedSelectorHash,
        bytes32 _expectedConfigurationHash
    )
        private
        view
    {
        (bool ok, bytes memory raw) = _facet.staticcall(abi.encodePacked(bytes4(0x5c19dfed)));
        assertTrue(ok);
        assertEq(raw.length, 192);
        assertEq(bytes4(raw), BRF1);
        assertEq(uint8(uint256(_word(raw, 1))), 1);
        assertEq(uint8(uint256(_word(raw, 2))), _expectedKind);
        assertEq(_word(raw, 3), STORAGE_LAYOUT_HASH);
        assertEq(_word(raw, 4), _expectedSelectorHash);
        assertEq(_word(raw, 5), _expectedConfigurationHash);
        (ok, raw) = _facet.staticcall(abi.encodePacked(bytes4(0xf6c0f7d2)));
        assertTrue(ok);
        assertEq(raw.length, 32);
        assertEq(_word(raw, 0), _expectedConfigurationHash);
    }

    function _assertTargetRevertsSelector(
        address _target,
        bytes memory _calldata,
        bytes4 _selector
    )
        private
    {
        (bool ok, bytes memory returndata) = _target.call(_calldata);
        assertFalse(ok);
        assertEq(returndata.length, 4);
        assertEq(bytes4(returndata), _selector);
    }

    function _deployWithSeatMock(
        uint16 _responseSize,
        bool _revertResponse
    )
        private
        returns (IBuilderRegistry deployed_)
    {
        BuilderLifecycleFacetMock mockSeat =
            new BuilderLifecycleFacetMock(1, 0, _responseSize, _revertResponse);
        FacetGraph memory facets = _defaultFacetGraph();
        facets.seat = address(mockSeat);
        facets.seatRuntimeHash = address(mockSeat).codehash;
        address deployed = deployer.deploy(
            _registryInitCodeWithFacets(
                PENALTY_SINK,
                address(proofVerifier),
                address(proofVerifier).codehash,
                proofVerifier.componentConfigHashV2(),
                facets
            )
        );
        deployer.activate(deployed);
        return IBuilderRegistry(deployed);
    }

    function _assertCallRevertsSelector(bytes memory _calldata, bytes4 _selector) private {
        (bool ok, bytes memory returndata) = address(registry).call(_calldata);
        assertFalse(ok);
        assertGe(returndata.length, 4);
        assertEq(bytes4(returndata), _selector);
    }

    function _writeWord(bytes memory _encoded, uint256 _offset, uint256 _value) private pure {
        assert(_offset + 32 <= _encoded.length);
        assembly ("memory-safe") {
            mstore(add(add(_encoded, 32), _offset), _value)
        }
    }

    function _word(bytes memory _encoded, uint256 _index) private pure returns (bytes32 value_) {
        assembly ("memory-safe") {
            value_ := mload(add(add(_encoded, 32), mul(_index, 32)))
        }
    }

    function _expectConstructorWordRevert(
        uint256 _wordIndex,
        uint256 _value,
        bytes4 _error
    )
        private
    {
        bytes memory initCode = _registryInitCode(PENALTY_SINK);
        _writeConstructorWord(initCode, _wordIndex, _value);
        assertTrue(_error != bytes4(0));
        // Partial matching covers parameterised LibExactCall errors as well as bare selectors.
        vm.expectPartialRevert(_error);
        deployer.deploy(initCode);
    }

    function _nextRegistryAddress() private view returns (address registry_) {
        return vm.computeCreateAddress(address(deployer), vm.getNonce(address(deployer)));
    }

    function _writeConstructorWord(
        bytes memory _initCode,
        uint256 _wordIndex,
        uint256 _value
    )
        private
        view
    {
        uint256 creationLength = vm.getCode("BuilderRegistry.sol:BuilderRegistry").length;
        _writeWord(_initCode, creationLength + _wordIndex * 32, _value);
    }

    function _independentEconomicHash(
        uint192 _lease,
        bytes32 _firstName
    )
        private
        view
        returns (bytes32)
    {
        bytes memory classes;
        for (uint256 i; i < 3; ++i) {
            IBuilderRegistry.BuilderRewardClassConfigV1 memory row = rewardClasses[i];
            classes = bytes.concat(
                classes,
                abi.encodePacked(
                    row.classId,
                    i == 0 ? _firstName : row.nameHash,
                    row.fixedWei,
                    row.perExecutionGasWei,
                    row.perPublishedByteWei,
                    row.capWei
                )
            );
        }
        bytes memory payload = bytes.concat(
            abi.encodePacked(
                block.chainid,
                address(token),
                address(token).codehash,
                TOKEN_DECIMALS,
                uint256(_lease),
                uint256(MAXIMUM_BOND),
                uint256(REPORTER_CAP),
                EVIDENCE_DELAY,
                REORG_MARGIN
            ),
            abi.encodePacked(
                uint16(64),
                uint16(76),
                uint16(8),
                uint16(268),
                uint16(16),
                uint16(1072),
                uint8(4),
                PENALTY_SINK,
                CLAIM_WINDOW,
                uint8(3)
            ),
            classes
        );
        assertEq(payload.length, 722);
        return keccak256(
            abi.encodePacked(
                "slot-chain-builder-registry-economic-config-v2", uint32(payload.length), payload
            )
        );
    }

    function _independentTopologyHash(
        uint64 _lastManagedWindow,
        bytes32 _economicHash,
        address _penaltySink
    )
        private
        view
        returns (bytes32)
    {
        bytes memory payload = bytes.concat(
            abi.encodePacked(
                block.chainid,
                L2_CHAIN_ID,
                address(token),
                address(token).codehash,
                TOKEN_DECIMALS,
                GENESIS,
                EVIDENCE_DELAY,
                REORG_MARGIN,
                FIRST_MANAGED_WINDOW,
                _lastManagedWindow,
                _penaltySink,
                CLAIM_WINDOW
            ),
            abi.encodePacked(
                address(settlement),
                address(schedule),
                address(proofVerifier),
                address(proofVerifier).codehash,
                proofVerifier.componentConfigHashV2()
            ),
            abi.encodePacked(
                address(seatFacet),
                address(seatFacet).codehash,
                SEAT_CONFIGURATION_HASH,
                address(leaseFacet),
                address(leaseFacet).codehash,
                LEASE_CONFIGURATION_HASH,
                _economicHash
            )
        );
        assertEq(payload.length, 509);
        return keccak256(
            abi.encodePacked("slot-chain-builder-registry-topology-v3", uint16(509), payload)
        );
    }
}

contract BuilderRegistryProofVerifierFaultTest is BuilderRegistryTestBase {
    using BuilderRegistryMerkleTracker for BuilderRegistryMerkleTracker.Tree;

    bytes4 private constant PROOF_VERIFIER_CONFIG_SELECTOR = 0x0d1c9932;
    bytes4 private constant COMPONENT_CONFIG_SELECTOR = 0xf6c0f7d2;
    bytes4 private constant PROOF_SELECTOR = 0xa9ca9190;

    BuilderProofVerifierMock private _mockVerifier;

    function setUp() public override {
        vm.warp(uint256(GENESIS) + CURRENT_SLOT);
        _setRewardClasses();
        token = new BuilderLeaseTokenMock(TOKEN_DECIMALS);
        settlement = new BuilderSettlementMock();
        schedule = new BuilderScheduleOracleMock();
        proofVerifier = new BuilderRegistryProofVerifierV1();
        seatFacet = new BuilderRegistrySeatLifecycleFacetV1();
        leaseFacet = new BuilderRegistryLeaseLifecycleFacetV1();
        _mockVerifier = new BuilderProofVerifierMock();
        deployer = new BuilderRegistryDeployHarness();
        settlement.setResponse(SETTLEMENT_STATE_SELECTOR, _settlementState(PROTOCOL_VERSION, 1));
        address deployed = deployer.deploy(
            _registryInitCodeWithVerifier(
                PENALTY_SINK,
                address(_mockVerifier),
                address(_mockVerifier).codehash,
                _mockVerifier.expectedConfigurationHash()
            )
        );
        registry = IBuilderRegistry(deployed);
        deployer.activate(deployed);
    }

    function test_proofCallRevertOogShortTrailingAndReturnBombRollBackCompletely() external {
        (address builder, bytes memory witness, bytes32 beforeDigest) = _vacantRegistration();
        for (uint8 mode = 1; mode <= 5; ++mode) {
            _mockVerifier.setMode(PROOF_SELECTOR, mode);
            _assertRegistrationFailsWithRollback(builder, witness, beforeDigest);
        }
    }

    function test_verifierConfigurationCallFaultsRollBackBeforeAnyProofOrCustodyWrite() external {
        (address builder, bytes memory witness, bytes32 beforeDigest) = _vacantRegistration();
        bytes4[2] memory selectors = [PROOF_VERIFIER_CONFIG_SELECTOR, COMPONENT_CONFIG_SELECTOR];
        for (uint256 i; i < selectors.length; ++i) {
            for (uint8 mode = 1; mode <= 5; ++mode) {
                _mockVerifier.setMode(selectors[i], mode);
                _assertRegistrationFailsWithRollback(builder, witness, beforeDigest);
            }
            _mockVerifier.setMode(selectors[i], 0);
        }
    }

    function test_wrongProofEnvelopeAndEveryNonzeroMaskedRootRollBackCompletely() external {
        (address builder, bytes memory witness, bytes32 beforeDigest) = _vacantRegistration();
        bytes32 configurationHash = _mockVerifier.expectedConfigurationHash();

        _mockVerifier.setResponse(
            PROOF_SELECTOR,
            abi.encode(
                bytes4(0x42504f31),
                configurationHash,
                bytes32(0),
                bytes32(uint256(1)),
                bytes32(0),
                bytes32(0)
            )
        );
        _assertRegistrationFailsWithRollback(builder, witness, beforeDigest);

        BuilderRegistryMerkleTracker.Tree memory registryTree =
            BuilderRegistryMerkleTracker.emptyRegistryTree();
        BuilderRegistryMerkleTracker.Tree memory trancheTree =
            BuilderRegistryMerkleTracker.emptyTrancheTree();
        SlotChainTypes.RegistryCellV1 memory newcomer = SlotChainTypes.RegistryCellV1({
            builder: builder,
            bond: LEASE,
            registrationIndex: 0,
            effectiveL2Slot: CURRENT_SLOT + 8 * 384,
            trancheRoot: trancheTree.root(),
            tombstonedAtL2Slot: type(uint64).max
        });
        bytes memory request = bytes.concat(
            bytes4(0x42505231),
            bytes1(uint8(1)),
            registryTree.root(),
            bytes1(uint8(0)),
            bytes1(uint8(0)),
            new bytes(100),
            bytes1(uint8(1)),
            _encodedRegistryCell(newcomer),
            BuilderRegistryMerkleTracker.encodeProof(registryTree.proof(0))
        );
        bytes memory proofCalldata = abi.encodeWithSelector(PROOF_SELECTOR, request);
        bytes32 commitment = keccak256(
            abi.encodePacked("slot-chain-builder-proof-request-v1", uint32(request.length), request)
        );
        for (uint256 maskedWord = 4; maskedWord <= 5; ++maskedWord) {
            bytes32[3] memory roots;
            roots[0] = bytes32(uint256(1));
            roots[maskedWord - 3] = bytes32(uint256(2));
            _mockVerifier.setCallResponse(
                proofCalldata,
                abi.encode(
                    bytes4(0x42504f31), configurationHash, commitment, roots[0], roots[1], roots[2]
                )
            );
            _assertRegistrationFailsWithRollback(builder, witness, beforeDigest);
        }
    }

    function _vacantRegistration()
        private
        returns (address builder_, bytes memory witness_, bytes32 beforeDigest_)
    {
        BuilderRegistryMerkleTracker.Tree memory registryTree =
            BuilderRegistryMerkleTracker.emptyRegistryTree();
        BuilderRegistryMerkleTracker.Tree memory admissionTree =
            BuilderRegistryMerkleTracker.emptyAdmissionTree();
        builder_ = address(0xB017D3);
        witness_ = bytes.concat(
            BuilderRegistryMerkleTracker.encodeProof(registryTree.proof(0)),
            BuilderRegistryMerkleTracker.encodeProof(admissionTree.proof(0))
        );
        _fundAndApprove(builder_, LEASE);
        beforeDigest_ = _stateDigest(builder_);
    }

    function _assertRegistrationFailsWithRollback(
        address _builder,
        bytes memory _witness,
        bytes32 _beforeDigest
    )
        private
    {
        vm.prank(_builder);
        (bool ok,) = address(registry)
            .call(
                abi.encodeCall(
                    IBuilderRegistry.registerBuilderV1, (LEASE, uint64(0), uint8(0), _witness)
                )
            );
        assertFalse(ok);
        assertEq(_stateDigest(_builder), _beforeDigest);
    }

    function _encodedRegistryCell(SlotChainTypes.RegistryCellV1 memory _cell)
        private
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            _cell.builder,
            _cell.bond,
            _cell.registrationIndex,
            _cell.effectiveL2Slot,
            _cell.trancheRoot,
            _cell.tombstonedAtL2Slot
        );
    }
}
