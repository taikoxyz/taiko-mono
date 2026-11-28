// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EtnaInboxLockHarness } from "./EtnaInboxLockHarness.sol";
import { EtnaInboxTestBase } from "./EtnaInboxTestBase.sol";
import { Vm } from "forge-std/src/Vm.sol";
import { IEtnaInbox } from "src/layer1/etna/iface/IEtnaInbox.sol";
import { EtnaInbox } from "src/layer1/etna/impl/EtnaInbox.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";
import { LibEtnaKeys } from "src/shared/etna/LibEtnaKeys.sol";

/// @title EtnaInboxFallbackKeysTest
/// @notice The Inbox's DAO fallback key set and `minTotalStake` (spec 4.3, appendix A and B):
/// the two owner setters, their checks and events, the values `init` writes, and the fallback key
/// hash that the start write and every recovery copy into the origin record.
/// @dev `setUp` initializes a new network with `_defaultInitParams()`: [K1] and
/// `MIN_TOTAL_STAKE`. K_i is the compressed key of private key i.
contract EtnaInboxFallbackKeysTest is EtnaInboxTestBase {
    /// @dev keccak256("FallbackKeysUpdated(bytes32,(uint8,bytes32)[])").
    bytes32 private constant _FALLBACK_KEYS_UPDATED =
        0xad67b35e197f2041d061711ea23ef099f669424769b341298aaa52161dd9f88c;

    /// @dev keccak256("MinTotalStakeUpdated(uint256)").
    bytes32 private constant _MIN_TOTAL_STAKE_UPDATED =
        0xfd570c3cd5a2dd2e25a4647876d87fd36c533b77efb87ca66499f6cec64a25a1;

    /// @dev keccak256("Recovered(uint48,uint256,uint256,uint256,bytes32,uint256[])").
    bytes32 private constant _RECOVERED =
        0x2fa5000c19d2065a9cdcfe817f524045106390f8c8e86dd3621fb190e273b16a;

    /// @dev The fallback key hashes the specification lists: [K1], [K1, K2] and [K3, K9].
    bytes32 private constant _HASH_K1 =
        0x9dd1f7298a08cbe8d9579af09f0c713fc35137e6c534a74f8c439b63252f046f;
    bytes32 private constant _HASH_K1_K2 =
        0x2bc20cdc8e87ed785fc8f8012165afba944fd223ecf8973e165e41f4cddf0cea;
    bytes32 private constant _HASH_K3_K9 =
        0x5890fcdf8ee020d53fbf91c780a078701c0cecd248bbf4322f5feccf57bc333b;

    /// @dev keccak256(abi.encode(0, 290)): the first word of generation 0's origin record.
    bytes32 private constant _ORIGIN_0_BASE =
        0x67c2238b85f1221355128cce4fe559243be9c53682cf7b4c8b4cb08961267650;

    /// @dev The secp256k1 field prime, an X that is never below p.
    uint256 private constant _P =
        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F;

    /// @dev The smallest X of at least 1 with no curve point: x^3 + 7 has no square root mod p.
    uint256 private constant _OFF_CURVE_X = 5;

    /// @dev The EIP-170 contract size limit in bytes.
    uint256 private constant _EIP170_LIMIT = 24_576;

    // ---------------------------------------------------------------
    // The key values the tests rely on
    // ---------------------------------------------------------------

    /// @dev K1, K2, K3 and K9 are the specification's points, and K9 is the only odd-Y one.
    function test_keys_MatchTheSpecPoints() external {
        _assertKey(_key(1), 0x02, K1_X);
        _assertKey(
            _key(2), 0x02, 0xc6047f9441ed7d6d3045406e95c07cd85c778e4b8cef3ca7abac09b95c709ee5
        );
        _assertKey(
            _key(3), 0x02, 0xf9308a019258c31049344f85f89d5229b531c845836f99b08601f113bce036f9
        );
        _assertKey(
            _key(9), 0x03, 0xacd484e2f0c7f65309ad178a9f559abde09796974c57e714c35f110dfc27ccbe
        );
        assertEq(_fallbackKeysHash(_defaultFallbackKeys()), _HASH_K1, "the default list is [K1]");
        assertEq(DEFAULT_FALLBACK_KEYS_HASH, _HASH_K1, "the base's default hash");
    }

    // ---------------------------------------------------------------
    // setFallbackKeys
    // ---------------------------------------------------------------

    /// @dev The owner's list is stored as given: its length in slot 275, its hash in slot 278 and
    /// `FallbackKeysUpdated(hash, keys)` with the list as data.
    function test_setFallbackKeys_StoresListHashAndEmits() external {
        IEtnaInbox.FallbackKey[] memory keys = _list(1, 2, 3);
        bytes32 hash = keccak256(abi.encode(bytes32("ETNA_FALLBACK_KEYS_V1"), keys));

        vm.recordLogs();
        _inbox().setFallbackKeys(keys);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(vm.load(inboxProxy, bytes32(uint256(278))), hash, "slot 278");
        assertEq(_inbox().fallbackKeysHash(), hash, "fallbackKeysHash()");
        _assertStoredList(keys);
        assertEq(logs.length, 1, "one log");
        assertEq(logs[0].emitter, inboxProxy, "emitted by the Inbox");
        assertEq(logs[0].topics.length, 2, "two topics");
        assertEq(logs[0].topics[0], _FALLBACK_KEYS_UPDATED, "topic0");
        assertEq(logs[0].topics[1], hash, "topic1 is the hash");
        assertEq(logs[0].data, abi.encode(keys), "data is the list");
        assertEq(vm.load(inboxProxy, bytes32(uint256(275))), bytes32(uint256(3)), "slot 275");
    }

    /// @dev The hashes of [K1] and [K1, K2] are the specification's literals.
    function test_fallbackKeysHash_MatchesTheSpecLiterals() external {
        _inbox().setFallbackKeys(_list(1));
        assertEq(_inbox().fallbackKeysHash(), _HASH_K1, "[K1]");
        _inbox().setFallbackKeys(_list(1, 2));
        assertEq(_inbox().fallbackKeysHash(), _HASH_K1_K2, "[K1, K2]");
        assertEq(_fallbackKeysHash(_list(1, 2)), _HASH_K1_K2, "the test helper agrees");
    }

    /// @dev The order is that of the 33-byte value `ckPrefix ‖ ckX`, prefix first: K3 (prefix
    /// 0x02) precedes K9 (prefix 0x03) although K9's X is smaller.
    function test_setFallbackKeys_OrdersByPrefixThenX() external {
        IEtnaInbox.FallbackKey[] memory keys = _list(3, 9);
        assertLt(uint256(keys[1].ckX), uint256(keys[0].ckX), "K9's X is below K3's");
        _inbox().setFallbackKeys(keys);
        assertEq(_inbox().fallbackKeysHash(), _HASH_K3_K9, "[K3, K9]");
        _assertStoredList(keys);
    }

    /// @dev [K9, K3] is ascending by X alone but not by the 33-byte value.
    function test_setFallbackKeys_RevertWhen_OrderedByXAlone() external {
        _expectSetFallbackKeysRevert(_list(9, 3), IEtnaInbox.InvalidFallbackKeys.selector);
    }

    /// @dev A list needs 1 to 128 keys: the empty list and 129 sorted keys revert.
    function test_setFallbackKeys_RevertWhen_CountOutOfRange() external {
        _expectSetFallbackKeysRevert(
            new IEtnaInbox.FallbackKey[](0), IEtnaInbox.InvalidFallbackKeys.selector
        );
        _expectSetFallbackKeysRevert(_sortedKeys(129), IEtnaInbox.InvalidFallbackKeys.selector);
    }

    /// @dev 128 sorted keys, the most a list holds, are stored, and the event data is the offset,
    /// the length and two words per key: 258 words.
    function test_setFallbackKeys_Accepts128Keys() external {
        IEtnaInbox.FallbackKey[] memory keys = _sortedKeys(128);

        vm.recordLogs();
        _inbox().setFallbackKeys(keys);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(logs.length, 1, "one log");
        assertEq(logs[0].topics[0], _FALLBACK_KEYS_UPDATED, "topic0");
        assertEq(logs[0].topics[1], _fallbackKeysHash(keys), "topic1");
        assertEq(logs[0].data.length, 258 * 32, "258 words");
        assertEq(logs[0].data, abi.encode(keys), "data is the list");
        assertEq(_inbox().fallbackKeysHash(), _fallbackKeysHash(keys), "hash");
        _assertStoredList(keys);
    }

    /// @dev A key that repeats or descends reverts.
    function test_setFallbackKeys_RevertWhen_NotStrictlyAscending() external {
        _expectSetFallbackKeysRevert(_list(2, 1), IEtnaInbox.InvalidFallbackKeys.selector);
        _expectSetFallbackKeysRevert(_list(1, 1), IEtnaInbox.InvalidFallbackKeys.selector);
        // Order is checked at every position, not only the first.
        _expectSetFallbackKeysRevert(_list(1, 3, 2), IEtnaInbox.InvalidFallbackKeys.selector);
    }

    /// @dev A key with prefix 0x04, an X of p or an X with no curve point reverts with the key
    /// library's error, also behind a valid key, and slot 278 keeps its value.
    function test_setFallbackKeys_RevertWhen_KeyInvalid() external {
        IEtnaInbox.FallbackKey[3] memory invalid = [
            IEtnaInbox.FallbackKey({ ckPrefix: 0x04, ckX: K1_X }),
            IEtnaInbox.FallbackKey({ ckPrefix: 0x02, ckX: bytes32(_P) }),
            IEtnaInbox.FallbackKey({ ckPrefix: 0x02, ckX: bytes32(_OFF_CURVE_X) })
        ];
        for (uint256 i; i < invalid.length; ++i) {
            IEtnaInbox.FallbackKey[] memory keys = new IEtnaInbox.FallbackKey[](1);
            keys[0] = invalid[i];
            _expectSetFallbackKeysRevert(keys, LibEtnaKeys.InvalidPublicKey.selector);

            keys = new IEtnaInbox.FallbackKey[](2);
            (keys[0], keys[1]) = (_key(1), invalid[i]);
            _expectSetFallbackKeysRevert(keys, LibEtnaKeys.InvalidPublicKey.selector);
        }
        assertEq(vm.load(inboxProxy, bytes32(uint256(278))), _HASH_K1, "slot 278 unchanged");
    }

    // ---------------------------------------------------------------
    // setMinTotalStake
    // ---------------------------------------------------------------

    /// @dev Any uint256 is stored, the largest included, and announced with one topic and the
    /// value as the one data word.
    function test_setMinTotalStake_StoresAnyValueAndEmits() external {
        _assertSetMinTotalStake(type(uint256).max);
        _assertSetMinTotalStake(0);
        _assertSetMinTotalStake(MIN_TOTAL_STAKE + 1);
    }

    // ---------------------------------------------------------------
    // Both setters
    // ---------------------------------------------------------------

    function test_setters_RevertWhen_NotOwner() external {
        IEtnaInbox.FallbackKey[] memory keys = _list(2);
        vm.prank(Bob);
        vm.expectRevert("Ownable: caller is not the owner");
        _inbox().setFallbackKeys(keys);
        vm.prank(Bob);
        vm.expectRevert("Ownable: caller is not the owner");
        _inbox().setMinTotalStake(1);
        _assertDefaultsKept();
    }

    /// @dev The owner of a proxy upgraded from the bootstrap but not initialized cannot set
    /// either value.
    function test_setters_RevertWhen_NotInitialized() external {
        _deployFreshInbox(false);
        EssentialContract(inboxProxy).upgradeTo(address(inboxImpl));
        IEtnaInbox.FallbackKey[] memory keys = _list(2);
        vm.expectRevert(IEtnaInbox.NotInitialized.selector);
        _inbox().setFallbackKeys(keys);
        vm.expectRevert(IEtnaInbox.NotInitialized.selector);
        _inbox().setMinTotalStake(1);
        assertEq(vm.load(inboxProxy, bytes32(FALLBACK_KEYS_SLOT)), 0, "slot 275");
        assertEq(vm.load(inboxProxy, bytes32(FALLBACK_KEYS_HASH_SLOT)), 0, "slot 278");
        assertEq(vm.load(inboxProxy, bytes32(MIN_TOTAL_STAKE_SLOT)), 0, "slot 279");
    }

    /// @dev Both setters take the Inbox lock that `land` and `recover` share.
    function test_setters_RevertWhen_SharedInboxLockHeld() external {
        _inbox().upgradeTo(address(new EtnaInboxLockHarness(_defaultConfig())));
        _inbox().transferOwnership(inboxProxy);
        vm.prank(inboxProxy);
        _inbox().acceptOwnership();

        bytes[2] memory calls = [
            abi.encodeCall(IEtnaInbox.setFallbackKeys, (_list(2))),
            abi.encodeCall(IEtnaInbox.setMinTotalStake, (1))
        ];
        for (uint256 i; i < calls.length; ++i) {
            (bool ok, bytes memory ret) =
                EtnaInboxLockHarness(inboxProxy).lockedCall(inboxProxy, calls[i]);
            assertFalse(ok, "reentrant setter");
            assertEq(ret, abi.encodeWithSelector(EssentialContract.REENTRANT_CALL.selector));
        }
        _assertDefaultsKept();
    }

    /// @dev Pausing the Inbox does not stop either setter.
    function test_setters_IgnorePause() external {
        EssentialContract(inboxProxy).pause();
        assertTrue(EssentialContract(inboxProxy).paused(), "paused");
        _inbox().setFallbackKeys(_list(2));
        _inbox().setMinTotalStake(7);
        assertEq(_inbox().fallbackKeysHash(), _fallbackKeysHash(_list(2)), "keys set");
        assertEq(_inbox().minTotalStake(), 7, "minTotalStake set");
    }

    /// @dev Neither setter accepts ETH: with 1 wei each reverts without data, and the same calls
    /// without ETH then succeed.
    function test_setters_RevertWhen_EtherSent() external {
        vm.deal(address(this), 2);
        bytes[2] memory calls = [
            abi.encodeCall(IEtnaInbox.setFallbackKeys, (_list(2))),
            abi.encodeCall(IEtnaInbox.setMinTotalStake, (1))
        ];
        for (uint256 i; i < calls.length; ++i) {
            (bool ok, bytes memory ret) = inboxProxy.call{ value: 1 }(calls[i]);
            assertFalse(ok, "payable setter");
            assertEq(ret.length, 0, "the nonpayable check");
        }
        assertEq(inboxProxy.balance, 0, "no ETH kept");
        _assertDefaultsKept();

        for (uint256 i; i < calls.length; ++i) {
            (bool ok,) = inboxProxy.call(calls[i]);
            assertTrue(ok, "the same call without ETH");
        }
        assertEq(_inbox().minTotalStake(), 1, "set without ETH");
    }

    /// @dev Each setter takes only its value, no generation, and its write is in place when the
    /// call returns, in the same L1 block; neither touches the generation or the rules schedule.
    function test_setters_ApplyAtOnceWithNoGeneration() external {
        assertEq(IEtnaInbox.setFallbackKeys.selector, bytes4(0xc358c1bb), "setFallbackKeys");
        assertEq(IEtnaInbox.setMinTotalStake.selector, bytes4(0x166d62e7), "setMinTotalStake");
        assertEq(IEtnaInbox.getFallbackKeys.selector, bytes4(0x9af4c02a), "getFallbackKeys");
        assertEq(IEtnaInbox.fallbackKeysHash.selector, bytes4(0xfe6dd650), "fallbackKeysHash");
        assertEq(IEtnaInbox.minTotalStake.selector, bytes4(0x5d281ec7), "minTotalStake");

        uint256 l1Block = block.number;
        bytes32 schedule = vm.load(inboxProxy, bytes32(RULES_SCHEDULE_SLOT));
        _inbox().setFallbackKeys(_list(2));
        assertEq(
            vm.load(inboxProxy, bytes32(FALLBACK_KEYS_HASH_SLOT)),
            _fallbackKeysHash(_list(2)),
            "slot 278 written by the call"
        );
        _inbox().setMinTotalStake(7);
        assertEq(
            vm.load(inboxProxy, bytes32(MIN_TOTAL_STAKE_SLOT)),
            bytes32(uint256(7)),
            "slot 279 written by the call"
        );
        assertEq(block.number, l1Block, "same L1 block");
        assertEq(_inbox().recoveryGeneration(), 0, "generation unchanged");
        assertEq(vm.load(inboxProxy, bytes32(RULES_SCHEDULE_SLOT)), schedule, "rules unchanged");
    }

    // ---------------------------------------------------------------
    // init
    // ---------------------------------------------------------------

    /// @dev `init` checks the list as `setFallbackKeys` does.
    function test_init_RevertWhen_FallbackKeysInvalid() external {
        _deployFreshInbox(false);
        IEtnaInbox.InitParams memory params = _defaultInitParams();

        params.fallbackKeys = new IEtnaInbox.FallbackKey[](0);
        _expectInitRevert(params, abi.encodeWithSelector(IEtnaInbox.InvalidFallbackKeys.selector));
        params.fallbackKeys = _list(2, 1);
        _expectInitRevert(params, abi.encodeWithSelector(IEtnaInbox.InvalidFallbackKeys.selector));
        params.fallbackKeys = _defaultFallbackKeys();
        params.fallbackKeys[0].ckPrefix = 0x04;
        _expectInitRevert(params, abi.encodeWithSelector(LibEtnaKeys.InvalidPublicKey.selector));

        _upgradeAndInit(inboxImpl, _defaultInitParams());
        assertTrue(_inbox().isInitialized(), "the valid list initializes");
    }

    /// @dev On a new network `init` announces the list and the threshold with the setters'
    /// events, in the setters' order, before `EtnaInitialized` and the start write.
    function test_init_EmitsBothEventsInSetterOrder() external {
        _deployFreshInbox(false);
        IEtnaInbox.InitParams memory params = _defaultInitParams();

        vm.recordLogs();
        _upgradeAndInit(inboxImpl, params);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        bytes32[4] memory order = [
            _FALLBACK_KEYS_UPDATED,
            _MIN_TOTAL_STAKE_UPDATED,
            IEtnaInbox.EtnaInitialized.selector,
            IEtnaInbox.StartWritten.selector
        ];
        uint256 next;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter != inboxProxy) continue;
            bytes32 topic0 = logs[i].topics[0];
            bool tracked;
            for (uint256 j; j < order.length; ++j) {
                tracked = tracked || topic0 == order[j];
            }
            if (!tracked) continue;
            assertLt(next, order.length, "one event each");
            assertEq(topic0, order[next], "event order");
            if (next == 0) {
                assertEq(logs[i].topics[1], _HASH_K1, "FallbackKeysUpdated topic1");
                assertEq(logs[i].data, abi.encode(params.fallbackKeys), "FallbackKeysUpdated data");
            } else if (next == 1) {
                assertEq(logs[i].topics.length, 1, "MinTotalStakeUpdated has one topic");
                assertEq(logs[i].data, abi.encode(MIN_TOTAL_STAKE), "MinTotalStakeUpdated data");
            }
            ++next;
        }
        assertEq(next, order.length, "all four events");
        assertEq(vm.load(inboxProxy, bytes32(FALLBACK_KEYS_HASH_SLOT)), _HASH_K1, "slot 278");
        assertEq(
            vm.load(inboxProxy, bytes32(MIN_TOTAL_STAKE_SLOT)), bytes32(MIN_TOTAL_STAKE), "slot 279"
        );
    }

    /// @dev `init` stores a full list of 128 keys, and the start write records its hash.
    function test_init_Stores128Keys() external {
        _deployFreshInbox(false);
        IEtnaInbox.InitParams memory params = _defaultInitParams();
        params.fallbackKeys = _sortedKeys(128);
        _upgradeAndInit(inboxImpl, params);

        bytes32 hash = _fallbackKeysHash(params.fallbackKeys);
        assertEq(_inbox().fallbackKeysHash(), hash, "hash");
        _assertStoredList(params.fallbackKeys);
        assertEq(_inbox().origins(0).fallbackKeysHash, hash, "origins(0)");
    }

    // ---------------------------------------------------------------
    // The origin record's fourth word
    // ---------------------------------------------------------------

    /// @dev The start write copies slot 278 into the fourth word of generation 0's origin record.
    function test_writeStart_RecordsSlot278InOriginWord4() external view {
        assertEq(keccak256(abi.encode(uint256(0), uint256(290))), _ORIGIN_0_BASE, "origins(0) base");
        bytes32 hash = _inbox().fallbackKeysHash();
        assertEq(hash, _HASH_K1, "slot 278");
        assertEq(_inbox().origins(0).fallbackKeysHash, hash, "origins(0).fallbackKeysHash");
        assertEq(vm.load(inboxProxy, bytes32(uint256(_ORIGIN_0_BASE) + 3)), hash, "fourth word");
    }

    /// @dev A recovery copies the hash in slot 278 at its execution into the new origin record
    /// and announces it in `Recovered`; generation 0's record keeps the earlier hash.
    function test_recover_RecordsTheFallbackKeysHashAtExecution() external {
        bytes32 hash = _recoverAfterSettingK2();

        assertEq(hash, _fallbackKeysHash(_list(2)), "hash of [K2]");
        IEtnaInbox.Origin memory origin = _inbox().origins(1);
        assertEq(origin.startHeight, 0, "origins(1).startHeight");
        assertEq(origin.l1BlockNumber, block.number, "origins(1).l1BlockNumber");
        assertEq(origin.l1Timestamp, block.timestamp, "origins(1).l1Timestamp");
        assertEq(origin.fallbackKeysHash, hash, "origins(1).fallbackKeysHash");
        assertEq(_originWord(1, 3), hash, "origins(1) fourth word");
        assertEq(_inbox().origins(0).fallbackKeysHash, _HASH_K1, "origins(0) keeps [K1]");
    }

    /// @dev A later key change leaves every written origin record as it was.
    function test_origin_UnchangedByLaterSetFallbackKeys() external {
        _recoverAfterSettingK2();
        bytes32[8] memory before;
        for (uint256 w; w < 4; ++w) {
            before[w] = _originWord(0, w);
            before[4 + w] = _originWord(1, w);
        }

        _inbox().setFallbackKeys(_list(3));

        assertEq(_inbox().fallbackKeysHash(), _fallbackKeysHash(_list(3)), "slot 278 moved on");
        for (uint256 w; w < 4; ++w) {
            assertEq(_originWord(0, w), before[w], "origins(0) unchanged");
            assertEq(_originWord(1, w), before[4 + w], "origins(1) unchanged");
        }
        assertEq(_inbox().origins(1).fallbackKeysHash, _fallbackKeysHash(_list(2)), "[K2] kept");
    }

    // ---------------------------------------------------------------
    // Code size
    // ---------------------------------------------------------------

    /// @dev The implementation stays deployable under EIP-170.
    function test_size_EtnaInboxBelowEip170() external {
        uint256 size = address(new EtnaInbox(_defaultConfig())).code.length;
        emit log_named_uint("EtnaInbox runtime bytes", size);
        assertLe(size, _EIP170_LIMIT, "EIP-170");
    }

    // ---------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------

    /// @dev The owner sets [K2] and then recovers at c = 0 with an empty list, expecting
    /// `Recovered` to carry the hash of [K2], which it returns.
    function _recoverAfterSettingK2() private returns (bytes32 hash_) {
        _inbox().setFallbackKeys(_list(2));
        hash_ = _inbox().fallbackKeysHash();
        uint256[] memory none = new uint256[](0);

        vm.expectEmit(inboxProxy);
        emit IEtnaInbox.Recovered(1, 0, block.number, block.timestamp, hash_, none);
        vm.recordLogs();
        _inbox().recover(0, 0, 0, type(uint256).max, none, 0);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs[0].topics[0], _RECOVERED, "Recovered topic0");
    }

    /// @dev Expects the owner's `setFallbackKeys(_keys)` to revert with `_selector`, leaving
    /// slots 275 and 278 and the stored list as they were.
    function _expectSetFallbackKeysRevert(
        IEtnaInbox.FallbackKey[] memory _keys,
        bytes4 _selector
    )
        private
    {
        bytes32 length = vm.load(inboxProxy, bytes32(FALLBACK_KEYS_SLOT));
        bytes32 hash = vm.load(inboxProxy, bytes32(FALLBACK_KEYS_HASH_SLOT));
        IEtnaInbox.FallbackKey[] memory stored = _inbox().getFallbackKeys();
        vm.expectRevert(_selector);
        _inbox().setFallbackKeys(_keys);
        assertEq(vm.load(inboxProxy, bytes32(FALLBACK_KEYS_SLOT)), length, "slot 275 unchanged");
        assertEq(vm.load(inboxProxy, bytes32(FALLBACK_KEYS_HASH_SLOT)), hash, "slot 278 unchanged");
        assertEq(abi.encode(_inbox().getFallbackKeys()), abi.encode(stored), "list unchanged");
    }

    /// @dev Expects the owner's upgrade to `inboxImpl` with `init(_params)` to revert with
    /// `_revertData`, leaving the proxy uninitialized.
    function _expectInitRevert(
        IEtnaInbox.InitParams memory _params,
        bytes memory _revertData
    )
        private
    {
        vm.expectRevert(_revertData);
        _upgradeAndInit(inboxImpl, _params);
        assertFalse(_inbox().isInitialized(), "not initialized");
        assertEq(vm.load(inboxProxy, bytes32(FALLBACK_KEYS_HASH_SLOT)), 0, "slot 278");
    }

    /// @dev The owner sets `minTotalStake` to `_value`; checks slot 279, the view and the one
    /// `MinTotalStakeUpdated` log.
    function _assertSetMinTotalStake(uint256 _value) private {
        vm.recordLogs();
        _inbox().setMinTotalStake(_value);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(vm.load(inboxProxy, bytes32(uint256(279))), bytes32(_value), "slot 279");
        assertEq(_inbox().minTotalStake(), _value, "minTotalStake()");
        assertEq(logs.length, 1, "one log");
        assertEq(logs[0].emitter, inboxProxy, "emitted by the Inbox");
        assertEq(logs[0].topics.length, 1, "exactly one topic");
        assertEq(logs[0].topics[0], _MIN_TOTAL_STAKE_UPDATED, "topic0");
        assertEq(logs[0].data, abi.encodePacked(_value), "data is the value");
    }

    /// @dev Checks that `getFallbackKeys()`, slot 275 and the list's storage words, two per key
    /// from keccak256(275), hold `_keys`.
    function _assertStoredList(IEtnaInbox.FallbackKey[] memory _keys) private view {
        IEtnaInbox.FallbackKey[] memory stored = _inbox().getFallbackKeys();
        assertEq(stored.length, _keys.length, "getFallbackKeys() length");
        assertEq(
            uint256(vm.load(inboxProxy, bytes32(FALLBACK_KEYS_SLOT))), _keys.length, "slot 275"
        );
        uint256 base = uint256(keccak256(abi.encode(FALLBACK_KEYS_SLOT)));
        for (uint256 i; i < _keys.length; ++i) {
            assertEq(stored[i].ckPrefix, _keys[i].ckPrefix, "getFallbackKeys() prefix");
            assertEq(stored[i].ckX, _keys[i].ckX, "getFallbackKeys() X");
            assertEq(
                uint256(vm.load(inboxProxy, bytes32(base + 2 * i))),
                _keys[i].ckPrefix,
                "stored prefix word"
            );
            assertEq(vm.load(inboxProxy, bytes32(base + 2 * i + 1)), _keys[i].ckX, "stored X");
        }
    }

    /// @dev The values `setUp` initialized stay: [K1] and `MIN_TOTAL_STAKE`.
    function _assertDefaultsKept() private view {
        assertEq(_inbox().fallbackKeysHash(), _HASH_K1, "fallback keys kept");
        _assertStoredList(_defaultFallbackKeys());
        assertEq(_inbox().minTotalStake(), MIN_TOTAL_STAKE, "minTotalStake kept");
    }

    function _assertKey(
        IEtnaInbox.FallbackKey memory _actual,
        uint8 _prefix,
        bytes32 _x
    )
        private
        pure
    {
        assertEq(_actual.ckPrefix, _prefix, "prefix");
        assertEq(_actual.ckX, _x, "X");
    }

    /// @dev Word `_word` of `origins[_generation]` (slot 290).
    function _originWord(uint256 _generation, uint256 _word) private view returns (bytes32) {
        return vm.load(
            inboxProxy, bytes32(uint256(keccak256(abi.encode(_generation, ORIGINS_SLOT))) + _word)
        );
    }

    function _key(uint256 _pk) private returns (IEtnaInbox.FallbackKey memory) {
        return _list(_pk)[0];
    }

    function _list(uint256 _a) private returns (IEtnaInbox.FallbackKey[] memory) {
        uint256[] memory pks = new uint256[](1);
        pks[0] = _a;
        return _keys(pks);
    }

    function _list(uint256 _a, uint256 _b) private returns (IEtnaInbox.FallbackKey[] memory) {
        uint256[] memory pks = new uint256[](2);
        (pks[0], pks[1]) = (_a, _b);
        return _keys(pks);
    }

    function _list(
        uint256 _a,
        uint256 _b,
        uint256 _c
    )
        private
        returns (IEtnaInbox.FallbackKey[] memory)
    {
        uint256[] memory pks = new uint256[](3);
        (pks[0], pks[1], pks[2]) = (_a, _b, _c);
        return _keys(pks);
    }

    function _inbox() private view returns (EtnaInbox) {
        return EtnaInbox(inboxProxy);
    }
}
