// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Vm } from "forge-std/src/Vm.sol";
import { IEtnaStakingRegistry } from "src/layer1/etna/iface/IEtnaStakingRegistry.sol";
import { EtnaRegistryCasesBase, RegistryCasesInbox } from "./EtnaRegistryCasesBase.sol";
import { PublicReplayToken } from "./EtnaRegistryPublicReplay.t.sol";

/// @notice Exercises delayed principal through the historical Registry proxy.
contract EtnaRegistryFundingReplayTest is EtnaRegistryCasesBase {
    uint256 private constant _DEADLINE = 1060;
    uint256 private constant _JOURNAL_CAPACITY = 2 * 1024 * 1024;
    bytes32 private constant _INCIDENT = keccak256("ETNA-Y04-FUNDED-FORFEITURE");

    enum Kind { Call, Authorization, Restore, Setup }

    struct Step {
        Kind kind;
        bytes32 name;
        uint256 height;
        uint256 timestamp;
        address actor;
        address target;
        bool ok;
        bytes input;
        bytes output;
        bytes32[95] beforeWords;
        bytes32[95] afterWords;
        bytes32 beforeDigest;
        bytes32 afterDigest;
        Vm.Log[] logs;
        Vm.AccountAccess[] frames;
    }

    address private _proxyTemplate;
    address private _inboxTemplate;
    address[3] private _lifetimeSigners;
    bytes32[3] private _lifetimeKeys;

    event RegistryFundingFaultPrefix(bytes payload);

    /// @notice Checks the complete closed-allocation mock-token lifecycle.
    function test_funded_forfeiture_and_reuse() external {
        bytes memory journal = _allocate(_initialize());
        journal = _registration(journal, "register_a", 0, true, abi.encode(uint256(0)));
        journal = _registration(journal, "register_b", 3, true, abi.encode(uint256(1)));

        VM.roll(12);
        bytes memory forfeit = abi.encodeCall(
            IEtnaStakingRegistry.forfeit, (0, _lifetimeKeys[0], _INCIDENT, _DEADLINE)
        );
        Step memory authorization = _premise(Kind.Authorization, "authorize");
        authorization.actor = ADMIN;
        authorization.target = REGISTRY;
        authorization.input = forfeit;
        journal = _appendBytes(journal, _encode(authorization));

        journal = _refusalBranches(journal, forfeit, authorization.beforeDigest);
        journal = _action(
            journal, "topup_a", OWNER_A, REGISTRY, abi.encodeCall(IEtnaStakingRegistry.topUp, (0, 5))
        );
        journal = _executeForfeit(journal, forfeit);
        journal = _confirmAndWithdraw(journal);
        VM.roll(19);
        journal = _registration(
            journal, "retired_key", 1, false, abi.encodePacked(IEtnaStakingRegistry.KeyAlreadyUsed.selector)
        );
        journal = _approve(journal, "approve_payout", OWNER_A, 4);
        journal = _registration(journal, "register_fresh_a", 4, true, abi.encode(uint256(2)));

        require(
            _balance(OWNER_A) == 0 && _balance(OWNER_B) == 0 && _balance(REPORTER) == 2
                && _balance(REGISTRY) == 8 && _balance(SINK) == 5 && _transfers() == 6,
            "Y04 final closed balances"
        );
        require(
            _rawMap(FORFEIT, uint256(_lifetimeKeys[0])) == bytes32(uint256(1))
                && _rawMap(R + 4, uint160(_lifetimeSigners[0])) == bytes32(uint256(1)),
            "Y04 retained lifetime flags"
        );
        emit RegistryCaseReceipt(journal);
    }

    /// @dev Records creation, initialization and raw state around the unchanged setup.
    function _initialize() private returns (bytes memory) {
        VM.chainId(1);
        VM.roll(10);
        VM.warp(1000);
        uint64 nonce = VM.getNonce(address(this));
        token = PublicReplayToken(VM.computeCreateAddress(address(this), nonce));
        implementation = VM.computeCreateAddress(address(this), nonce + 2);
        _inboxTemplate = VM.computeCreateAddress(address(this), nonce + 1);
        _proxyTemplate = VM.computeCreateAddress(address(this), nonce + 3);
        require(
            REGISTRY.code.length == 0 && INBOX.code.length == 0 && address(token).code.length == 0
                && implementation.code.length == 0 && _proxyTemplate.code.length == 0
                && _inboxTemplate.code.length == 0,
            "Y04 fresh deployment accounts"
        );
        Step memory setup;
        setup.kind = Kind.Setup;
        setup.name = "setup";
        setup.height = VM.getBlockNumber();
        setup.timestamp = VM.getBlockTimestamp();
        setup.actor = address(this);
        setup.target = REGISTRY;
        setup.input = abi.encodeWithSignature("init(address)", ADMIN);
        setup.beforeWords = _selectedState();
        setup.beforeDigest = this.wideStateDigest();
        VM.recordLogs();
        VM.startStateDiffRecording();
        _setupRegistry(0);
        setup.frames = VM.stopAndReturnStateDiff();
        setup.logs = VM.getRecordedLogs();
        setup.ok = true;
        require(
            address(token) == VM.computeCreateAddress(address(this), nonce)
                && implementation == VM.computeCreateAddress(address(this), nonce + 2)
                && _inboxTemplate.codehash == INBOX.codehash
                && _proxyTemplate.codehash == REGISTRY.codehash,
            "Y04 deployment identities"
        );
        uint256[3] memory rows = [uint256(0), 3, 4];
        for (uint256 i; i < rows.length; ++i) {
            PublicPoP memory pop = _publicPoP(rows[i]);
            _lifetimeSigners[i] = pop.signer;
            _lifetimeKeys[i] = pop.entryKey;
        }
        setup.afterWords = _selectedState();
        setup.afterDigest = this.wideStateDigest();
        return _newJournal(
            abi.encode(
                bytes32("etna-registry-funding-1"), address(this), address(token), INBOX, REGISTRY,
                implementation, _proxyTemplate, _inboxTemplate
            ),
            _encode(setup)
        );
    }

    /// @dev Records the only three initial mock-token allocations and approvals.
    function _allocate(bytes memory _journal) private returns (bytes memory) {
        address[3] memory owners = [OWNER_A, OWNER_B, REPORTER];
        uint256[3] memory amounts = [uint256(9), 4, 2];
        uint256[3] memory approvals = [uint256(9), 4, 1];
        bytes32[3] memory mintNames = [bytes32("mint_a"), bytes32("mint_b"), bytes32("mint_public")];
        bytes32[3] memory approvalNames =
            [bytes32("approve_a"), bytes32("approve_b"), bytes32("approve_public")];
        for (uint256 i; i < owners.length; ++i) {
            _journal = _action(
                _journal, mintNames[i], address(this), address(token),
                abi.encodeCall(PublicReplayToken.mint, (owners[i], amounts[i]))
            );
            _journal = _approve(_journal, approvalNames[i], owners[i], approvals[i]);
        }
        return _journal;
    }

    /// @dev Exercises independent refusal branches from the same saved prefix.
    function _refusalBranches(bytes memory _journal, bytes memory _forfeit, bytes32 _anchor)
        private
        returns (bytes memory)
    {
        uint256 saved = VM.snapshotState();
        VM.roll(15);
        VM.warp(_DEADLINE + 1);
        _journal = _refuse(
            _journal, "forfeit_late", ADMIN, _forfeit, IEtnaStakingRegistry.AuthorizationExpired.selector
        );
        _journal = _restore(_journal, "restore_late", saved, _anchor);

        saved = VM.snapshotState();
        require(_balance(REPORTER) == 2 && _allowance(REPORTER) == 1, "Y04 funded public offer");
        _journal = _refuse(
            _journal, "topup_public", REPORTER, abi.encodeCall(IEtnaStakingRegistry.topUp, (0, 1)),
            IEtnaStakingRegistry.NotBondOwner.selector
        );
        return _restore(_journal, "restore_public", saved, _anchor);
    }

    /// @dev Restores EVM state and explicitly restores the declared branch clock.
    function _restore(bytes memory _journal, bytes32 _name, uint256 _saved, bytes32 _anchor)
        private
        returns (bytes memory)
    {
        require(VM.revertToState(_saved), "Y04 restore fixture branch");
        VM.roll(12);
        VM.warp(1000);
        Step memory restored = _premise(Kind.Restore, _name);
        require(
            restored.height == 12 && restored.timestamp == 1000 && restored.beforeDigest == _anchor,
            "Y04 intact prefix restoration"
        );
        return _appendBytes(_journal, _encode(restored));
    }

    /// @dev Captures the equality boundary with full before/after wide digests.
    function _executeForfeit(bytes memory _journal, bytes memory _forfeit)
        private
        returns (bytes memory)
    {
        VM.roll(15);
        VM.warp(_DEADLINE);
        _journal = _action(
            _journal, "mock_generation", address(this), INBOX, abi.encodeCall(RegistryCasesInbox.setGeneration, (1))
        );
        Step memory execution = _observe("forfeit", ADMIN, REGISTRY, _forfeit, true);
        if (
            !execution.ok
                && keccak256(execution.output)
                    == keccak256(abi.encodePacked(IEtnaStakingRegistry.AuthorizationExpired.selector))
        ) {
            emit RegistryFundingFaultPrefix(_appendBytes(_journal, _encode(execution)));
            revert("Y04 deadline equality: got AuthorizationExpired");
        }
        _journal = _append(_journal, execution, true, "");
        if (_rawMap(TOP, 0) != bytes32(uint256(4))) {
            emit RegistryFundingFaultPrefix(_journal);
            revert("Y04 pending debit: expected 4");
        }
        require(
            _raw(_mapSlot(TOP, 0) + 1) == bytes32(uint256(14)) && _balance(SINK) == 5
                && _balance(REGISTRY) == 8,
            "Y04 forfeiture readiness and balances"
        );
        return _journal;
    }

    /// @dev Records coverage and delay boundaries before the owner payout.
    function _confirmAndWithdraw(bytes memory _journal) private returns (bytes memory) {
        VM.roll(16);
        bytes memory confirm = abi.encodeCall(IEtnaStakingRegistry.confirmExit, (0));
        _journal = _snapshot(_journal, "mock_uncovered", 14);
        _journal = _refuse(
            _journal, "confirm_uncovered", REPORTER, confirm, IEtnaStakingRegistry.ExitNotCovered.selector
        );
        _journal = _snapshot(_journal, "mock_covered", 15);
        _journal = _action(_journal, "confirm", REPORTER, REGISTRY, confirm);

        VM.roll(17);
        bytes memory withdraw = abi.encodeCall(IEtnaStakingRegistry.withdraw, (0, OWNER_A));
        _journal = _refuse(
            _journal, "withdraw_early", OWNER_A, withdraw, IEtnaStakingRegistry.WithdrawalNotReady.selector
        );
        VM.roll(18);
        _journal = _refuse(
            _journal, "withdraw_public", REPORTER, abi.encodeCall(IEtnaStakingRegistry.withdraw, (0, PAYEE)),
            IEtnaStakingRegistry.NotBondOwner.selector
        );
        _journal = _action(_journal, "withdraw_a", OWNER_A, REGISTRY, withdraw);
        require(_balance(OWNER_A) == 4 && _balance(REGISTRY) == 4, "Y04 exact owner payout");
        return _journal;
    }

    /// @dev Records an explicit mock Inbox snapshot premise.
    function _snapshot(bytes memory _journal, bytes32 _name, uint48 _height)
        private
        returns (bytes memory)
    {
        return _action(
            _journal, _name, address(this), INBOX, abi.encodeCall(RegistryCasesInbox.setSnapshot, (_height))
        );
    }

    /// @dev Records a real mock-token approval without allocating more tokens.
    function _approve(bytes memory _journal, bytes32 _name, address _owner, uint256 _amount)
        private
        returns (bytes memory)
    {
        Step memory s = _observe(
            _name, _owner, address(token), abi.encodeCall(PublicReplayToken.approve, (REGISTRY, _amount)), false
        );
        return _append(_journal, s, true, abi.encode(true));
    }

    /// @dev Records a successful action and checks its void return data.
    function _action(bytes memory _journal, bytes32 _name, address _actor, address _target, bytes memory _input)
        private
        returns (bytes memory)
    {
        return _append(_journal, _observe(_name, _actor, _target, _input, false), true, "");
    }

    /// @dev Records an exact refusal with unchanged bounded state.
    function _refuse(bytes memory _journal, bytes32 _name, address _actor, bytes memory _input, bytes4 _error)
        private
        returns (bytes memory)
    {
        return _append(_journal, _observe(_name, _actor, REGISTRY, _input, true), false, abi.encodePacked(_error));
    }

    /// @dev Uses a pinned public registration proof with its declared owner.
    function _registration(bytes memory _journal, bytes32 _name, uint256 _row, bool _ok, bytes memory _output)
        private
        returns (bytes memory)
    {
        PublicPoP memory pop = _publicPoP(_row);
        bytes memory input = abi.encodeCall(IEtnaStakingRegistry.register, (pop.key, 4, pop.signature));
        return _append(_journal, _observe(_name, pop.owner, REGISTRY, input, !_ok), _ok, _output);
    }

    /// @dev Records a non-transactional authorization or restored-prefix observation.
    function _premise(Kind _kind, bytes32 _name) private returns (Step memory s) {
        s.kind = _kind;
        s.name = _name;
        s.height = VM.getBlockNumber();
        s.timestamp = VM.getBlockTimestamp();
        s.ok = true;
        s.beforeWords = _selectedState();
        s.afterWords = s.beforeWords;
        s.beforeDigest = this.wideStateDigest();
        s.afterDigest = s.beforeDigest;
    }

    /// @dev Captures raw state, logs and complete ordered account accesses.
    function _observe(bytes32 _name, address _actor, address _target, bytes memory _input, bool _digest)
        private
        returns (Step memory s)
    {
        s.name = _name;
        s.height = VM.getBlockNumber();
        s.timestamp = VM.getBlockTimestamp();
        s.actor = _actor;
        s.target = _target;
        s.input = _input;
        s.beforeWords = _selectedState();
        if (_digest) s.beforeDigest = this.wideStateDigest();
        CallResult memory result;
        if (_target == REGISTRY) {
            result = _callRegistry(_actor, _input);
            _registryFrame(result, _actor, _input);
        } else {
            VM.recordLogs();
            VM.startStateDiffRecording();
            VM.prank(_actor);
            (result.ok, result.data) = _target.call(_input);
            result.accesses = VM.stopAndReturnStateDiff();
            result.logs = VM.getRecordedLogs();
        }
        require(
            s.height == VM.getBlockNumber() && s.timestamp == VM.getBlockTimestamp(),
            "Y04 call clock stability"
        );
        s.ok = result.ok;
        s.output = result.data;
        s.logs = result.logs;
        s.frames = result.accesses;
        s.afterWords = _selectedState();
        if (_digest) s.afterDigest = this.wideStateDigest();
    }

    /// @dev Checks the expected result before appending one closed record.
    function _append(bytes memory _journal, Step memory _s, bool _ok, bytes memory _output)
        private
        pure
        returns (bytes memory)
    {
        require(
            _s.ok == _ok && keccak256(_s.output) == keccak256(_output),
            string.concat("Y04 unexpected outcome: ", string(abi.encodePacked(_s.name)))
        );
        if (!_ok) {
            require(
                _s.beforeDigest != bytes32(0) && _s.beforeDigest == _s.afterDigest
                    && keccak256(abi.encode(_s.beforeWords)) == keccak256(abi.encode(_s.afterWords))
                    && _s.logs.length == 0,
                "Y04 refusal rollback"
            );
        }
        return _appendBytes(_journal, _encode(_s));
    }

    /// @dev Isolates unchanged wide observation in a fresh EVM memory frame.
    function wideStateDigest() external returns (bytes32) {
        require(msg.sender == address(this), "Y04 observer self only");
        return _stateDigest();
    }

    /// @dev Reserves one bounded journal rather than copying every earlier record.
    function _newJournal(bytes memory _header, bytes memory _first)
        private
        pure
        returns (bytes memory journal)
    {
        journal = new bytes(_JOURNAL_CAPACITY);
        assembly ("memory-safe") { mstore(journal, 0) }
        _appendBytes(journal, _header);
        return _appendBytes(journal, _first);
    }

    /// @dev Appends only to the private reserved journal; its allocated extent stays fixed.
    function _appendBytes(bytes memory _journal, bytes memory _fragment)
        private
        pure
        returns (bytes memory)
    {
        uint256 length = _journal.length;
        require(
            length <= _JOURNAL_CAPACITY && _fragment.length <= _JOURNAL_CAPACITY - length,
            "Y04 journal capacity"
        );
        assembly ("memory-safe") {
            mcopy(add(add(_journal, 32), length), add(_fragment, 32), mload(_fragment))
            mstore(_journal, add(length, mload(_fragment)))
        }
        return _journal;
    }

    /// @dev Length-prefixes the complete typed ABI record.
    function _encode(Step memory _s) private pure returns (bytes memory) {
        bytes memory data = abi.encode(_s);
        return bytes.concat(abi.encode(data.length), data);
    }

    /// @dev Reads all selected raw slots; absent deployment has no entries-root getter.
    function _selectedState() private view returns (bytes32[95] memory words) {
        words[0] = _raw(R);
        words[1] = _raw(R + 1);
        words[2] = _raw(R + 7);
        words[3] = REGISTRY.code.length == 0 ? bytes32(0) : registry.entriesRoot();
        words[4] = VM.load(INBOX, bytes32(0));

        uint256 checkpointBase = uint256(keccak256(abi.encode(R)));
        uint256 entryBase = uint256(keccak256(abi.encode(R + 1)));
        for (uint256 i; i < 8; ++i) words[5 + i] = _raw(checkpointBase + i);
        for (uint256 i; i < 6; ++i) words[13 + i] = _raw(entryBase + i);
        words[19] = _rawMap(R + 2, 0);
        words[20] = _rawMap(R + 2, 1);
        words[21] = _rawMap(R + 2, 1 << 32);
        words[22] = _rawMap(R + 5, 0);
        words[23] = _rawMap(R + 5, 1);
        for (uint256 i; i < 13; ++i) words[24 + i] = _rawMap(R + 3, 4096 >> i);
        words[37] = _rawMap(R + 3, 4097);
        for (uint256 i; i < 3; ++i) _bondWords(words, i);

        address[13] memory accounts = [
            OWNER_A, OWNER_B, REPORTER, REGISTRY, SINK, PAYEE, ADMIN, address(this), address(token),
            INBOX, implementation, _proxyTemplate, _inboxTemplate
        ];
        for (uint256 i; i < accounts.length; ++i) {
            words[68 + 2 * i] = bytes32(_balance(accounts[i]));
            words[69 + 2 * i] = bytes32(_allowance(accounts[i]));
        }
        words[94] = bytes32(_transfers());
    }

    /// @dev Records lifetime, ownership, pending principal and readiness slots.
    function _bondWords(bytes32[95] memory _words, uint256 _id) private view {
        uint256 dest = 38 + 10 * _id;
        uint256 bond = _mapSlot(R + 6, _id);
        for (uint256 i; i < 4; ++i) _words[dest + i] = _raw(bond + i);
        _words[dest + 4] = _rawMap(OWNERS, _id);
        _words[dest + 5] = _rawMap(CONFIRM, _id);
        _words[dest + 6] = _rawMap(TOP, _id);
        _words[dest + 7] = _raw(_mapSlot(TOP, _id) + 1);
        _words[dest + 8] = _rawMap(R + 4, uint160(_lifetimeSigners[_id]));
        _words[dest + 9] = _rawMap(FORFEIT, uint256(_lifetimeKeys[_id]));
    }
}
