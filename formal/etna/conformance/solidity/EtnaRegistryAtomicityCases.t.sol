// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Vm, VmSafe } from "forge-std/src/Vm.sol";
import { IEtnaStakingRegistry } from "src/layer1/etna/iface/IEtnaStakingRegistry.sol";
import { EtnaRegistryCasesBase } from "./EtnaRegistryCasesBase.sol";
import { PublicReplayToken } from "./EtnaRegistryPublicReplay.t.sol";

/// @notice Late token failures and identical retries through the actual Registry proxy.
contract EtnaRegistryAtomicityCasesTest is EtnaRegistryCasesBase {
    // All positions are zero-based offsets in the VM recorder's ordered arrays.
    struct TraceFrame {
        uint256 index;
        VmSafe.AccountAccessKind kind;
        address account;
        address accessor;
        uint64 depth;
        bool reverted;
    }

    struct TraceWrite {
        TraceFrame frame;
        uint256 index;
        address account;
        bytes32 slot;
        bytes32 previousValue;
        bytes32 newValue;
        bool reverted;
    }

    bytes32 private constant RECEIPT_SCHEMA = "etna-registry-atomicity-2";

    struct Observation {
        bytes32 name;
        uint256 height;
        uint48 snapshot;
        address actor;
        address target;
        bool ok;
        bytes32 beforeState;
        bytes32 afterState;
        uint256 logCount;
        address tokenTarget;
        bool tokenReverted;
        uint256[3] allowanceWrite;
    }

    bytes private _journal;

    event AtomicityLogControl(uint256 indexed marker);

    function test_register_allowance_rollback_and_retry() external {
        _setupRegistry(0);
        inbox.setSnapshot(7);
        _fund(OWNER_A, 4, 4);
        _fund(OWNER_B, 4, 3);
        PublicPoP memory first = _publicPoP(0);
        PublicPoP memory next = _publicPoP(3);
        require(_register(first, 4) == 0, "N04 register: initial bond ID");
        _calibrateRevertedLog();

        VM.roll(11);
        bytes memory callData = abi.encodeCall(IEtnaStakingRegistry.register, (next.key, 4, next.signature));
        bytes32 firstRoot = _leaf(0, _entry(first, 4, 12));
        bytes32 nextRoot = _leaf(1, _entry(next, 4, 13));
        bytes32 root = keccak256(abi.encodePacked(firstRoot, nextRoot));
        bytes32 checkpoint = _checkpointEvent(1, 11, 2, root);
        bytes32[] memory events = new bytes32[](1);
        events[0] = checkpoint;
        _registryAction(
            "register_refusal", next.owner, callData, false,
            abi.encodeWithSignature("Error(string)", "token allowance"), events
        );

        (bool known,) = registry.bondForKey(next.signer);
        (bool occupied,) = registry.bondInSlot(1);
        require(
            !known && !occupied && registry.bondCount() == 1 && registry.checkpointCount() == 1,
            "N04 register: no failed identity, slot or checkpoint"
        );
        require(_balance(next.owner) == 4 && _allowance(next.owner) == 3, "N04 register: refusal funding");
        _externalAction(
            "approve_retry", next.owner, abi.encodeCall(PublicReplayToken.approve, (REGISTRY, 4)),
            abi.encode(true)
        );
        require(_balance(next.owner) == 4 && _allowance(next.owner) == 4, "N04 register: retry approval");

        events = new bytes32[](3);
        events[0] = checkpoint;
        events[1] = _transferEvent(next.owner, REGISTRY, 4);
        events[2] = _registeredEvent(next);
        _registryAction("register_retry", next.owner, callData, true, abi.encode(uint256(1)), events);
        _requireCheckpoint(0, 10, 1, firstRoot);
        _requireCheckpoint(1, 11, 2, root);
        require(_balance(REGISTRY) == 8 && _transfers() == 2, "N04 register: exact vault and transfer count");

        emit RegistryCaseReceipt(bytes.concat(RECEIPT_SCHEMA, _journal));
    }

    function test_topup_balance_rollback_and_retry() external {
        _setupRegistry(0);
        inbox.setSnapshot(9);
        _fund(OWNER_A, 4, 8);
        _fund(OWNER_B, 4, 4);
        PublicPoP memory first = _publicPoP(0);
        PublicPoP memory neighbor = _publicPoP(3);
        require(_register(first, 4) == 0 && _register(neighbor, 4) == 1, "N04 topUp: initial bond IDs");

        VM.roll(12);
        bytes memory callData = abi.encodeCall(IEtnaStakingRegistry.topUp, (0, 4));
        require(_balance(first.owner) == 0 && _allowance(first.owner) == 4, "N04 topUp: refusal funding");
        _registryAction(
            "topup_refusal", first.owner, callData, false,
            abi.encodeWithSignature("Error(string)", "token balance"), new bytes32[](0)
        );
        _requireTopUpState(first, neighbor, false);
        _externalAction("fund_retry", address(this), abi.encodeCall(PublicReplayToken.mint, (first.owner, 4)), "");
        require(_balance(first.owner) == 4 && _allowance(first.owner) == 4, "N04 topUp: retry funding");

        bytes32[] memory events = new bytes32[](2);
        events[0] = _transferEvent(first.owner, REGISTRY, 4);
        events[1] = _topUpEvent("TopUpDeposited(uint256,uint256,uint48)", abi.encode(uint256(4), uint48(14)));
        _registryAction("topup_retry", first.owner, callData, true, "", events);
        _requireTopUpState(first, neighbor, true);

        VM.roll(14);
        bytes32 neighborLeaf = _leaf(1, _entry(neighbor, 4, 12));
        bytes32 oldRoot = keccak256(abi.encodePacked(_leaf(0, _entry(first, 4, 12)), neighborLeaf));
        bytes32 nextRoot = keccak256(abi.encodePacked(_leaf(0, _entry(first, 8, 12)), neighborLeaf));
        events[0] = _checkpointEvent(1, 14, 2, nextRoot);
        events[1] = _topUpEvent("TopUpActivated(uint256,uint256)", abi.encode(uint256(4)));
        _registryAction(
            "activate_topup", REPORTER, abi.encodeCall(IEtnaStakingRegistry.activateTopUp, (0)), true, "", events
        );
        _requireCheckpoint(0, 10, 2, oldRoot);
        _requireCheckpoint(1, 14, 2, nextRoot);
        (uint256 pending, uint48 ready) = registry.topUpOf(0);
        require(pending == 0 && ready == 0, "N04 activation: consumed pending");
        require(_balance(REGISTRY) == 12 && _transfers() == 3, "N04 topUp: exact vault and transfer count");

        emit RegistryCaseReceipt(bytes.concat(RECEIPT_SCHEMA, _journal));
    }

    /// @notice Emit one trace entry then revert for the local recorder calibration.
    function atomicityRevertedLog() external {
        require(msg.sender == address(this), "N04 calibration: only self");
        emit AtomicityLogControl(1);
        revert("N04 calibration revert");
    }

    function _calibrateRevertedLog() private {
        VM.recordLogs();
        (bool ok, bytes memory result) = address(this).call(abi.encodeCall(this.atomicityRevertedLog, ()));
        Vm.Log[] memory logs = VM.getRecordedLogs();
        require(
            !ok && keccak256(result) == keccak256(abi.encodeWithSignature("Error(string)", "N04 calibration revert")),
            "N04 calibration: exact revert"
        );
        bytes32[] memory topics = new bytes32[](2);
        topics[0] = keccak256("AtomicityLogControl(uint256)");
        topics[1] = bytes32(uint256(1));
        bytes32[] memory expected = new bytes32[](1);
        expected[0] = _event(address(this), topics, "");
        _requireEvents(logs, expected);
    }

    function _registryAction(
        bytes32 _name,
        address _actor,
        bytes memory _call,
        bool _ok,
        bytes memory _return,
        bytes32[] memory _traceEvents
    )
        private
    {
        Observation memory obs = _observeBefore(_name, _actor);
        bytes32[4] memory slots;
        bytes32[4] memory beforeWords;
        if (_name == "topup_refusal") {
            uint256 pending = _mapSlot(TOP, 0);
            slots = [bytes32(pending), bytes32(pending + 1), bytes32(_mapSlot(R + 3, 4096)),
                bytes32(_mapSlot(R + 3, 2048))];
            beforeWords = _readRegistryWords(slots);
        }
        CallResult memory result = _callRegistry(_actor, _call);
        if (_name == "topup_refusal") {
            require(!result.ok, "N04 topup_refusal: expected token balance, got success");
        }
        bytes memory observedCall;
        (obs.target, observedCall) = _registryFrame(result, _actor, _call);
        bytes memory expectedTokenCall = "";
        if (_name != "activate_topup") {
            expectedTokenCall = abi.encodeCall(PublicReplayToken.transferFrom, (_actor, REGISTRY, 4));
        }
        bytes memory observedTokenCall = _observeTokenFrame(obs, result, expectedTokenCall);
        _observeAfter(obs, result);
        if (_ok) {
            require(result.ok && keccak256(result.data) == keccak256(_return), "N04 action: exact success bytes");
            _requireEvents(result.logs, _traceEvents);
        } else {
            _requireRefusal(result, _return, obs.beforeState, obs.afterState, _traceEvents);
        }
        _append(obs, observedCall, result.data, observedTokenCall);
        if (_name == "topup_refusal") {
            _appendTopUpWitness(result.accesses, slots, beforeWords);
        }
    }

    /// @dev Raw reads run outside the action recorder.
    function _readRegistryWords(bytes32[4] memory _slots) private view returns (bytes32[4] memory words) {
        for (uint256 i; i < _slots.length; ++i) {
            words[i] = _raw(uint256(_slots[i]));
        }
    }

    /// @dev Capture all writes to the selected slot keys across the ordered action.
    /// The collector checks the storage account, frame context, order and values.
    function _appendTopUpWitness(
        Vm.AccountAccess[] memory _accesses,
        bytes32[4] memory _slots,
        bytes32[4] memory _beforeWords
    )
        private
    {
        TraceFrame memory delegateFrame;
        TraceFrame memory tokenFrame;
        bytes memory writes;
        for (uint256 i; i < _accesses.length; ++i) {
            Vm.AccountAccess memory access = _accesses[i];
            TraceFrame memory frame =
                TraceFrame(i, access.kind, access.account, access.accessor, access.depth, access.reverted);
            // The earlier exact frame checks bind these two boundaries to the attempted calls.
            if (access.kind == VmSafe.AccountAccessKind.DelegateCall && access.account == implementation) {
                delegateFrame = frame;
            }
            if (access.kind == VmSafe.AccountAccessKind.Call && access.account == address(token)) {
                tokenFrame = frame;
            }
            for (uint256 j; j < access.storageAccesses.length; ++j) {
                Vm.StorageAccess memory store = access.storageAccesses[j];
                bytes32 slot = store.slot;
                if (!store.isWrite || (slot != _slots[0] && slot != _slots[1] && slot != _slots[2] && slot != _slots[3])) {
                    continue;
                }
                TraceWrite memory write = TraceWrite(
                    frame, j, store.account, slot, store.previousValue, store.newValue, store.reverted
                );
                writes = bytes.concat(writes, abi.encode(write));
            }
        }
        bytes memory witness = abi.encode(delegateFrame, tokenFrame, _beforeWords, _readRegistryWords(_slots), writes);
        _journal = bytes.concat(_journal, abi.encodePacked(witness.length), witness);
    }

    function _observeTokenFrame(
        Observation memory _obs,
        CallResult memory _result,
        bytes memory _expected
    )
        private
        view
        returns (bytes memory observed)
    {
        uint64 delegateDepth;
        observed = "";
        for (uint256 i; i < _result.accesses.length; ++i) {
            Vm.AccountAccess memory access = _result.accesses[i];
            if (access.kind == VmSafe.AccountAccessKind.DelegateCall && access.account == implementation) {
                delegateDepth = access.depth;
            }
            if (access.kind != VmSafe.AccountAccessKind.Call || access.account != address(token)) continue;
            require(
                _obs.tokenTarget == address(0) && delegateDepth != 0 && access.depth == delegateDepth + 1
                    && access.accessor == REGISTRY && access.value == 0 && access.reverted != _result.ok
                    && keccak256(access.data) == keccak256(_expected),
                "N04 origin: exact nested token transferFrom"
            );
            _obs.tokenTarget = access.account;
            _obs.tokenReverted = access.reverted;
            observed = access.data;
            _observeAllowanceWrite(_obs, access);
        }
        require((_obs.tokenTarget != address(0)) == (_expected.length != 0), "N04 origin: missing token transferFrom");
    }

    function _observeAllowanceWrite(Observation memory _obs, Vm.AccountAccess memory _access) private pure {
        bytes32 slot = keccak256(abi.encode(REGISTRY, keccak256(abi.encode(_obs.actor, uint256(1)))));
        for (uint256 i; i < _access.storageAccesses.length; ++i) {
            Vm.StorageAccess memory access = _access.storageAccesses[i];
            if (access.account != _access.account || access.slot != slot || !access.isWrite) continue;
            ++_obs.allowanceWrite[0];
            _obs.allowanceWrite[1] = uint256(access.previousValue);
            _obs.allowanceWrite[2] = uint256(access.newValue);
            require(access.reverted == _access.reverted, "N04 token: allowance write revert flag");
        }
        if (_obs.name == "register_refusal") {
            require(_obs.allowanceWrite[0] == 0, "N04 token: no write on allowance refusal");
        } else {
            require(
                _obs.allowanceWrite[0] == 1 && _obs.allowanceWrite[1] == 4 && _obs.allowanceWrite[2] == 0,
                "N04 token: exact allowance write"
            );
        }
    }

    function _externalAction(bytes32 _name, address _actor, bytes memory _call, bytes memory _return) private {
        Observation memory obs = _observeBefore(_name, _actor);
        CallResult memory result;
        VM.recordLogs();
        VM.startStateDiffRecording();
        if (_actor != address(this)) VM.prank(_actor);
        (result.ok, result.data) = address(token).call(_call);
        result.accesses = VM.stopAndReturnStateDiff();
        result.logs = VM.getRecordedLogs();

        bytes memory observedCall;
        for (uint256 i; i < result.accesses.length; ++i) {
            Vm.AccountAccess memory access = result.accesses[i];
            if (access.kind != VmSafe.AccountAccessKind.Call || access.account != address(token)) continue;
            require(
                obs.target == address(0) && access.accessor == _actor && access.value == 0 && !access.reverted
                    && keccak256(access.data) == keccak256(_call),
                "N04 context: exact external token call"
            );
            obs.target = access.account;
            observedCall = access.data;
        }
        require(obs.target == address(token), "N04 context: missing external token call");
        _observeAfter(obs, result);
        require(
            result.ok && keccak256(result.data) == keccak256(_return) && result.logs.length == 0,
            "N04 context: exact external token result"
        );
        _append(obs, observedCall, result.data, "");
    }

    function _observeBefore(bytes32 _name, address _actor) private returns (Observation memory obs) {
        obs.name = _name;
        obs.height = VM.getBlockNumber();
        obs.snapshot = inbox.activeCommitteeSnapshot();
        obs.actor = _actor;
        obs.beforeState = _stateDigest();
    }

    function _observeAfter(Observation memory _obs, CallResult memory _result) private {
        _obs.ok = _result.ok;
        _obs.logCount = _result.logs.length;
        _obs.afterState = _stateDigest();
        require(
            _obs.height == VM.getBlockNumber() && _obs.snapshot == inbox.activeCommitteeSnapshot(),
            "N04 context: height and snapshot unchanged"
        );
    }

    function _append(
        Observation memory _obs,
        bytes memory _call,
        bytes memory _return,
        bytes memory _tokenCall
    )
        private
    {
        bytes memory step = abi.encode(_obs, _call, _return, _tokenCall);
        _journal = bytes.concat(_journal, abi.encodePacked(step.length), step);
    }

    function _requireTopUpState(PublicPoP memory _first, PublicPoP memory _neighbor, bool _deposited) private view {
        (uint256 pending, uint48 ready) = registry.topUpOf(0);
        require(
            pending == (_deposited ? 4 : 0) && ready == (_deposited ? 14 : 0),
            "N04 topUp: exact pending and readiness"
        );
        require(
            _rawMap(R + 3, 4096) == bytes32(uint256(_deposited ? 8 : 4) << 12)
                && _rawMap(R + 3, 4097) == bytes32(uint256(4 << 12 | 1)),
            "N04 topUp: exact admission leaves"
        );
        IEtnaStakingRegistry.Entry memory first = _entry(_first, 4, 12);
        IEtnaStakingRegistry.Entry memory neighbor = _entry(_neighbor, 4, 12);
        _requireEntry(_mapSlot(R + 6, 0), first);
        _requireEntry(_mapSlot(R + 6, 1), neighbor);
        bytes32 root = keccak256(abi.encodePacked(_leaf(0, first), _leaf(1, neighbor)));
        require(
            registry.checkpointCount() == 1 && registry.entriesRoot() == root, "N04 topUp: effective history unchanged"
        );
        _requireCheckpoint(0, 10, 2, root);
    }

    function _entry(PublicPoP memory _pop, uint256 _stake, uint48 _active)
        private
        pure
        returns (IEtnaStakingRegistry.Entry memory)
    {
        return IEtnaStakingRegistry.Entry({
            ckPrefix: _pop.prefix, ckX: _pop.x, effStake: _stake, activeFromL1: _active, exitEffectiveL1: NO_EXIT
        });
    }

    function _registeredEvent(PublicPoP memory _pop) private pure returns (bytes32) {
        bytes32[] memory topics = new bytes32[](4);
        topics[0] = keccak256("Registered(uint256,address,address,uint8,bytes32,uint256,uint48)");
        topics[1] = bytes32(uint256(1));
        topics[2] = bytes32(uint256(uint160(_pop.owner)));
        topics[3] = bytes32(uint256(uint160(_pop.signer)));
        return _event(REGISTRY, topics, abi.encode(_pop.prefix, _pop.x, uint256(4), uint48(13)));
    }

    function _topUpEvent(string memory _signature, bytes memory _data) private pure returns (bytes32) {
        bytes32[] memory topics = new bytes32[](2);
        topics[0] = keccak256(bytes(_signature));
        // Topic 1 is the indexed bond ID 0.
        return _event(REGISTRY, topics, _data);
    }
}
