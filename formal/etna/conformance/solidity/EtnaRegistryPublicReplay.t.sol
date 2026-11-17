// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Vm } from "forge-std/src/Vm.sol";
import { IEtnaStakingRegistry } from "src/layer1/etna/iface/IEtnaStakingRegistry.sol";
import { EtnaStakingRegistry } from "src/layer1/etna/impl/EtnaStakingRegistry.sol";

/// @dev Minimal exact-transfer token. No callback, fee or token-authentication claim.
contract PublicReplayToken {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    uint256 public transfers;
    event Transfer(address indexed from, address indexed to, uint256 amount);

    function mint(address _to, uint256 _amount) external {
        balanceOf[_to] += _amount;
    }

    function approve(address _to, uint256 _amount) external returns (bool) {
        allowance[msg.sender][_to] = _amount;
        return true;
    }

    function transfer(address _to, uint256 _amount) external returns (bool) {
        _move(msg.sender, _to, _amount);
        return true;
    }

    function transferFrom(
        address _from,
        address _to,
        uint256 _amount
    )
        external
        returns (bool)
    {
        require(allowance[_from][msg.sender] >= _amount, "token allowance");
        allowance[_from][msg.sender] -= _amount;
        _move(_from, _to, _amount);
        return true;
    }

    function _move(address _from, address _to, uint256 _amount) private {
        require(balanceOf[_from] >= _amount, "token balance");
        balanceOf[_from] -= _amount;
        balanceOf[_to] += _amount;
        ++transfers;
        emit Transfer(_from, _to, _amount);
    }
}

/// @dev Named interface premises: initialized, unlocked Inbox and operator-supplied snapshot.
contract PublicReplayInbox {
    uint48 public activeCommitteeSnapshot;

    function isInitialized() external pure returns (bool) {
        return true;
    }

    function inNonReentrant() external pure returns (bool) {
        return false;
    }

    function setSnapshot(uint48 _snapshot) external {
        activeCommitteeSnapshot = _snapshot;
    }
}

/// @notice Actual Registry lifecycle using only published public registration PoPs.
/// @dev Deliberately imports Vm, never Test/CommonTest or any historical replay base.
contract EtnaRegistryPublicReplayTest {
    Vm private constant _VM = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
    address private constant _REGISTRY = 0x2222222222222222222222222222222222222222;
    address private constant _AA = 0xaAaAaAaaAaAaAaaAaAAAAAAAAaaaAaAaAaaAaaAa;
    address private constant _BB = 0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB;
    address private constant _ADMIN = address(0x3333);
    address private constant _PUBLIC = address(0x4444);
    address private constant _SINK = address(0x5555);
    address private constant _PAYEE = address(0x6666);
    uint256 private constant _R =
        0x46e4e2fea4a7d0ac18aca03baa3a1f64e1be04ec23c1ca0c7b901af7b59b8000;
    uint256 private constant _OWNERS =
        0x39c9f3adc28a427dc5a3705913196a8ee3e586999e5fd34170cb091706065d00;
    uint256 private constant _CONFIRM =
        0x25e74f824855a18216fe2fa8b7d9dcc76ad83f6de1a344c666c3293e57124900;
    uint256 private constant _TOP =
        0x3a1aea98c955969894fa1164a9cf4fb395d732d0191953a25567edb8a7c00400;
    uint256 private constant _FORFEIT =
        0xdfeb3c25dc200ebc2d2e4944bf5b28b239af40d34f2491dee100754230b61400;
    uint256 private constant _NO_EXIT = type(uint48).max;
    bytes32 private constant _IMPLEMENTATION =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    struct LiteralEntry {
        bytes32 x;
        uint256 stake;
        uint256 prefix;
        uint256 active;
        uint256 exit;
    }

    struct LiteralCheckpoint {
        uint256 atBlock;
        uint256 count;
        bytes32 root;
    }
    LiteralEntry[6] private _entries;
    LiteralCheckpoint[] private _history;
    uint256 private _count;
    string private _fixture;
    EtnaStakingRegistry private _registry;
    PublicReplayToken private _token;
    PublicReplayInbox private _inbox;

    /// @dev Only code placement and proxy implementation pointer are cheatcode-written.
    function _setup(uint256 _bps) private {
        _VM.chainId(1);
        _VM.roll(10);
        _VM.warp(1000);
        _token = new PublicReplayToken();
        _inbox = new PublicReplayInbox();
        EtnaStakingRegistry implementation = new EtnaStakingRegistry(
            IEtnaStakingRegistry.Config({
                token: address(_token),
                minStake: 4,
                activationDelay: 2,
                exitDelay: 2,
                withdrawalDelay: 2,
                slashBountyBps: 0,
                slashSink: _SINK,
                l2ChainId: 167,
                inbox: address(_inbox),
                forfeitBps: _bps
            })
        );
        ERC1967Proxy placed = new ERC1967Proxy(address(implementation), "");
        _VM.etch(_REGISTRY, address(placed).code);
        _VM.store(_REGISTRY, _IMPLEMENTATION, bytes32(uint256(uint160(address(implementation)))));
        _registry = EtnaStakingRegistry(_REGISTRY);
        _registry.init(_ADMIN);
        require(_registry.owner() == _ADMIN, "public setup: actual initialization");
        _fixture =
            _VM.readFile("test/layer1/etna/conformance/vectors/registry_public/registration.json");
        require(
            _VM.parseJsonUint(_fixture, ".deployment.l1_chain_id") == 1, "public fixture: chain"
        );
        require(
            _VM.parseJsonAddress(_fixture, ".deployment.registry") == _REGISTRY,
            "public fixture: address"
        );
        for (uint256 i; i < 12; ++i) {
            string memory p = _row(i);
            address owner = _VM.parseJsonAddress(_fixture, string.concat(p, ".owner"));
            require(
                _registry.registerDigest(owner)
                    == _VM.parseJsonBytes32(_fixture, string.concat(p, ".digest")),
                "public domain: published digest"
            );
        }
        _token.mint(_AA, 100);
        _token.mint(_BB, 100);
        _VM.prank(_AA);
        _token.approve(_REGISTRY, 100);
        _VM.prank(_BB);
        _token.approve(_REGISTRY, 100);
    }

    /// @notice Executes all six owner-AA public proofs, including the leading-zero X point.
    function test_public_allPublishedOwnerAAPoPs() external {
        _allPoPs(0);
    }

    /// @notice Executes all six owner-BB public proofs independently on fresh state.
    function test_public_allPublishedOwnerBBPoPs() external {
        _allPoPs(1);
    }

    /// @dev Each actual registration is checked before advancing; same-block coalescing is real.
    function _allPoPs(uint256 _offset) private {
        _setup(5000);
        _refuse(
            _BB,
            abi.encodeCall(
                _registry.register,
                (
                    _VM.parseJsonBytes(_fixture, ".register_digests[0].key"),
                    uint256(4),
                    _VM.parseJsonBytes(_fixture, ".register_digests[0].pop_sig")
                )
            ),
            IEtnaStakingRegistry.InvalidSignature.selector
        );
        for (uint256 i; i < 6; ++i) {
            _register(2 * i + _offset);
        }
        require(_count == 6 && _history.length == 1, "public progress: all six PoPs");
        _at(12);
        address owner = _offset == 0 ? _AA : _BB;
        _topUp(owner, 0, 4, 14);
        _at(14);
        _activate(0, 4);
        require(_history.length == 2, "public progress: later mutation");
        _checkHistory();
    }

    /// @notice Repeated legal held-slot top-ups reach 12 effective, zero pending principal.
    function test_public_repeatedActivationAndClosedHistory() external {
        _setup(5000);
        _register(0);
        _at(12);
        _topUp(_AA, 0, 4, 14);
        _principal(4, 4, 14, 8, 0, 8, 0);
        _at(13);
        _refuse(
            _PUBLIC,
            abi.encodeCall(_registry.activateTopUp, (0)),
            IEtnaStakingRegistry.TopUpNotReady.selector
        );
        _at(14);
        _activate(0, 4);
        _principal(8, 0, 0, 8, 0, 8, 0);
        _at(15);
        _topUp(_AA, 0, 4, 17);
        _principal(8, 4, 17, 12, 0, 12, 0);
        _at(17);
        _activate(0, 4);
        _principal(12, 0, 0, 12, 0, 12, 0);
        require(_history.length == 3, "public progress: second activation");
        _checkHistory();
    }

    /// @notice Pending maturity is not activation; forfeiture crosses effective into pending.
    function test_public_pendingLiabilityConfirmationAndPayout() external {
        _setup(5000);
        _register(0);
        _at(12);
        _topUp(_AA, 0, 12, 14);
        _at(14);
        _principal(4, 12, 14, 16, 0, 16, 0);
        _checkHistory();
        require(_history.length == 1, "public history: maturity writes nothing");
        _at(15);
        _forfeit(8);
        _principal(0, 8, 14, 8, 8, 16, 0);
        _inbox.setSnapshot(14);
        _at(16);
        _refuse(
            _PUBLIC,
            abi.encodeCall(_registry.confirmExit, (0)),
            IEtnaStakingRegistry.ExitNotCovered.selector
        );
        _inbox.setSnapshot(15);
        _VM.recordLogs();
        _VM.prank(_PUBLIC);
        _registry.confirmExit(0);
        _events(_one(_bondEvent("ExitConfirmed(uint256,uint256)", 0, abi.encode(uint256(16)))));
        require(_rawMap(_CONFIRM, 0) == bytes32(uint256(16)), "public confirmation: first block");
        _at(17);
        _VM.pauseGasMetering();
        bytes32 confirmedState = _stateDigest();
        _VM.resumeGasMetering();
        _VM.recordLogs();
        _VM.prank(_PUBLIC);
        _registry.confirmExit(0);
        require(
            _rawMap(_CONFIRM, 0) == bytes32(uint256(16)),
            "public confirmation: first block preserved"
        );
        _VM.pauseGasMetering();
        bytes32 repeatedState = _stateDigest();
        _VM.resumeGasMetering();
        require(repeatedState == confirmedState, "public confirmation: complete no-op equality");
        _events(new bytes32[](0));
        _refuse(
            _AA,
            abi.encodeCall(_registry.withdraw, (0, _PAYEE)),
            IEtnaStakingRegistry.WithdrawalNotReady.selector
        );
        _refuse(
            _AA,
            abi.encodeCall(_registry.topUp, (0, 1)),
            IEtnaStakingRegistry.TopUpNotAllowed.selector
        );
        _at(18);
        _refuse(
            _PUBLIC,
            abi.encodeCall(_registry.withdraw, (0, _PAYEE)),
            IEtnaStakingRegistry.NotBondOwner.selector
        );
        _withdraw(_AA, _PAYEE, 8);
        _principal(0, 0, 0, 0, 8, 16, 8);
        _afterWithdrawal();
        require(_history.length == 3, "public progress: liability paid");
    }

    /// @notice An independent 10000bps fixture permits public zero-principal withdrawal.
    function test_public_fullForfeitPublicZeroWithdrawal() external {
        _setup(10_000);
        _register(0);
        _at(15);
        _forfeit(4);
        _principal(0, 0, 0, 0, 4, 4, 0);
        _inbox.setSnapshot(15);
        _at(16);
        _VM.recordLogs();
        _VM.prank(_PUBLIC);
        _registry.confirmExit(0);
        _events(_one(_bondEvent("ExitConfirmed(uint256,uint256)", 0, abi.encode(uint256(16)))));
        _at(18);
        _withdraw(_PUBLIC, address(0), 0);
        _principal(0, 0, 0, 0, 4, 4, 0);
        _afterWithdrawal();
        require(_token.transfers() == 2, "public payout: no zero transfer");
    }

    /// @dev Real PoP validation, literal issued/key/slot identity and full exact event stream.
    function _register(uint256 _rowIndex) private {
        uint256 id = _count;
        string memory p = _row(_rowIndex);
        string memory k = string.concat(".keys[", _VM.toString(_rowIndex / 2), "]");
        address owner = _VM.parseJsonAddress(_fixture, string.concat(p, ".owner"));
        bytes memory key = _VM.parseJsonBytes(_fixture, string.concat(p, ".key"));
        bytes memory pop = _VM.parseJsonBytes(_fixture, string.concat(p, ".pop_sig"));
        bytes32 x = _VM.parseJsonBytes32(_fixture, string.concat(k, ".ck_x"));
        uint256 prefix = _VM.parseJsonUint(_fixture, string.concat(k, ".ck_prefix"));
        address ck = _VM.parseJsonAddress(_fixture, string.concat(k, ".ck_addr"));
        require(
            keccak256(key) == keccak256(abi.encodePacked(uint8(prefix), x)),
            "public key: canonical bytes"
        );
        require(
            address(
                uint160(
                    uint256(
                        keccak256(
                            abi.encodePacked(
                                x, _VM.parseJsonBytes32(_fixture, string.concat(k, ".ck_y"))
                            )
                        )
                    )
                )
            ) == ck,
            "public key: published address"
        );
        require(
            keccak256(abi.encode(prefix, x))
                == _VM.parseJsonBytes32(_fixture, string.concat(k, ".entry_key")),
            "public key: lifetime identity"
        );
        require(
            _registry.registerDigest(owner)
                == _VM.parseJsonBytes32(_fixture, string.concat(p, ".digest")),
            "public domain: before actual register"
        );
        _VM.recordLogs();
        _VM.prank(owner);
        uint256 actualId = _registry.register(key, 4, pop);
        require(actualId == id, "public identity: issued id");
        _entries[id] = LiteralEntry(x, 4, prefix, 12, _NO_EXIT);
        ++_count;
        _rememberCheckpoint();
        bytes32[] memory expected = new bytes32[](3);
        expected[0] = _checkpointEvent();
        expected[1] = _transferEvent(owner, _REGISTRY, 4);
        bytes32[] memory topics = new bytes32[](4);
        topics[0] = keccak256("Registered(uint256,address,address,uint8,bytes32,uint256,uint48)");
        topics[1] = bytes32(id);
        topics[2] = bytes32(uint256(uint160(owner)));
        topics[3] = bytes32(uint256(uint160(ck)));
        expected[2] =
            _eventHash(_REGISTRY, topics, abi.encode(uint8(prefix), x, uint256(4), uint48(12)));
        _events(expected);
        require(_raw(_R + 7) == bytes32(_count), "public identity: issued count");
        require(
            _rawMap(_R + 4, uint256(uint160(ck))) == bytes32(id + 1),
            "public identity: lifetime key"
        );
        require(_rawMap(_R + 5, id) == bytes32(id + 1), "public identity: held slot");
        require(_rawMap(_OWNERS, id) == bytes32(uint256(uint160(owner))), "public identity: owner");
        require(
            _token.balanceOf(owner) == 100 - 4 * _count
                && _token.balanceOf(_REGISTRY) == 4 * _count,
            "public cash: registration ledger"
        );
        require(
            _token.allowance(owner, _REGISTRY) == 100 - 4 * _count && _token.transfers() == _count,
            "public cash: registration transfers"
        );
        _checkEntries();
        _checkHistory();
    }

    /// @dev Deposit changes admission principal, not entry/checkpoint history.
    function _topUp(address _owner, uint256 _id, uint256 _amount, uint256 _ready) private {
        bytes32 root = _root();
        _VM.recordLogs();
        _VM.prank(_owner);
        _registry.topUp(_id, _amount);
        bytes32[] memory expected = new bytes32[](2);
        expected[0] = _transferEvent(_owner, _REGISTRY, _amount);
        expected[1] = _bondEvent(
            "TopUpDeposited(uint256,uint256,uint48)", _id, abi.encode(_amount, uint48(_ready))
        );
        _events(expected);
        require(_rawMap(_TOP, _id) == bytes32(_amount), "public ledger: deposited pending");
        require(
            _raw(uint256(keccak256(abi.encode(_id, _TOP))) + 1) == bytes32(_ready),
            "public readiness: deposit"
        );
        require(_registry.entriesRoot() == root, "public history: top-up no entry write");
        _checkEntries();
        _checkHistory();
    }

    /// @dev Public activation invokes the original action and compares a literal changed entry.
    function _activate(uint256 _id, uint256 _amount) private {
        _VM.recordLogs();
        _VM.prank(_PUBLIC);
        _registry.activateTopUp(_id);
        _entries[_id].stake += _amount;
        _rememberCheckpoint();
        bytes32[] memory expected = new bytes32[](2);
        expected[0] = _checkpointEvent();
        expected[1] = _bondEvent("TopUpActivated(uint256,uint256)", _id, abi.encode(_amount));
        _events(expected);
        require(
            _rawMap(_TOP, _id) == 0 && _raw(uint256(keccak256(abi.encode(_id, _TOP))) + 1) == 0,
            "public ledger: activation clears pending"
        );
        _checkEntries();
        _checkHistory();
    }

    /// @dev Penalty constants are supplied by the literal 16/8 and 4/4 ledgers.
    function _forfeit(uint256 _penalty) private {
        bytes32 key = keccak256(abi.encode(_entries[0].prefix, _entries[0].x));
        _VM.recordLogs();
        _VM.prank(_ADMIN);
        _registry.forfeit(0, key, bytes32(uint256(77)), 1060);
        _entries[0].stake = 0;
        _entries[0].exit = 15;
        _rememberCheckpoint();
        bytes32[] memory expected = new bytes32[](3);
        expected[0] = _checkpointEvent();
        expected[1] = _transferEvent(_REGISTRY, _SINK, _penalty);
        bytes32[] memory topics = new bytes32[](3);
        topics[0] = keccak256("Forfeited(uint256,bytes32,bytes32,uint256,uint256)");
        topics[1] = 0;
        topics[2] = key;
        expected[2] = _eventHash(
            _REGISTRY, topics, abi.encode(bytes32(uint256(77)), _penalty == 8 ? 16 : 4, _penalty)
        );
        _events(expected);
        require(
            _rawMap(_FORFEIT, uint256(key)) == bytes32(uint256(1)),
            "public identity: lifetime forfeiture"
        );
        _checkEntries();
        _checkHistory();
    }

    /// @dev Positive owner payout or public zero payout; empty slot still has a canonical leaf.
    function _withdraw(address _caller, address _to, uint256 _amount) private {
        _VM.recordLogs();
        _VM.prank(_caller);
        _registry.withdraw(0, _to);
        delete _entries[0];
        _rememberCheckpoint();
        bytes32[] memory expected = new bytes32[](_amount == 0 ? 2 : 3);
        expected[0] = _checkpointEvent();
        if (_amount != 0) expected[1] = _transferEvent(_REGISTRY, _to, _amount);
        bytes32[] memory topics = new bytes32[](3);
        topics[0] = keccak256("StakeWithdrawn(uint256,address,uint256)");
        topics[1] = 0;
        topics[2] = bytes32(uint256(uint160(_to)));
        expected[expected.length - 1] = _eventHash(_REGISTRY, topics, abi.encode(_amount));
        _events(expected);
        _checkEntries();
        _checkHistory();
    }

    /// @dev Raw principal plus independent cash conservation, never a derived Registry getter.
    function _principal(
        uint256 _eff,
        uint256 _pending,
        uint256 _ready,
        uint256 _custody,
        uint256 _sink,
        uint256 _spent,
        uint256 _paid
    )
        private
        view
    {
        uint256 bond = uint256(keccak256(abi.encode(uint256(0), _R + 6)));
        require(_raw(bond + 1) == bytes32(_eff), "public ledger: effective principal");
        require(_rawMap(_TOP, 0) == bytes32(_pending), "public ledger: pending principal");
        require(
            _raw(uint256(keccak256(abi.encode(uint256(0), _TOP))) + 1) == bytes32(_ready),
            "public ledger: readiness"
        );
        require(
            _token.balanceOf(_REGISTRY) == _custody && _custody == _eff + _pending,
            "public cash: custody backs liability"
        );
        require(
            _token.balanceOf(_SINK) == _sink && _token.balanceOf(_PAYEE) == _paid,
            "public cash: destinations"
        );
        require(
            _token.balanceOf(_AA) == 100 - _spent && _token.balanceOf(_BB) == 100,
            "public cash: owner deposit"
        );
        require(_custody + _sink + _paid == _spent, "public cash: conservation");
        require(_token.allowance(_AA, _REGISTRY) == 100 - _spent, "public cash: consumed allowance");
    }

    /// @dev Permanent bond/key identity remains while all withdrawable business fields clear.
    function _afterWithdrawal() private {
        uint256 bond = uint256(keccak256(abi.encode(uint256(0), _R + 6)));
        bytes32 x = _VM.parseJsonBytes32(_fixture, ".keys[0].ck_x");
        address ck = _VM.parseJsonAddress(_fixture, ".keys[0].ck_addr");
        require(
            _raw(bond) == x && _raw(bond + 2) == bytes32(uint256(3) | (12 << 8) | (15 << 56)),
            "public identity: retained entry"
        );
        require(
            _raw(bond + 3) == bytes32(uint256(1 << 24)), "public identity: withdrawn no held slot"
        );
        require(_raw(_R + 7) == bytes32(uint256(1)), "public identity: issued forever");
        require(
            _rawMap(_R + 4, uint256(uint160(ck))) == bytes32(uint256(1)),
            "public identity: key forever"
        );
        require(
            _rawMap(_R + 5, 0) == 0 && _rawMap(_OWNERS, 0) == 0 && _rawMap(_CONFIRM, 0) == 0,
            "public withdrawal: clear metadata"
        );
        require(
            _rawMap(_FORFEIT, uint256(keccak256(abi.encode(uint256(3), x)))) == bytes32(uint256(1)),
            "public identity: forfeiture forever"
        );
        _refuse(
            _AA,
            abi.encodeCall(_registry.withdraw, (0, _PAYEE)),
            IEtnaStakingRegistry.BondWithdrawn.selector
        );
        _refuse(
            _AA,
            abi.encodeCall(
                _registry.register,
                (
                    _VM.parseJsonBytes(_fixture, ".register_digests[0].key"),
                    uint256(4),
                    _VM.parseJsonBytes(_fixture, ".register_digests[0].pop_sig")
                )
            ),
            IEtnaStakingRegistry.KeyAlreadyUsed.selector
        );
    }

    /// @dev A complete selected bounded raw-state digest precedes and follows every failed call.
    function _refuse(address _caller, bytes memory _call, bytes4 _error) private {
        // Raw observation is deliberately outside the action gas measurement.
        _VM.pauseGasMetering();
        bytes32 beforeState = _stateDigest();
        _VM.resumeGasMetering();
        _VM.recordLogs();
        _VM.prank(_caller);
        (bool ok, bytes memory reason) = _REGISTRY.call(_call);
        require(
            !ok && keccak256(reason) == keccak256(abi.encodePacked(_error)),
            "public rejection: exact selector"
        );
        _VM.pauseGasMetering();
        bytes32 afterState = _stateDigest();
        _VM.resumeGasMetering();
        require(afterState == beforeState, "public rejection: full raw equality");
        _events(new bytes32[](0));
    }

    /// @dev Raw namespaces, bounded entries/bonds/tree/checkpoints, full admission index and token storage.
    function _stateDigest() private view returns (bytes32 h) {
        for (uint256 i; i < 251; ++i) {
            h = keccak256(abi.encode(h, _raw(i)));
        }
        h = keccak256(abi.encode(h, _VM.load(_REGISTRY, _IMPLEMENTATION)));
        for (uint256 i; i < 8; ++i) {
            h = keccak256(abi.encode(h, _raw(_R + i)));
        }
        uint256 checkpointBase = uint256(keccak256(abi.encode(_R)));
        uint256 entryBase = uint256(keccak256(abi.encode(_R + 1)));
        for (uint256 i; i < 16; ++i) {
            h = keccak256(abi.encode(h, _raw(checkpointBase + i)));
        }
        for (uint256 i; i < 18; ++i) {
            h = keccak256(abi.encode(h, _raw(entryBase + i)));
        }
        for (uint256 i; i < 8192; ++i) {
            h = keccak256(abi.encode(h, _rawMap(_R + 3, i)));
        }
        for (uint256 level; level < 4; ++level) {
            for (uint256 i; i < (8 >> level); ++i) {
                h = keccak256(abi.encode(h, _rawMap(_R + 2, (level << 32) | i)));
            }
        }
        for (uint256 i; i < 6; ++i) {
            uint256 bond = uint256(keccak256(abi.encode(i, _R + 6)));
            for (uint256 j; j < 4; ++j) {
                h = keccak256(abi.encode(h, _raw(bond + j)));
            }
            h = keccak256(
                abi.encode(
                    h,
                    _rawMap(_R + 5, i),
                    _rawMap(_OWNERS, i),
                    _rawMap(_CONFIRM, i),
                    _rawMap(_TOP, i),
                    _raw(uint256(keccak256(abi.encode(i, _TOP))) + 1)
                )
            );
            string memory k = string.concat(".keys[", _VM.toString(i), "]");
            address ck = _VM.parseJsonAddress(_fixture, string.concat(k, ".ck_addr"));
            bytes32 key = _VM.parseJsonBytes32(_fixture, string.concat(k, ".entry_key"));
            h = keccak256(
                abi.encode(
                    h, _rawMap(_R + 4, uint256(uint160(ck))), _rawMap(_FORFEIT, uint256(key))
                )
            );
        }
        address[6] memory actors = [_AA, _BB, _SINK, _PAYEE, _PUBLIC, _REGISTRY];
        for (uint256 i; i < actors.length; ++i) {
            h = keccak256(
                abi.encode(
                    h,
                    _VM.load(address(_token), keccak256(abi.encode(actors[i], uint256(0)))),
                    _VM.load(
                        address(_token),
                        keccak256(
                            abi.encode(_REGISTRY, keccak256(abi.encode(actors[i], uint256(1))))
                        )
                    )
                )
            );
        }
        h = keccak256(
            abi.encode(
                h, _VM.load(address(_token), bytes32(uint256(2))), _VM.load(address(_inbox), 0)
            )
        );
    }

    /// @dev Canonical entry encoding computed only from the literal ledger, not production helpers.
    function _root() private view returns (bytes32) {
        if (_count == 0) return 0;
        bytes32[8] memory layer;
        for (uint256 i; i < _count; ++i) {
            LiteralEntry memory e = _entries[i];
            layer[i] = keccak256(
                abi.encode(
                    bytes32("ETNA_REG_ENTRY_V1"), i, e.prefix, e.x, e.stake, e.active, e.exit
                )
            );
        }
        uint256 width = 1;
        while (width < _count) width *= 2;
        while (width > 1) {
            for (uint256 i; i < width / 2; ++i) {
                layer[i] = keccak256(abi.encodePacked(layer[2 * i], layer[2 * i + 1]));
            }
            width /= 2;
        }
        return layer[0];
    }

    /// @dev Freeze expected checkpoints on real write actions only; all historical rows are rechecked.
    function _rememberCheckpoint() private {
        LiteralCheckpoint memory c = LiteralCheckpoint(block.number, _count, _root());
        uint256 n = _history.length;
        if (n > 0 && _history[n - 1].atBlock == block.number) _history[n - 1] = c;
        else _history.push(c);
    }

    /// @dev Independent raw array encoding plus getter agreement; no getter feeds expected roots.
    function _checkHistory() private view {
        require(
            _raw(_R) == bytes32(_history.length), "public history: one checkpoint per changed block"
        );
        require(_registry.entriesRoot() == _root(), "public history: independent root");
        uint256 base = uint256(keccak256(abi.encode(_R)));
        for (uint256 i; i < _history.length; ++i) {
            LiteralCheckpoint memory c = _history[i];
            require(
                _raw(base + 2 * i) == bytes32(c.atBlock | (c.count << 48)),
                "public history: closed checkpoint header"
            );
            require(
                _raw(base + 2 * i + 1) == c.root,
                "public history: immutable literal checkpoint root"
            );
            IEtnaStakingRegistry.Checkpoint memory actual = _registry.checkpointAt(i);
            require(
                actual.l1Block == c.atBlock && actual.count == c.count
                    && actual.entriesRoot == c.root,
                "public history: checkpoint getter"
            );
        }
    }

    /// @dev Compare actual packed entries with literals, including the all-zero withdrawn slot.
    function _checkEntries() private view {
        require(_raw(_R + 1) == bytes32(_count), "public entry: count");
        uint256 base = uint256(keccak256(abi.encode(_R + 1)));
        for (uint256 i; i < _count; ++i) {
            LiteralEntry memory e = _entries[i];
            require(
                _raw(base + 3 * i) == e.x && _raw(base + 3 * i + 1) == bytes32(e.stake)
                    && _raw(base + 3 * i + 2)
                        == bytes32(e.prefix | (e.active << 8) | (e.exit << 56)),
                "public entry: literal raw fields"
            );
            if (e.x != 0) {
                uint256 bond = uint256(keccak256(abi.encode(i, _R + 6)));
                require(
                    _raw(bond) == e.x && _raw(bond + 1) == bytes32(e.stake)
                        && _raw(bond + 2) == bytes32(e.prefix | (e.active << 8) | (e.exit << 56)),
                    "public identity: bond mirrors held slot"
                );
                require(
                    _raw(bond + 3) == bytes32(i | (1 << 16)), "public identity: held bond flags"
                );
            }
        }
    }

    /// @dev Exact logs (emitter, all topics, all data), including token transfers and absent logs.
    function _events(bytes32[] memory _expected) private {
        Vm.Log[] memory logs = _VM.getRecordedLogs();
        require(logs.length == _expected.length, "public events: exact length");
        for (uint256 i; i < logs.length; ++i) {
            require(
                _eventHash(logs[i].emitter, logs[i].topics, logs[i].data) == _expected[i],
                "public events: exact fields/order"
            );
        }
    }

    function _checkpointEvent() private view returns (bytes32) {
        uint256 i = _history.length - 1;
        return _bondEvent(
            "CheckpointWritten(uint256,uint48,uint48,bytes32)",
            i,
            abi.encode(uint48(block.number), uint48(_count), _root())
        );
    }

    function _bondEvent(
        string memory _signature,
        uint256 _id,
        bytes memory _data
    )
        private
        pure
        returns (bytes32)
    {
        bytes32[] memory topics = new bytes32[](2);
        topics[0] = keccak256(bytes(_signature));
        topics[1] = bytes32(_id);
        return _eventHash(_REGISTRY, topics, _data);
    }

    function _transferEvent(
        address _from,
        address _to,
        uint256 _amount
    )
        private
        view
        returns (bytes32)
    {
        bytes32[] memory topics = new bytes32[](3);
        topics[0] = keccak256("Transfer(address,address,uint256)");
        topics[1] = bytes32(uint256(uint160(_from)));
        topics[2] = bytes32(uint256(uint160(_to)));
        return _eventHash(address(_token), topics, abi.encode(_amount));
    }

    function _eventHash(
        address _emitter,
        bytes32[] memory _topics,
        bytes memory _data
    )
        private
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(_emitter, _topics, _data));
    }

    function _one(bytes32 _event) private pure returns (bytes32[] memory items) {
        items = new bytes32[](1);
        items[0] = _event;
    }

    function _raw(uint256 _slot) private view returns (bytes32) {
        return _VM.load(_REGISTRY, bytes32(_slot));
    }

    function _rawMap(uint256 _namespace, uint256 _key) private view returns (bytes32) {
        return _raw(uint256(keccak256(abi.encode(_key, _namespace))));
    }

    /// @dev Legal increasing L1 timestamps accompany each scheduled block advance.
    function _at(uint256 _block) private {
        _VM.roll(_block);
        _VM.warp(1000 + 12 * (_block - 10));
    }

    function _row(uint256 _i) private pure returns (string memory) {
        return string.concat(".register_digests[", _VM.toString(_i), "]");
    }
}
