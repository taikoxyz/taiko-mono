// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {
    IBuilderRegistry
} from "../../../../contracts/layer1/slotchain/iface/IBuilderRegistry.sol";
import { SlotChainTypes } from "../../../../contracts/shared/slotchain/SlotChainTypes.sol";
import {
    LibSlotChainEncoding
} from "../../../../contracts/shared/slotchain/libs/LibSlotChainEncoding.sol";
import { BuilderRegistryTestBase } from "./BuilderRegistry.t.sol";
import {
    BuilderLeaseTokenMock,
    BuilderRegistryMerkleTracker
} from "./BuilderRegistryTestHelpers.sol";
import { Vm } from "forge-std/src/Vm.sol";

contract BuilderRegistryInvariantHandler {
    using BuilderRegistryMerkleTracker for BuilderRegistryMerkleTracker.Tree;

    Vm private constant _VM = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    IBuilderRegistry private immutable _registry;
    BuilderLeaseTokenMock private immutable _token;
    uint64 private immutable _effectiveL2Slot;
    uint192 private immutable _lease;
    uint192 private immutable _maximumBond;

    bytes32[128] private _registryNodes;
    bytes32[128] private _admissionNodes;
    bytes32[5] private _admissionUpperSiblings;
    bytes32 private _emptyTrancheRoot;
    uint64 private _successfulRegistrations;
    uint256 private _accountedBond;
    uint256 private _forcedSurplus;

    constructor(
        IBuilderRegistry _registryAddress,
        BuilderLeaseTokenMock _tokenAddress,
        uint64 _effectiveSlot,
        uint192 _leaseAmount,
        uint192 _maximumBondAmount
    ) {
        _registry = _registryAddress;
        _token = _tokenAddress;
        _effectiveL2Slot = _effectiveSlot;
        _lease = _leaseAmount;
        _maximumBond = _maximumBondAmount;
        SlotChainTypes.RegistryCellV1 memory emptyCell;
        for (uint8 i; i < 64; ++i) {
            _registryNodes[uint256(64) + i] =
                BuilderRegistryMerkleTracker.registryLeaf(i, false, emptyCell);
            _admissionNodes[uint256(64) + i] =
                BuilderRegistryMerkleTracker.admissionLeaf(i, false, 0, emptyCell);
        }
        _initializeTree(_registryNodes, true);
        _initializeTree(_admissionNodes, false);
        BuilderRegistryMerkleTracker.Tree memory fullAdmission =
            BuilderRegistryMerkleTracker.emptyAdmissionTree();
        bytes32[] memory fullAdmissionProof = fullAdmission.proof(0);
        for (uint256 i; i < 5; ++i) {
            _admissionUpperSiblings[i] = fullAdmissionProof[i + 6];
        }
        BuilderRegistryMerkleTracker.Tree memory trancheTree =
            BuilderRegistryMerkleTracker.emptyTrancheTree();
        _emptyTrancheRoot = trancheTree.root();
    }

    function registerNext(uint192 _rawBond) external {
        if (_successfulRegistrations >= 64) return;
        uint192 bond = uint192(_bound(_rawBond, _lease, _maximumBond));
        uint8 activeIndex = uint8(_successfulRegistrations);
        uint64 registrationIndex = _successfulRegistrations;
        address builder = address(uint160(uint256(registrationIndex) + 0x10000));
        bytes32[] memory registryProof = _proof(_registryNodes, activeIndex);
        bytes32[] memory admissionProof = new bytes32[](11);
        bytes32[] memory activeAdmissionProof = _proof(_admissionNodes, activeIndex);
        for (uint256 i; i < 6; ++i) {
            admissionProof[i] = activeAdmissionProof[i];
        }
        for (uint256 i; i < 5; ++i) {
            admissionProof[i + 6] = _admissionUpperSiblings[i];
        }
        bytes memory witness = bytes.concat(
            BuilderRegistryMerkleTracker.encodeProof(registryProof),
            BuilderRegistryMerkleTracker.encodeProof(admissionProof)
        );
        _token.mint(builder, bond);
        _VM.prank(builder);
        _token.approve(address(_registry), type(uint256).max);
        _VM.prank(builder);
        _registry.registerBuilderV1(bond, registrationIndex, activeIndex, witness);

        SlotChainTypes.RegistryCellV1 memory cell = SlotChainTypes.RegistryCellV1({
            builder: builder,
            bond: bond,
            registrationIndex: registrationIndex,
            effectiveL2Slot: _effectiveL2Slot,
            trancheRoot: _emptyTrancheRoot,
            tombstonedAtL2Slot: type(uint64).max
        });
        _updateTree(
            _registryNodes,
            activeIndex,
            BuilderRegistryMerkleTracker.registryLeaf(activeIndex, true, cell),
            true
        );
        _updateTree(
            _admissionNodes,
            activeIndex,
            BuilderRegistryMerkleTracker.admissionLeaf(activeIndex, true, 1, cell),
            false
        );
        ++_successfulRegistrations;
        _accountedBond += bond;
    }

    function rejectDuplicateOrRacedRegistration(
        bool _duplicate,
        uint64 _indexDelta
    )
        external
    {
        if (_successfulRegistrations == 0 || _successfulRegistrations >= 64) return;
        uint64 liveIndex = _successfulRegistrations - 1;
        address builder = _duplicate
            ? address(uint160(uint256(liveIndex) + 0x10000))
            : address(uint160(uint256(_successfulRegistrations) + 0x20000));
        uint64 expectedIndex = _successfulRegistrations + uint64(_bound(_indexDelta, 1, 64));
        bytes32 stateBefore = stateDigest();
        _token.mint(builder, _lease);
        _VM.prank(builder);
        _token.approve(address(_registry), type(uint256).max);
        _VM.prank(builder);
        (bool ok,) = address(_registry)
            .call(
                abi.encodeCall(
                    IBuilderRegistry.registerBuilderV1,
                    (_lease, expectedIndex, uint8(_successfulRegistrations), bytes(""))
                )
            );
        if (ok || stateDigest() != stateBefore) revert UnexpectedSuccessfulRegistration();
    }

    function forceSurplus(uint128 _rawAmount) external {
        uint256 amount = _bound(_rawAmount, 1, type(uint96).max);
        _token.mint(address(_registry), amount);
        _forcedSurplus += amount;
    }

    function stateDigest() public view returns (bytes32) {
        (bytes4 aMagic, uint64 admissionVersion, bytes32 admissionRoot) =
            _registry.admissionStateV1();
        (
            bytes4 rMagic,
            uint8 schema,
            uint8 activeCount,
            uint64 registryVersion,
            uint64 registryAdmissionVersion,
            uint256 nextRegistrationIndex,
            bytes32 registryRoot
        ) = _registry.scheduleRegistryStateV1();
        return keccak256(
            abi.encode(
                aMagic,
                admissionVersion,
                admissionRoot,
                rMagic,
                schema,
                activeCount,
                registryVersion,
                registryAdmissionVersion,
                nextRegistrationIndex,
                registryRoot,
                _token.rawBalance(address(_registry))
            )
        );
    }

    function successfulRegistrations() external view returns (uint64) {
        return _successfulRegistrations;
    }

    function accountedBond() external view returns (uint256) {
        return _accountedBond;
    }

    function forcedSurplus() external view returns (uint256) {
        return _forcedSurplus;
    }

    function expectedRegistryRoot() external view returns (bytes32) {
        return _registryNodes[1];
    }

    function expectedAdmissionRoot() external view returns (bytes32) {
        bytes32 root = _admissionNodes[1];
        for (uint8 height = 6; height < 11; ++height) {
            root = LibSlotChainEncoding.hashAdmissionNode(
                height, root, _admissionUpperSiblings[height - 6]
            );
        }
        return root;
    }

    function _initializeTree(bytes32[128] storage _nodes, bool _registryKind) private {
        uint256 width = 64;
        uint8 height;
        while (width > 1) {
            uint256 parentStart = width >> 1;
            for (uint256 i; i < width; i += 2) {
                bytes32 left = _nodes[width + i];
                bytes32 right = _nodes[width + i + 1];
                _nodes[parentStart + i / 2] = _registryKind
                    ? LibSlotChainEncoding.hashRegistryNode(height, left, right)
                    : LibSlotChainEncoding.hashAdmissionNode(height, left, right);
            }
            width >>= 1;
            ++height;
        }
    }

    function _proof(
        bytes32[128] storage _nodes,
        uint8 _index
    )
        private
        view
        returns (bytes32[] memory siblings_)
    {
        siblings_ = new bytes32[](6);
        uint256 position = uint256(64) + _index;
        for (uint256 height; height < 6; ++height) {
            siblings_[height] = _nodes[position ^ 1];
            position >>= 1;
        }
    }

    function _updateTree(
        bytes32[128] storage _nodes,
        uint8 _index,
        bytes32 _leaf,
        bool _registryKind
    )
        private
    {
        uint256 position = uint256(64) + _index;
        _nodes[position] = _leaf;
        uint8 height;
        while (position > 1) {
            uint256 parent = position >> 1;
            bytes32 left = _nodes[parent << 1];
            bytes32 right = _nodes[(parent << 1) | 1];
            _nodes[parent] = _registryKind
                ? LibSlotChainEncoding.hashRegistryNode(height, left, right)
                : LibSlotChainEncoding.hashAdmissionNode(height, left, right);
            position = parent;
            ++height;
        }
    }

    function _bound(
        uint256 _value,
        uint256 _minimum,
        uint256 _maximum
    )
        private
        pure
        returns (uint256 bounded_)
    {
        if (_value >= _minimum && _value <= _maximum) return _value;
        return _minimum + (_value % (_maximum - _minimum + 1));
    }

    error UnexpectedSuccessfulRegistration();
}

contract BuilderRegistryInvariantTest is BuilderRegistryTestBase {
    BuilderRegistryInvariantHandler private _handler;

    function setUp() public override {
        super.setUp();
        _handler = new BuilderRegistryInvariantHandler(
            registry, token, CURRENT_SLOT + 8 * 384, LEASE, MAXIMUM_BOND
        );
        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = BuilderRegistryInvariantHandler.registerNext.selector;
        selectors[1] = BuilderRegistryInvariantHandler.rejectDuplicateOrRacedRegistration.selector;
        selectors[2] = BuilderRegistryInvariantHandler.forceSurplus.selector;
        targetSelector(FuzzSelector({ addr: address(_handler), selectors: selectors }));
        targetContract(address(_handler));
    }

    function invariant_rootsVersionsCapacityAndCustodyRemainExact() external view {
        uint64 successful = _handler.successfulRegistrations();
        (
            bytes4 rMagic,
            uint8 schema,
            uint8 activeCount,
            uint64 registryVersion,
            uint64 admissionVersion,
            uint256 nextRegistrationIndex,
            bytes32 registryRoot
        ) = registry.scheduleRegistryStateV1();
        (bytes4 aMagic, uint64 aVersion, bytes32 admissionRoot) = registry.admissionStateV1();

        assertEq(rMagic, BRS1);
        assertEq(aMagic, ADS1);
        assertEq(schema, 1);
        assertLe(activeCount, 64);
        assertEq(activeCount, successful);
        assertEq(registryVersion, successful);
        assertEq(admissionVersion, successful);
        assertEq(aVersion, successful);
        assertEq(nextRegistrationIndex, successful);
        assertEq(registryRoot, _handler.expectedRegistryRoot());
        assertEq(admissionRoot, _handler.expectedAdmissionRoot());
        assertEq(
            token.rawBalance(address(registry)), _handler.accountedBond() + _handler.forcedSurplus()
        );
    }
}
