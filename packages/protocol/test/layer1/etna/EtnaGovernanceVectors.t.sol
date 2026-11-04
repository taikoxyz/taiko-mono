// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EtnaStakingRegistryTestBase } from "./EtnaStakingRegistryTestBase.sol";
import { EtnaTestKeys } from "./EtnaTestKeys.sol";
import { LibEtnaVectors } from "./LibEtnaVectors.sol";
import { ReentrantERC20 } from "./ReentrantERC20.sol";
import { Vm } from "forge-std/src/Vm.sol";
import { IEtnaInbox } from "src/layer1/etna/iface/IEtnaInbox.sol";
import { IEtnaStakingRegistry } from "src/layer1/etna/iface/IEtnaStakingRegistry.sol";
import { EtnaStakingRegistry } from "src/layer1/etna/impl/EtnaStakingRegistry.sol";

/// @notice Shared client/contract ABI, ERC-7201 namespaces and overflow-safe penalty vectors.
contract EtnaGovernanceVectorsTest is EtnaStakingRegistryTestBase {
    function test_vectors_GovernanceSelectorsAndCalldataMatchSolidityAbi() external view {
        string memory j = LibEtnaVectors.load();
        bytes32 key = 0x7268c66e6d00f6fb2bc2a14b5bd15892af0853ac758024d8795d61a5acedf607;
        _assertAbi(
            j,
            "top_up",
            IEtnaStakingRegistry.topUp.selector,
            abi.encodeCall(IEtnaStakingRegistry.topUp, (0, 100))
        );
        _assertAbi(
            j,
            "activate_top_up",
            IEtnaStakingRegistry.activateTopUp.selector,
            abi.encodeCall(IEtnaStakingRegistry.activateTopUp, (0))
        );
        _assertAbi(
            j,
            "forfeit",
            IEtnaStakingRegistry.forfeit.selector,
            abi.encodeCall(
                IEtnaStakingRegistry.forfeit, (0, key, bytes32(uint256(42)), 1_700_000_123)
            )
        );
        IEtnaInbox.Exclusion[] memory exclusions = new IEtnaInbox.Exclusion[](1);
        exclusions[0] = IEtnaInbox.Exclusion(0, key);
        uint256[] memory blanks = new uint256[](2);
        blanks[0] = 3;
        blanks[1] = 5;
        _assertAbi(
            j,
            "recover",
            IEtnaInbox.recover.selector,
            abi.encodeCall(IEtnaInbox.recover, (2, 12, 7, 1_700_000_123, exclusions, blanks, 4))
        );
        _assertAbi(
            j,
            "invalidate_recovery_nonce",
            IEtnaInbox.invalidateRecoveryNonce.selector,
            abi.encodeCall(IEtnaInbox.invalidateRecoveryNonce, (7))
        );
        _assertAbi(
            j,
            "schedule_rules",
            IEtnaInbox.scheduleRules.selector,
            abi.encodeCall(IEtnaInbox.scheduleRules, (2, 1_700_003_600))
        );
        _assertAbi(
            j,
            "schedule_stop",
            IEtnaInbox.scheduleStop.selector,
            abi.encodeCall(IEtnaInbox.scheduleStop, (1_700_007_200, 600))
        );
        _assertAbi(
            j,
            "set_origin",
            IEtnaInbox.setOrigin.selector,
            abi.encodeCall(
                IEtnaInbox.setOrigin, (1000, bytes32(uint256(0x51)), bytes32(uint256(0x52)))
            )
        );
    }

    function test_vectors_GovernanceEventTopicsAndDataMatchDeclaredAbi() external {
        string memory j = LibEtnaVectors.load();
        vm.recordLogs();
        emit IEtnaStakingRegistry.TopUpDeposited(0, 100, 42);
        emit IEtnaStakingRegistry.TopUpActivated(0, 100);
        emit IEtnaStakingRegistry.Forfeited(
            0,
            0x7268c66e6d00f6fb2bc2a14b5bd15892af0853ac758024d8795d61a5acedf607,
            bytes32(uint256(42)),
            100,
            10
        );
        emit IEtnaInbox.RecoveryNonceInvalidated(7, 8);
        emit IEtnaStakingRegistry.BondDisplaced(12, 7, 4096);
        // The packed slot 293 word of the ordinary `inbox_293` item.
        emit IEtnaInbox
            .RulesScheduleUpdated(uint256(
                LibEtnaVectors.bytes32At(j, ".packed_words.inbox_293[0].word")
            ));
        emit IEtnaInbox.StartWritten(1000, bytes32(uint256(0x51)), bytes32(uint256(0x52)));
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 7);
        string[7] memory names = [
            "top_up_deposited",
            "top_up_activated",
            "forfeited",
            "recovery_nonce_invalidated",
            "bond_displaced",
            "rules_schedule_updated",
            "start_written"
        ];
        for (uint256 i; i < names.length; ++i) {
            string memory row = string.concat(".governance_events.", names[i]);
            assertEq(logs[i].topics[0], LibEtnaVectors.bytes32At(j, string.concat(row, ".topic0")));
            uint256 indexedCount = LibEtnaVectors.lengthAt(j, string.concat(row, ".indexed_topics"));
            assertEq(logs[i].topics.length, indexedCount + 1);
            for (uint256 t; t < indexedCount; ++t) {
                assertEq(
                    logs[i].topics[t + 1],
                    LibEtnaVectors.bytes32At(
                        j, string.concat(row, ".indexed_topics[", vm.toString(t), "]")
                    )
                );
            }
            assertEq(logs[i].data, LibEtnaVectors.bytesAt(j, string.concat(row, ".data")));
        }
    }

    function test_vectors_NamespaceWordsAreExactlyWhatRegistryViewsRead() external {
        string memory j = LibEtnaVectors.load();
        string memory p = ".layout.registry.top_ups";
        bytes32 base = LibEtnaVectors.bytes32At(j, string.concat(p, ".base"));
        assertEq(base, _erc7201("taiko.etna.registry.top-ups"));
        for (uint256 i; i < 2; ++i) {
            string memory row = string.concat(p, ".slots[", vm.toString(i), "]");
            uint256 bondId = LibEtnaVectors.uintAt(j, string.concat(row, ".bond_id"));
            bytes32 slot = LibEtnaVectors.bytes32At(j, string.concat(row, ".slot"));
            bytes32 readySlot = LibEtnaVectors.bytes32At(j, string.concat(row, ".ready_slot"));
            assertEq(slot, keccak256(abi.encode(bondId, base)));
            assertEq(uint256(readySlot), uint256(slot) + 1);
            vm.store(address(registry), slot, bytes32(100 + i));
            vm.store(address(registry), readySlot, bytes32(200 + i));
            (uint256 pending, uint48 ready) = registry.topUpOf(bondId);
            assertEq(pending, 100 + i);
            assertEq(ready, 200 + i);
        }
        p = ".layout.registry.forfeitures";
        base = LibEtnaVectors.bytes32At(j, string.concat(p, ".base"));
        assertEq(base, _erc7201("taiko.etna.registry.forfeitures"));
        for (uint256 i; i < 2; ++i) {
            string memory row = string.concat(p, ".slots[", vm.toString(i), "]");
            bytes32 key = LibEtnaVectors.bytes32At(j, string.concat(row, ".entry_key"));
            bytes32 slot = LibEtnaVectors.bytes32At(j, string.concat(row, ".slot"));
            assertEq(slot, keccak256(abi.encode(key, base)));
            vm.store(address(registry), slot, bytes32(uint256(1)));
            assertTrue(registry.forfeited(key));
        }
    }

    function test_vectors_ForfeitureRoundingSourcesAndUint256MaximumUseActualContract() external {
        string memory j = LibEtnaVectors.load();
        mockInbox.setInitialized(true);
        for (uint256 i; i < 5; ++i) {
            string memory row = string.concat(".forfeitures[", vm.toString(i), "]");
            uint256 effective = LibEtnaVectors.uintAt(j, string.concat(row, ".eff_stake"));
            uint256 pending = LibEtnaVectors.uintAt(j, string.concat(row, ".pending_top_up"));
            (EtnaStakingRegistry actual, ReentrantERC20 actualToken) = _forfeitureFixture(
                effective, pending, LibEtnaVectors.uintAt(j, string.concat(row, ".forfeit_bps"))
            );
            IEtnaStakingRegistry.Entry memory entry = actual.bondAt(0).entry;
            actual.forfeit(
                0, keccak256(abi.encode(entry.ckPrefix, entry.ckX)), bytes32(i), block.timestamp
            );
            assertEq(
                actualToken.balanceOf(SLASH_SINK),
                LibEtnaVectors.uintAt(j, string.concat(row, ".penalty"))
            );
            assertEq(
                actual.bondAt(0).entry.effStake,
                LibEtnaVectors.uintAt(j, string.concat(row, ".eff_stake_after"))
            );
            (uint256 remaining, uint48 ready) = actual.topUpOf(0);
            assertEq(
                remaining, LibEtnaVectors.uintAt(j, string.concat(row, ".pending_top_up_after"))
            );
            assertEq(ready, remaining == 0 ? 0 : 123);
        }
    }

    /// @dev A registry with `minStake` 1 and `_forfeitBps` whose bond 0 holds `_effective`
    /// effective and `_pending` pending principal. It registers one base unit, then plants the
    /// split in bond 0's record (the `bonds` mapping at R + 6, effStake in its second word) and
    /// the top-ups namespace, with the registry holding all of it: the uint256 maximum does not
    /// fit an admission value, and pending-only principal cannot be deposited. All authorization,
    /// arithmetic, checkpoint and token-transfer code remains real.
    function _forfeitureFixture(
        uint256 _effective,
        uint256 _pending,
        uint256 _forfeitBps
    )
        private
        returns (EtnaStakingRegistry actual_, ReentrantERC20 token_)
    {
        token_ = new ReentrantERC20();
        IEtnaStakingRegistry.Config memory cfg =
            _registryConfig(address(token_), address(mockInbox));
        cfg.minStake = 1;
        cfg.forfeitBps = _forfeitBps;
        actual_ = _deployRegistry(cfg);
        token_.mint(Alice, 1);
        token_.mint(address(actual_), _effective + _pending - 1);
        vm.prank(Alice);
        token_.approve(address(actual_), type(uint256).max);
        bytes memory publicKey = EtnaTestKeys.publicKey(0xC0A);
        bytes memory pop = EtnaTestKeys.popSig(0xC0A, actual_, Alice);
        vm.prank(Alice);
        actual_.register(publicKey, 1, pop);
        uint256 bondSlot = uint256(keccak256(abi.encode(uint256(0), REGISTRY_BASE + 6)));
        vm.store(address(actual_), bytes32(bondSlot + 1), bytes32(_effective));
        if (_pending != 0) {
            bytes32 pendingSlot =
                keccak256(abi.encode(uint256(0), _erc7201("taiko.etna.registry.top-ups")));
            vm.store(address(actual_), pendingSlot, bytes32(_pending));
            vm.store(address(actual_), bytes32(uint256(pendingSlot) + 1), bytes32(uint256(123)));
        }
    }

    function _assertAbi(
        string memory _j,
        string memory _name,
        bytes4 _selector,
        bytes memory _calldata
    )
        private
        view
    {
        string memory p = string.concat(".governance_abi.", _name);
        assertEq(
            abi.encodePacked(_selector), LibEtnaVectors.bytesAt(_j, string.concat(p, ".selector"))
        );
        assertEq(_calldata, LibEtnaVectors.bytesAt(_j, string.concat(p, ".calldata")));
    }
}
