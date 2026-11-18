// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Vm, VmSafe} from "forge-std/src/Vm.sol";
import {IEtnaStakingRegistry} from "src/layer1/etna/iface/IEtnaStakingRegistry.sol";
import {EtnaRegistryCasesBase} from "./EtnaRegistryCasesBase.sol";

/// @notice Actual occupied-zero displacement and the opposite public retirement schedule.
contract EtnaRegistryDisplacementCasesTest is EtnaRegistryCasesBase {
    // All fields are static: ABI encoding inlines these twelve words before the two bytes offsets.
    struct StepContext {
        bytes32 name;
        uint256 height;
        uint48 snapshot;
        uint48 generation;
        address actor;
        address target;
        bool ok;
        bytes32 beforeState;
        bytes32 afterState;
        bytes32 beforeFullState;
        bytes32 afterFullState;
        uint256 logCount;
    }

    bytes private _journal;
    address[3] private _signers;
    bytes32[3] private _keys;

    /// @notice Replace a held zero bond before its permissionless zero withdrawal.
    function test_held_zero_displacement_then_withdraw() external {
        _prepare();
        _registration("replace_held_zero", 4, 2);
        require(uint256(_raw(_mapSlot(R + 6, 0) + 3)) & (1 << 16) == 0, "O03 replace: old holdsSlot still set");
        require(_rawMap(R + 5, 0) == bytes32(uint256(3)), "O03 replace: actual replacement slot");
        VM.roll(18);
        _action("zero_withdraw", REPORTER, abi.encodeCall(IEtnaStakingRegistry.withdraw, (0, PAYEE)));
        require(_rawMap(R + 5, 0) == bytes32(uint256(3)), "O03 withdraw: replacement slot erased");
        _finish();
    }

    /// @notice Withdraw the still-held zero bond before replacement takes a genuine vacancy.
    function test_zero_withdraw_then_vacant_reuse() external {
        _prepare();
        VM.roll(18);
        _action("zero_withdraw", REPORTER, abi.encodeCall(IEtnaStakingRegistry.withdraw, (0, PAYEE)));
        require(_rawMap(R + 5, 0) == 0, "O03 vacancy: old slot cleared");
        IEtnaStakingRegistry.Entry memory empty;
        require(_rawMap(R + 2, 0) == _leaf(0, empty), "O03 vacancy: hashed empty used leaf");
        VM.roll(19);
        _registration("replace_vacancy", 4, 2);
        _finish();
    }

    /// @dev Construct all principal, exits and evidence through actual public entry points.
    function _prepare() private {
        _setupRegistry(0);
        _fund(OWNER_A, 100, 100);
        _journal = abi.encodePacked(bytes32("etna-registry-displacement-2"));
        for (uint256 i; i < 3; ++i) {
            PublicPoP memory pop = _publicPoP(2 * i);
            require(pop.owner == OWNER_A, "O03 public owners");
            _signers[i] = pop.signer;
            _keys[i] = pop.entryKey;
        }
        _registration("register_a", 0, 0);
        _registration("register_b", 2, 1);
        VM.roll(12);
        _action("topup_a", OWNER_A, abi.encodeCall(IEtnaStakingRegistry.topUp, (0, 5)));
        VM.roll(13);
        _refuse(
            "activate_early",
            abi.encodeCall(IEtnaStakingRegistry.activateTopUp, (0)),
            IEtnaStakingRegistry.TopUpNotReady.selector
        );
        VM.roll(14);
        _action("activate_a", REPORTER, abi.encodeCall(IEtnaStakingRegistry.activateTopUp, (0)));
        VM.roll(15);
        _action("force_exit_a", INBOX, abi.encodeCall(IEtnaStakingRegistry.forceExit, (0, _keys[0])));
        VM.roll(16);
        _premise("snapshot_uncovered", abi.encodeWithSignature("setSnapshot(uint48)", uint48(14)));
        _refuse(
            "confirm_uncovered",
            abi.encodeCall(IEtnaStakingRegistry.confirmExit, (0)),
            IEtnaStakingRegistry.ExitNotCovered.selector
        );
        _premise("snapshot_covered", abi.encodeWithSignature("setSnapshot(uint48)", uint48(15)));
        _action("confirm_a", REPORTER, abi.encodeCall(IEtnaStakingRegistry.confirmExit, (0)));
        _premise("generation_advance", abi.encodeWithSignature("setGeneration(uint48)", uint48(1)));
        VM.roll(17);
        string memory votes = VM.readFile("test/layer1/etna/conformance/vectors/comet_signed/public-votes.json");
        _action(
            "slash_historical",
            REPORTER,
            abi.encodeCall(
                IEtnaStakingRegistry.slashDoubleSign,
                (0, _publicVote(votes, _rowPath(".voteCases", 0)), _publicVote(votes, _rowPath(".voteCases", 2)))
            )
        );
        require(
            registry.exitConfirmedAtL1(0) == 16 && registry.bondAt(0).entry.exitEffectiveL1 == 15,
            "O03 slash: retained exit and confirmation"
        );
        _refuse(
            "withdraw_early",
            abi.encodeCall(IEtnaStakingRegistry.withdraw, (0, PAYEE)),
            IEtnaStakingRegistry.WithdrawalNotReady.selector
        );
    }

    /// @dev Require lifetime identity, distinct replacement and exact conserved fixture cash.
    function _finish() private {
        require(
            registry.ownerOf(0) == address(0) && registry.exitConfirmedAtL1(0) == 0,
            "O03 retirement: owner and confirmation cleared"
        );
        IEtnaStakingRegistry.Bond memory old = registry.bondAt(0);
        require(
            old.withdrawn && !old.holdsSlot && old.slot == 0 && old.entry.effStake == 0 && old.entry.activeFromL1 == 12
                && old.entry.exitEffectiveL1 == 15,
            "O03 retirement: immutable historical identity"
        );
        (bool known, uint256 bond) = registry.bondForKey(_signers[0]);
        require(known && bond == 0 && !registry.forfeited(_keys[0]), "O03 retirement: lifetime key retained");
        require(
            _balance(OWNER_A) == 83 && _allowance(OWNER_A) == 83 && _balance(REGISTRY) == 8 && _balance(REPORTER) == 2
                && _balance(SINK) == 7 && _balance(PAYEE) == 0 && _transfers() == 6,
            "O03 cash: exact deposits and payouts"
        );
        emit RegistryCaseReceipt(_journal);
    }

    /// @dev Bind a genuine public PoP to its actual issued ID.
    function _registration(bytes32 _name, uint256 _row, uint256 _id) private {
        PublicPoP memory pop = _publicPoP(_row);
        _step(
            _name,
            pop.owner,
            REGISTRY,
            abi.encodeCall(IEtnaStakingRegistry.register, (pop.key, 4, pop.signature)),
            true,
            abi.encode(_id)
        );
    }

    /// @dev Bind a successful actual Registry action.
    function _action(bytes32 _name, address _actor, bytes memory _data) private {
        _step(_name, _actor, REGISTRY, _data, true, "");
    }

    /// @dev Bind an actual refusal and its complete selected rollback.
    function _refuse(bytes32 _name, bytes memory _data, bytes4 _error) private {
        _step(_name, REPORTER, REGISTRY, _data, false, abi.encodePacked(_error));
    }

    /// @dev Explicitly journal a synthetic Inbox premise through its real fixture setter.
    function _premise(bytes32 _name, bytes memory _data) private {
        _step(_name, address(this), INBOX, _data, true, "");
    }

    /// @notice Read the unchanged full observer in a fresh memory frame for this test only.
    function observeFullState() external returns (bytes32) {
        require(msg.sender == address(this), "O03 observer: self only");
        return _stateDigest();
    }

    /// @dev Record only the actual action; keep all raw observers outside the recorder.
    function _step(bytes32 _name, address _actor, address _target, bytes memory _data, bool _ok, bytes memory _return)
        private
    {
        StepContext memory context;
        context.name = _name;
        context.actor = _actor;
        context.beforeState = _selectedState();
        context.beforeFullState = this.observeFullState();
        context.height = VM.getBlockNumber();
        context.snapshot = inbox.activeCommitteeSnapshot();
        context.generation = inbox.recoveryGeneration();
        require(block.chainid == 1 && block.timestamp == 1000, "O03 context: chain and timestamp");
        CallResult memory result;
        bytes memory observed;
        if (_target == REGISTRY) {
            result = _callRegistry(_actor, _data);
            (context.target, observed) = _registryFrame(result, _actor, _data);
            require(
                context.snapshot == inbox.activeCommitteeSnapshot() && context.generation == inbox.recoveryGeneration(),
                "O03 context: Registry changed premise"
            );
        } else {
            VM.recordLogs();
            VM.startStateDiffRecording();
            (result.ok, result.data) = INBOX.call(_data);
            result.accesses = VM.stopAndReturnStateDiff();
            result.logs = VM.getRecordedLogs();
            uint256 frames;
            for (uint256 i; i < result.accesses.length; ++i) {
                Vm.AccountAccess memory access = result.accesses[i];
                if (access.kind == VmSafe.AccountAccessKind.Call && access.account == INBOX) {
                    require(
                        access.accessor == _actor && !access.reverted && keccak256(access.data) == keccak256(_data),
                        "O03 premise: exact direct call"
                    );
                    context.target = access.account;
                    observed = access.data;
                    ++frames;
                }
            }
            require(frames == 1, "O03 premise: unique direct call");
        }
        require(context.height == VM.getBlockNumber(), "O03 context: height changed");
        context.afterFullState = this.observeFullState();
        if (_ok) require(result.ok && keccak256(result.data) == keccak256(_return), "O03 action: exact success");
        else _requireRefusal(result, _return, context.beforeFullState, context.afterFullState, new bytes32[](0));
        context.ok = result.ok;
        context.afterState = _selectedState();
        context.logCount = result.logs.length;
        bytes memory step = abi.encode(context, observed, result.data);
        _journal = bytes.concat(_journal, abi.encodePacked(step.length), step);
    }

    /// @dev Fixed 83-word raw projection: eight closed checkpoints and all selected identities/cash.
    function _selectedState() private view returns (bytes32) {
        bytes32[83] memory words;
        words[0] = _raw(R);
        words[1] = _raw(R + 1);
        words[2] = _raw(R + 7);
        words[3] = registry.entriesRoot();
        words[4] = VM.load(INBOX, 0);
        require(
            registry.checkpointCount() == uint256(words[0]) && registry.entryCount() == uint256(words[1])
                && registry.bondCount() == uint256(words[2]),
            "O03 counts: raw and ABI"
        );
        uint256 checkpoints = uint256(keccak256(abi.encode(R)));
        for (uint256 i; i < 8; ++i) {
            words[5 + 2 * i] = _raw(checkpoints + 2 * i);
            words[6 + 2 * i] = _raw(checkpoints + 2 * i + 1);
            if (i < uint256(words[0])) {
                uint256 fields = uint256(words[5 + 2 * i]);
                _requireCheckpoint(i, uint48(fields), uint48(fields >> 48), words[6 + 2 * i]);
            }
        }
        uint256 entries = uint256(keccak256(abi.encode(R + 1)));
        for (uint256 i; i < 6; ++i) {
            words[21 + i] = _raw(entries + i);
        }
        words[27] = _rawMap(R + 2, 0);
        words[28] = _rawMap(R + 2, 1);
        words[29] = _rawMap(R + 2, 1 << 32);
        words[30] = _rawMap(R + 5, 0);
        words[31] = _rawMap(R + 5, 1);
        for (uint256 i; i < 13; ++i) {
            words[32 + i] = _rawMap(R + 3, 1 << i);
        }
        words[45] = _rawMap(R + 3, 4097);
        for (uint256 i; i < 3; ++i) {
            uint256 dest = 46 + 10 * i;
            uint256 bond = _mapSlot(R + 6, i);
            for (uint256 j; j < 4; ++j) {
                words[dest + j] = _raw(bond + j);
            }
            words[dest + 4] = _rawMap(OWNERS, i);
            words[dest + 5] = _rawMap(CONFIRM, i);
            words[dest + 6] = _rawMap(TOP, i);
            words[dest + 7] = _raw(_mapSlot(TOP, i) + 1);
            words[dest + 8] = _rawMap(R + 4, uint160(_signers[i]));
            words[dest + 9] = _rawMap(FORFEIT, uint256(_keys[i]));
        }
        words[76] = bytes32(_balance(OWNER_A));
        words[77] = bytes32(_allowance(OWNER_A));
        words[78] = bytes32(_balance(REGISTRY));
        words[79] = bytes32(_balance(REPORTER));
        words[80] = bytes32(_balance(SINK));
        words[81] = bytes32(_balance(PAYEE));
        words[82] = bytes32(_transfers());
        return keccak256(abi.encode(words));
    }
}
