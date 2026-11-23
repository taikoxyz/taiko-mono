// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EtnaInboxTestBase } from "./EtnaInboxTestBase.sol";
import { Vm } from "forge-std/src/Vm.sol";
import { IEtnaInbox } from "src/layer1/etna/iface/IEtnaInbox.sol";
import { IUnzenProposeCutoff } from "src/layer1/etna/iface/IUnzenProposeCutoff.sol";
import { LibEtnaVectors } from "test/shared/etna/LibEtnaVectors.sol";

/// @title EtnaGovernanceVectorsTest
/// @notice Pins the Inbox's governance calldata, view calldata and event encodings to the
/// `governance_abi`, `view_abi` and `governance_events` entries labelled `inbox` (and the Unzen
/// Inbox's cutoff view, labelled `unzen_inbox`) of `testdata/etna_vectors/vectors.json`.
/// @dev The staking contract's entries are read by `EtnaStakingVectors.t.sol` on L2. Every entry
/// carries one of the three labels, so between them the two suites read every entry.
contract EtnaGovernanceVectorsTest is EtnaInboxTestBase {
    /// @dev The X of K2, the compressed key of private key 2.
    bytes32 private constant _K2_X =
        0xc6047f9441ed7d6d3045406e95c07cd85c778e4b8cef3ca7abac09b95c709ee5;

    /// @dev The fallback key hash of [K1, K2].
    bytes32 private constant _TWO_KEYS_HASH =
        0x2bc20cdc8e87ed785fc8f8012165afba944fd223ecf8973e165e41f4cddf0cea;

    /// @dev The deadline the vector authorizations carry.
    uint256 private constant _VALID_UNTIL = 1_700_000_123;

    /// @dev The forced transaction and fee of the vector forced-inclusion entries.
    bytes private constant _FI_TX = hex"c0";
    uint256 private constant _FI_FEE_WEI = 1_000_000_000;

    function test_vectors_InboxSelectorsAndCalldataMatchSolidityAbi() external view {
        string memory j = LibEtnaVectors.load();
        _assertLabels(j, ".governance_abi", 9, 0);
        _assertLabels(j, ".view_abi", 7, 1);

        _assertCall(
            j,
            ".governance_abi.recover",
            "inbox",
            IEtnaInbox.recover.selector,
            abi.encodeCall(IEtnaInbox.recover, (2, 12, 7, _VALID_UNTIL, _fiToClear(), 4))
        );
        _assertCall(
            j,
            ".governance_abi.invalidate_recovery_nonce",
            "inbox",
            IEtnaInbox.invalidateRecoveryNonce.selector,
            abi.encodeCall(IEtnaInbox.invalidateRecoveryNonce, (7))
        );
        _assertCall(
            j,
            ".governance_abi.schedule_rules",
            "inbox",
            IEtnaInbox.scheduleRules.selector,
            abi.encodeCall(IEtnaInbox.scheduleRules, (1, 2, 1_700_003_600))
        );
        _assertCall(
            j,
            ".governance_abi.schedule_stop",
            "inbox",
            IEtnaInbox.scheduleStop.selector,
            abi.encodeCall(IEtnaInbox.scheduleStop, (1, 1_700_007_200))
        );
        _assertCall(
            j,
            ".governance_abi.set_origin",
            "inbox",
            IEtnaInbox.setOrigin.selector,
            abi.encodeCall(IEtnaInbox.setOrigin, (1000))
        );
        _assertCall(
            j,
            ".governance_abi.save_forced_inclusion",
            "inbox",
            IEtnaInbox.saveForcedInclusion.selector,
            abi.encodeCall(IEtnaInbox.saveForcedInclusion, (_FI_TX))
        );
        _assertCall(
            j,
            ".governance_abi.sweep_protocol_fees",
            "inbox",
            IEtnaInbox.sweepProtocolFees.selector,
            abi.encodeCall(IEtnaInbox.sweepProtocolFees, ())
        );
        _assertCall(
            j,
            ".governance_abi.set_fallback_keys",
            "inbox",
            IEtnaInbox.setFallbackKeys.selector,
            abi.encodeCall(IEtnaInbox.setFallbackKeys, (_twoKeys()))
        );
        _assertCall(
            j,
            ".governance_abi.set_min_total_stake",
            "inbox",
            IEtnaInbox.setMinTotalStake.selector,
            abi.encodeCall(IEtnaInbox.setMinTotalStake, (type(uint256).max))
        );

        _assertView(j, "config_hash", "inbox", IEtnaInbox.configHash.selector);
        _assertView(j, "etna_staking", "inbox", IEtnaInbox.etnaStaking.selector);
        _assertView(j, "unsettled_limit", "inbox", IEtnaInbox.unsettledLimit.selector);
        _assertView(j, "get_fallback_keys", "inbox", IEtnaInbox.getFallbackKeys.selector);
        _assertView(j, "fallback_keys_hash", "inbox", IEtnaInbox.fallbackKeysHash.selector);
        _assertView(j, "min_total_stake", "inbox", IEtnaInbox.minTotalStake.selector);
        _assertView(j, "etna_start", "inbox", IEtnaInbox.etnaStart.selector);
        _assertView(j, "propose_cutoff", "unzen_inbox", IUnzenProposeCutoff.proposeCutoff.selector);
        // The Unzen cutoff the start write reads is one uint48 word: the installed cutoff, or 0.
        string memory cutoff = ".view_abi.propose_cutoff.results";
        assertEq(LibEtnaVectors.lengthAt(j, cutoff), 2, "cutoff results");
        for (uint256 i; i < 2; ++i) {
            string memory r = LibEtnaVectors.itemAt(cutoff, i);
            assertEq(
                abi.encode(uint48(LibEtnaVectors.uintAt(j, string.concat(r, "values[0]")))),
                LibEtnaVectors.bytesAt(j, string.concat(r, "data")),
                "cutoff word"
            );
        }
    }

    function test_vectors_InboxEventTopicsAndDataMatchDeclaredAbi() external {
        string memory j = LibEtnaVectors.load();
        assertEq(LibEtnaVectors.countWithContract(j, ".governance_events", "inbox"), 10, "inbox");
        assertEq(
            LibEtnaVectors.countWithContract(j, ".governance_events", "inbox")
                + LibEtnaVectors.countWithContract(j, ".governance_events", "staking"),
            LibEtnaVectors.entryCount(j, ".governance_events"),
            "every event names the Inbox or the staking contract"
        );

        vm.recordLogs();
        emit IEtnaInbox.FallbackKeysUpdated(DEFAULT_FALLBACK_KEYS_HASH, _defaultFallbackKeys());
        emit IEtnaInbox.MinTotalStakeUpdated(type(uint256).max);
        emit IEtnaInbox.RecoveryNonceInvalidated(7, 8);
        // The packed slot 293 word of the ordinary `inbox_293` item.
        emit IEtnaInbox
            .RulesScheduleUpdated(uint256(
                LibEtnaVectors.bytes32At(j, ".packed_words.inbox_293[0].word")
            ));
        emit IEtnaInbox.StartWritten(1000, bytes32(uint256(0x51)), bytes32(uint256(0x52)));
        emit IEtnaInbox.EtnaInitialized(
            LibEtnaVectors.bytes32At(j, ".config.hash"), ETNA_STAKING, UNSETTLED_LIMIT
        );
        emit IEtnaInbox.Landed(0, 6, 12, bytes32(uint256(0x77)), 1);
        emit IEtnaInbox.ForcedInclusionSaved(3, _FI_TX, _FI_FEE_WEI);
        emit IEtnaInbox.ProtocolFeesSwept(_FI_FEE_WEI);
        emit IEtnaInbox.Recovered(2, 12, 50, _VALID_UNTIL, _TWO_KEYS_HASH, _fiToClear());
        Vm.Log[] memory logs = vm.getRecordedLogs();

        string[10] memory names = [
            "fallback_keys_updated",
            "min_total_stake_updated",
            "recovery_nonce_invalidated",
            "rules_schedule_updated",
            "start_written",
            "etna_initialized",
            "landed",
            "forced_inclusion_saved",
            "protocol_fees_swept",
            "recovered"
        ];
        assertEq(logs.length, names.length, "one log per event");
        for (uint256 i; i < names.length; ++i) {
            _assertEvent(j, string.concat(".governance_events.", names[i], "."), logs[i], names[i]);
        }
    }

    /// @dev The `setFallbackKeys` and `setMinTotalStake` calldata of `governance_abi`, sent to the
    /// initialized Inbox by its owner, emit the vector events: the two_keys list's
    /// `FallbackKeysUpdated` and `min_total_stake_updated`. The views then return `view_abi`'s
    /// two_keys and fallback_only data, and `setMinTotalStake(0)` its zero data.
    function test_vectors_InboxSetterCalldataEmitsTheVectorEventsAndViewData() external {
        string memory j = LibEtnaVectors.load();
        string memory list = ".fallback_keys.accepted[1].";
        assertEq(LibEtnaVectors.stringAt(j, string.concat(list, "name")), "two_keys");

        vm.recordLogs();
        _call(LibEtnaVectors.bytesAt(j, ".governance_abi.set_fallback_keys.calldata"));
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 1, "one fallback key event");
        assertEq(logs[0].emitter, inboxProxy, "emitter");
        assertEq(logs[0].topics.length, 2, "topics");
        assertEq(
            logs[0].topics[0], LibEtnaVectors.bytes32At(j, string.concat(list, "event.topic0"))
        );
        assertEq(
            logs[0].topics[1], LibEtnaVectors.bytes32At(j, string.concat(list, "event.topic1"))
        );
        assertEq(logs[0].data, LibEtnaVectors.bytesAt(j, string.concat(list, "event.data")));
        _assertViewResult(j, "get_fallback_keys", 0, "two_keys");
        _assertViewResult(j, "fallback_keys_hash", 0, "two_keys");

        vm.recordLogs();
        _call(LibEtnaVectors.bytesAt(j, ".governance_abi.set_min_total_stake.calldata"));
        logs = vm.getRecordedLogs();
        assertEq(logs.length, 1, "one minTotalStake event");
        _assertEvent(j, ".governance_events.min_total_stake_updated.", logs[0], "minTotalStake");
        _assertViewResult(j, "min_total_stake", 0, "fallback_only");

        IEtnaInbox(inboxProxy).setMinTotalStake(0);
        _assertViewResult(j, "min_total_stake", 1, "zero");
    }

    // ---------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------

    /// @dev The family at `_family` has `_inbox` entries labelled `inbox`, `_unzen` labelled
    /// `unzen_inbox`, and every other entry labelled `staking`.
    function _assertLabels(
        string memory _j,
        string memory _family,
        uint256 _inbox,
        uint256 _unzen
    )
        private
        pure
    {
        uint256 inboxCount = LibEtnaVectors.countWithContract(_j, _family, "inbox");
        uint256 unzenCount = LibEtnaVectors.countWithContract(_j, _family, "unzen_inbox");
        uint256 stakingCount = LibEtnaVectors.countWithContract(_j, _family, "staking");
        assertEq(inboxCount, _inbox, string.concat(_family, ": inbox entries"));
        assertEq(unzenCount, _unzen, string.concat(_family, ": unzen_inbox entries"));
        assertEq(
            inboxCount + unzenCount + stakingCount,
            LibEtnaVectors.entryCount(_j, _family),
            string.concat(_family, ": every entry names a known contract")
        );
    }

    /// @dev The call entry at `_p` has label `_contract`, its signature hashes to its selector,
    /// which is Solidity's `_selector`, and its calldata is `_calldata`.
    function _assertCall(
        string memory _j,
        string memory _p,
        string memory _contract,
        bytes4 _selector,
        bytes memory _calldata
    )
        private
        pure
    {
        assertEq(LibEtnaVectors.stringAt(_j, string.concat(_p, ".contract")), _contract, _p);
        bytes memory selector = LibEtnaVectors.bytesAt(_j, string.concat(_p, ".selector"));
        assertEq(selector, abi.encodePacked(_selector), _p);
        assertEq(
            bytes4(keccak256(bytes(LibEtnaVectors.stringAt(_j, string.concat(_p, ".signature"))))),
            _selector,
            _p
        );
        assertEq(LibEtnaVectors.bytesAt(_j, string.concat(_p, ".calldata")), _calldata, _p);
    }

    /// @dev The no-argument view `view_abi.<_name>` matches `_selector` and is called with the
    /// selector alone.
    function _assertView(
        string memory _j,
        string memory _name,
        string memory _contract,
        bytes4 _selector
    )
        private
        pure
    {
        _assertCall(
            _j,
            string.concat(".view_abi.", _name),
            _contract,
            _selector,
            abi.encodePacked(_selector)
        );
    }

    /// @dev The Inbox view `view_abi.<_name>` returns the data of its result `_index`, named
    /// `_result`.
    function _assertViewResult(
        string memory _j,
        string memory _name,
        uint256 _index,
        string memory _result
    )
        private
        view
    {
        string memory v = string.concat(".view_abi.", _name, ".");
        string memory r = string.concat(v, "results[", vm.toString(_index), "].");
        assertEq(LibEtnaVectors.stringAt(_j, string.concat(r, "name")), _result, _name);
        (bool ok, bytes memory data) =
            inboxProxy.staticcall(LibEtnaVectors.bytesAt(_j, string.concat(v, "calldata")));
        assertTrue(ok, _name);
        assertEq(data, LibEtnaVectors.bytesAt(_j, string.concat(r, "data")), _name);
    }

    /// @dev The log `_log` is the `governance_events` entry at `_e`: an Inbox event whose
    /// signature hashes to its topic0, with its indexed topics and data.
    function _assertEvent(
        string memory _j,
        string memory _e,
        Vm.Log memory _log,
        string memory _name
    )
        private
        view
    {
        assertEq(LibEtnaVectors.stringAt(_j, string.concat(_e, "contract")), "inbox", _name);
        bytes32 topic0 = LibEtnaVectors.bytes32At(_j, string.concat(_e, "topic0"));
        assertEq(
            keccak256(bytes(LibEtnaVectors.stringAt(_j, string.concat(_e, "signature")))),
            topic0,
            _name
        );
        assertEq(_log.topics[0], topic0, _name);
        uint256 indexedCount = LibEtnaVectors.lengthAt(_j, string.concat(_e, "indexed_topics"));
        assertEq(_log.topics.length, indexedCount + 1, _name);
        for (uint256 t; t < indexedCount; ++t) {
            assertEq(
                _log.topics[t + 1],
                LibEtnaVectors.bytes32At(
                    _j, string.concat(_e, "indexed_topics[", vm.toString(t), "]")
                ),
                _name
            );
        }
        assertEq(_log.data, LibEtnaVectors.bytesAt(_j, string.concat(_e, "data")), _name);
    }

    /// @dev Sends `_calldata` to the Inbox proxy as its owner and requires success.
    function _call(bytes memory _calldata) private {
        (bool ok, bytes memory reason) = inboxProxy.call(_calldata);
        assertTrue(ok, string(reason));
    }

    /// @dev The forced inclusion indices the vector recovery clears, strictly increasing.
    function _fiToClear() private pure returns (uint256[] memory list_) {
        list_ = new uint256[](2);
        (list_[0], list_[1]) = (3, 5);
    }

    /// @dev The fallback key list [K1, K2], ascending because both prefixes are 0x02 and K1's X is
    /// smaller.
    function _twoKeys() private pure returns (IEtnaInbox.FallbackKey[] memory keys_) {
        keys_ = new IEtnaInbox.FallbackKey[](2);
        keys_[0] = IEtnaInbox.FallbackKey({ ckPrefix: K1_PREFIX, ckX: K1_X });
        keys_[1] = IEtnaInbox.FallbackKey({ ckPrefix: 2, ckX: _K2_X });
    }
}
