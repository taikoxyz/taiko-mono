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
            abi.encodeCall(IEtnaInbox.recover, (2, 12, 7, 1_700_000_123, exclusions, blanks))
        );
        _assertAbi(
            j,
            "invalidate_recovery_nonce",
            IEtnaInbox.invalidateRecoveryNonce.selector,
            abi.encodeCall(IEtnaInbox.invalidateRecoveryNonce, (7))
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
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 4);
        string[4] memory names =
            ["top_up_deposited", "top_up_activated", "forfeited", "recovery_nonce_invalidated"];
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

    function test_vectors_NewNamespaceWordsAreExactlyWhatRegistryViewsRead() external {
        string memory j = LibEtnaVectors.load();
        string memory p = ".layout.registry.top_ups";
        bytes32 base = LibEtnaVectors.bytes32At(j, string.concat(p, ".base"));
        assertEq(base, _namespace("taiko.etna.registry.top-ups"));
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
        assertEq(base, _namespace("taiko.etna.registry.forfeitures"));
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
            ReentrantERC20 actualToken = new ReentrantERC20();
            IEtnaStakingRegistry.Config memory cfg =
                _registryConfig(address(actualToken), address(mockInbox));
            cfg.minStake = 1;
            cfg.forfeitBps = LibEtnaVectors.uintAt(j, string.concat(row, ".forfeit_bps"));
            EtnaStakingRegistry actual = _deployRegistry(cfg);
            actualToken.mint(Alice, effective + pending);
            vm.prank(Alice);
            actualToken.approve(address(actual), type(uint256).max);
            bytes memory publicKey = EtnaTestKeys.publicKey(0xC0A);
            bytes memory pop = EtnaTestKeys.popSig(0xC0A, actual, Alice);
            vm.prank(Alice);
            actual.register(publicKey, effective + pending, pop);
            if (pending != 0) {
                // Boundary fixtures include pending-only principal. Plant just its split; all
                // authorization, arithmetic, checkpoint and token-transfer code remains real.
                uint256 entrySlot = uint256(
                    keccak256(
                        abi.encode(
                            uint256(
                                    0x46e4e2fea4a7d0ac18aca03baa3a1f64e1be04ec23c1ca0c7b901af7b59b8000
                                ) + 1
                        )
                    )
                );
                vm.store(address(actual), bytes32(entrySlot + 1), bytes32(effective));
                bytes32 pendingSlot =
                    keccak256(abi.encode(uint256(0), _namespace("taiko.etna.registry.top-ups")));
                vm.store(address(actual), pendingSlot, bytes32(pending));
                vm.store(address(actual), bytes32(uint256(pendingSlot) + 1), bytes32(uint256(123)));
            }
            IEtnaStakingRegistry.Entry memory entry = actual.entryAt(0);
            actual.forfeit(
                0, keccak256(abi.encode(entry.ckPrefix, entry.ckX)), bytes32(i), block.timestamp
            );
            assertEq(
                actualToken.balanceOf(SLASH_SINK),
                LibEtnaVectors.uintAt(j, string.concat(row, ".penalty"))
            );
            assertEq(
                actual.entryAt(0).effStake,
                LibEtnaVectors.uintAt(j, string.concat(row, ".eff_stake_after"))
            );
            (uint256 remaining, uint48 ready) = actual.topUpOf(0);
            assertEq(
                remaining, LibEtnaVectors.uintAt(j, string.concat(row, ".pending_top_up_after"))
            );
            assertEq(ready, remaining == 0 ? 0 : 123);
        }
    }

    function test_constructor_RevertWhen_ForfeitRateZeroOrAboveWholeBalance() external {
        IEtnaStakingRegistry.Config memory cfg = _registryConfig(address(token), address(mockInbox));
        cfg.forfeitBps = 0;
        vm.expectRevert(IEtnaStakingRegistry.InvalidConfig.selector);
        new EtnaStakingRegistry(cfg);
        cfg.forfeitBps = 10_001;
        vm.expectRevert(IEtnaStakingRegistry.InvalidConfig.selector);
        new EtnaStakingRegistry(cfg);
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

    function _namespace(string memory _name) private pure returns (bytes32) {
        return bytes32(
            uint256(keccak256(abi.encode(uint256(keccak256(bytes(_name))) - 1))) & ~uint256(0xff)
        );
    }
}
