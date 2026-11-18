// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Vm, VmSafe } from "forge-std/src/Vm.sol";
import { IEtnaStakingRegistry } from "src/layer1/etna/iface/IEtnaStakingRegistry.sol";
import { EtnaStakingRegistry } from "src/layer1/etna/impl/EtnaStakingRegistry.sol";
import { PublicReplayToken } from "./EtnaRegistryPublicReplay.t.sol";

/// @dev Initialized, unlocked Inbox with explicit synthetic generation and snapshot.
contract RegistryCasesInbox {
    uint48 public recoveryGeneration;
    uint48 public activeCommitteeSnapshot;

    /// @notice Supplies the current recovery generation.
    function setGeneration(uint48 _generation) external {
        recoveryGeneration = _generation;
    }

    /// @notice Supplies the active committee snapshot.
    function setSnapshot(uint48 _snapshot) external {
        activeCommitteeSnapshot = _snapshot;
    }

    /// @notice Reports the initialized premise.
    function isInitialized() external pure returns (bool) {
        return true;
    }

    /// @notice Reports the unlocked premise.
    function inNonReentrant() external pure returns (bool) {
        return false;
    }
}

/// @dev Shared public fixture. State is constructed by the actual Registry entry points.
abstract contract EtnaRegistryCasesBase {
    Vm internal constant VM = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
    address internal constant INBOX = 0x1111111111111111111111111111111111111111;
    address internal constant REGISTRY = 0x2222222222222222222222222222222222222222;
    address internal constant OWNER_A = 0xaAaAaAaaAaAaAaaAaAAAAAAAAaaaAaAaAaaAaaAa;
    address internal constant OWNER_B = 0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB;
    address internal constant ADMIN = address(0x3333);
    address internal constant REPORTER = address(0x4444);
    address internal constant SINK = address(0x5555);
    address internal constant PAYEE = address(0x6666);
    uint64 internal constant L2_CHAIN_ID = 167001;
    uint48 internal constant NO_EXIT = type(uint48).max;

    uint256 internal constant R = 0x46e4e2fea4a7d0ac18aca03baa3a1f64e1be04ec23c1ca0c7b901af7b59b8000;
    uint256 internal constant OWNERS = 0x39c9f3adc28a427dc5a3705913196a8ee3e586999e5fd34170cb091706065d00;
    uint256 internal constant CONFIRM = 0x25e74f824855a18216fe2fa8b7d9dcc76ad83f6de1a344c666c3293e57124900;
    uint256 internal constant TOP = 0x3a1aea98c955969894fa1164a9cf4fb395d732d0191953a25567edb8a7c00400;
    uint256 internal constant FORFEIT = 0xdfeb3c25dc200ebc2d2e4944bf5b28b239af40d34f2491dee100754230b61400;
    bytes32 private constant _IMPLEMENTATION =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    struct PublicPoP {
        address owner;
        address signer;
        uint8 prefix;
        bytes32 x;
        bytes32 entryKey;
        bytes key;
        bytes signature;
    }

    struct CallResult {
        bool ok;
        bytes data;
        Vm.Log[] logs;
        Vm.AccountAccess[] accesses;
    }

    EtnaStakingRegistry internal registry;
    PublicReplayToken internal token;
    RegistryCasesInbox internal inbox;
    address internal implementation;
    string private _registration;
    address[6] private _signers;
    bytes32[6] private _keys;

    event RegistryCaseReceipt(bytes payload);

    /// @dev Place the Inbox before construction; seed only ERC1967's implementation pointer.
    function _setupRegistry(uint48 _generation) internal {
        VM.chainId(1);
        VM.roll(10);
        VM.warp(1000);
        token = new PublicReplayToken();
        VM.etch(INBOX, address(new RegistryCasesInbox()).code);
        inbox = RegistryCasesInbox(INBOX);
        inbox.setGeneration(_generation);
        implementation = address(new EtnaStakingRegistry(IEtnaStakingRegistry.Config({
            token: address(token),
            minStake: 4,
            activationDelay: 2,
            exitDelay: 2,
            withdrawalDelay: 2,
            slashBountyBps: 2500,
            slashSink: SINK,
            l2ChainId: L2_CHAIN_ID,
            inbox: INBOX,
            forfeitBps: 5000
        })));
        VM.etch(REGISTRY, address(new ERC1967Proxy(implementation, "")).code);
        VM.store(REGISTRY, _IMPLEMENTATION, bytes32(uint256(uint160(implementation))));
        registry = EtnaStakingRegistry(REGISTRY);
        registry.init(ADMIN);
        require(
            block.chainid == 1 && registry.owner() == ADMIN && registry.inbox() == INBOX
                && registry.l2ChainId() == L2_CHAIN_ID && address(registry.token()) == address(token)
                && registry.minStake() == 4 && registry.activationDelay() == 2
                && registry.exitDelay() == 2 && registry.withdrawalDelay() == 2
                && registry.slashBountyBps() == 2500 && registry.slashSink() == SINK
                && registry.forfeitBps() == 5000 && inbox.isInitialized()
                && !inbox.inNonReentrant() && inbox.recoveryGeneration() == _generation,
            "registry setup: immutable deployment and initialized premises"
        );
        _registration = VM.readFile("test/layer1/etna/conformance/vectors/registry_public/registration.json");
        require(
            VM.parseJsonUint(_registration, ".deployment.l1_chain_id") == block.chainid
                && VM.parseJsonAddress(_registration, ".deployment.registry") == REGISTRY,
            "registry setup: published registration deployment"
        );
        for (uint256 i; i < _signers.length; ++i) {
            string memory keyPath = _rowPath(".keys", i);
            _signers[i] = VM.parseJsonAddress(_registration, string.concat(keyPath, ".ck_addr"));
            _keys[i] = VM.parseJsonBytes32(_registration, string.concat(keyPath, ".entry_key"));
        }
    }

    /// @dev Decode one named public proof row and verify its digest and stored-key literals.
    function _publicPoP(uint256 _index) internal view returns (PublicPoP memory pop) {
        string memory row = _rowPath(".register_digests", _index);
        string memory key = _rowPath(".keys", _index / 2);
        pop.owner = VM.parseJsonAddress(_registration, string.concat(row, ".owner"));
        pop.key = VM.parseJsonBytes(_registration, string.concat(row, ".key"));
        pop.signature = VM.parseJsonBytes(_registration, string.concat(row, ".pop_sig"));
        pop.signer = _signers[_index / 2];
        pop.entryKey = _keys[_index / 2];
        pop.prefix = uint8(VM.parseJsonUint(_registration, string.concat(key, ".ck_prefix")));
        pop.x = VM.parseJsonBytes32(_registration, string.concat(key, ".ck_x"));
        bytes32 y = VM.parseJsonBytes32(_registration, string.concat(key, ".ck_y"));

        require(
            registry.registerDigest(pop.owner)
                == VM.parseJsonBytes32(_registration, string.concat(row, ".digest")),
            "registry domain: published registration digest"
        );
        require(
            keccak256(pop.key) == keccak256(abi.encodePacked(pop.prefix, pop.x))
                && address(uint160(uint256(keccak256(abi.encodePacked(pop.x, y))))) == pop.signer
                && keccak256(abi.encode(pop.prefix, pop.x)) == pop.entryKey,
            "registry key: public point and lifetime identity"
        );
    }

    /// @dev Use a genuine public proof with the actual register entry point.
    function _register(PublicPoP memory _pop, uint256 _amount) internal returns (uint256) {
        VM.prank(_pop.owner);
        return registry.register(_pop.key, _amount, _pop.signature);
    }

    /// @dev Externally fund/approve the synthetic token before a test action.
    function _fund(address _owner, uint256 _minted, uint256 _approved) internal {
        token.mint(_owner, _minted);
        VM.prank(_owner);
        require(token.approve(REGISTRY, _approved), "registry token: approval");
    }

    /// @dev Array-path helper for the two pinned public JSON projections.
    function _rowPath(string memory _array, uint256 _index) internal pure returns (string memory) {
        return string.concat(_array, "[", VM.toString(_index), "]");
    }

    /// @dev Capture raw low-level result, trace logs and ordered accesses around the action only.
    function _callRegistry(address _actor, bytes memory _calldata) internal returns (CallResult memory result) {
        VM.recordLogs();
        VM.startStateDiffRecording();
        VM.prank(_actor);
        (result.ok, result.data) = REGISTRY.call(_calldata);
        result.accesses = VM.stopAndReturnStateDiff();
        result.logs = VM.getRecordedLogs();
    }

    /// @dev Match the proxy and its immediate implementation frame to the exact attempted calldata.
    /// The pinned Vm recorder reports the inherited caller as the delegated accessor.
    function _registryFrame(CallResult memory _result, address _actor, bytes memory _calldata)
        internal
        view
        returns (address proxy, bytes memory observedData)
    {
        bytes32 dataHash = keccak256(_calldata);
        uint256 frames;
        uint64 callDepth;
        for (uint256 i; i < _result.accesses.length; ++i) {
            Vm.AccountAccess memory access = _result.accesses[i];
            if (access.kind == VmSafe.AccountAccessKind.Call && access.account == REGISTRY) {
                require(
                    frames == 0 && access.reverted != _result.ok
                        && keccak256(access.data) == dataHash,
                    "registry origin: exact proxy call"
                );
                callDepth = access.depth;
                proxy = access.account;
                ++frames;
            }
            if (access.kind == VmSafe.AccountAccessKind.DelegateCall && access.account == implementation) {
                require(
                    frames == 1 && access.accessor == _actor && access.depth == callDepth + 1
                        && access.reverted != _result.ok && keccak256(access.data) == dataHash,
                    "registry origin: exact delegated implementation call"
                );
                observedData = access.data;
                ++frames;
            }
        }
        require(frames == 2, "registry origin: missing proxy or implementation frame");
    }

    /// @dev Exact error bytes and raw rollback. Caller supplies the expected trace logs.
    function _requireRefusal(
        CallResult memory _actual,
        bytes memory _error,
        bytes32 _before,
        bytes32 _after,
        bytes32[] memory _traceLogs
    )
        internal
        pure
    {
        require(!_actual.ok && keccak256(_actual.data) == keccak256(_error), "registry refusal: exact error bytes");
        require(_before == _after, "registry refusal: raw rollback equality");
        _requireEvents(_actual.logs, _traceLogs);
    }

    /// @dev Read a raw Registry slot or mapping word using the pinned storage layout.
    function _raw(uint256 _slot) internal view returns (bytes32) {
        return VM.load(REGISTRY, bytes32(_slot));
    }

    /// @dev Resolve a numeric mapping key without reading a Registry getter.
    function _mapSlot(uint256 _base, uint256 _key) internal pure returns (uint256) {
        return uint256(keccak256(abi.encode(_key, _base)));
    }

    /// @dev Read a raw mapping word.
    function _rawMap(uint256 _base, uint256 _key) internal view returns (bytes32) {
        return _raw(_mapSlot(_base, _key));
    }

    /// @dev Raw exact-transfer token balance for a named account.
    function _balance(address _actor) internal view returns (uint256) {
        return uint256(VM.load(address(token), keccak256(abi.encode(_actor, uint256(0)))));
    }

    /// @dev Raw exact-transfer token allowance to the Registry.
    function _allowance(address _actor) internal view returns (uint256) {
        return uint256(VM.load(address(token), keccak256(abi.encode(REGISTRY, keccak256(abi.encode(_actor, uint256(1)))))));
    }

    /// @dev Raw transfer counter stored in the exact-transfer token fixture.
    function _transfers() internal view returns (uint256) {
        return uint256(VM.load(address(token), bytes32(uint256(2))));
    }

    /// @dev Digest the bounded fixture slots and all 8192 admission cells, outside measured action gas.
    function _stateDigest() internal returns (bytes32 h) {
        VM.pauseGasMetering();
        for (uint256 i; i < 251; ++i) h = keccak256(abi.encode(h, _raw(i)));
        h = keccak256(abi.encode(h, VM.load(REGISTRY, _IMPLEMENTATION), VM.load(INBOX, 0)));
        for (uint256 i; i < 8; ++i) h = keccak256(abi.encode(h, _raw(R + i)));
        uint256 checkpoints = uint256(keccak256(abi.encode(R)));
        uint256 entries = uint256(keccak256(abi.encode(R + 1)));
        for (uint256 i; i < 16; ++i) h = keccak256(abi.encode(h, _raw(checkpoints + i)));
        for (uint256 i; i < 18; ++i) h = keccak256(abi.encode(h, _raw(entries + i)));
        for (uint256 i; i < 8192; ++i) h = keccak256(abi.encode(h, _rawMap(R + 3, i)));
        for (uint256 level; level <= 12; ++level) {
            uint256 width = level < 3 ? 8 >> level : 1;
            for (uint256 index; index < width; ++index) {
                h = keccak256(abi.encode(h, _rawMap(R + 2, (level << 32) | index)));
            }
        }
        for (uint256 i; i < _signers.length; ++i) {
            uint256 bond = _mapSlot(R + 6, i);
            for (uint256 j; j < 4; ++j) h = keccak256(abi.encode(h, _raw(bond + j)));
            h = keccak256(abi.encode(
                h, _rawMap(R + 5, i), _rawMap(OWNERS, i), _rawMap(CONFIRM, i), _rawMap(TOP, i),
                _raw(_mapSlot(TOP, i) + 1), _rawMap(R + 4, uint160(_signers[i])),
                _rawMap(FORFEIT, uint256(_keys[i]))
            ));
        }
        address[7] memory actors = [OWNER_A, OWNER_B, REPORTER, SINK, PAYEE, REGISTRY, ADMIN];
        for (uint256 i; i < actors.length; ++i) {
            h = keccak256(abi.encode(h, _balance(actors[i]), _allowance(actors[i])));
        }
        h = keccak256(abi.encode(h, _transfers()));
        VM.resumeGasMetering();
    }

    /// @dev Independent ENC-A-37 entry leaf, including the canonical empty-slot leaf.
    function _leaf(uint256 _slot, IEtnaStakingRegistry.Entry memory _e) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            bytes32("ETNA_REG_ENTRY_V1"), _slot, _e.ckPrefix, _e.ckX, _e.effStake,
            _e.activeFromL1, _e.exitEffectiveL1
        ));
    }

    /// @dev Check exact three-word layout for a bond entry or slot array entry.
    function _requireEntry(uint256 _base, IEtnaStakingRegistry.Entry memory _e) internal view {
        require(
            _raw(_base) == _e.ckX && _raw(_base + 1) == bytes32(_e.effStake)
                && _raw(_base + 2) == bytes32(uint256(_e.ckPrefix)
                    | uint256(_e.activeFromL1) << 8 | uint256(_e.exitEffectiveL1) << 56),
            "registry entry: literal packed fields"
        );
    }

    /// @dev Check the two raw checkpoint words and the matching public getter.
    function _requireCheckpoint(uint256 _index, uint48 _block, uint48 _count, bytes32 _root) internal view {
        uint256 base = uint256(keccak256(abi.encode(R))) + 2 * _index;
        require(
            _raw(base) == bytes32(uint256(_block) | uint256(_count) << 48) && _raw(base + 1) == _root,
            "registry history: exact raw checkpoint words"
        );
        IEtnaStakingRegistry.Checkpoint memory got = registry.checkpointAt(_index);
        require(
            got.l1Block == _block && got.count == _count && got.entriesRoot == _root,
            "registry history: exact checkpoint getter"
        );
    }

    /// @dev Digest emitter, all topics and ABI data for exact trace comparison.
    function _event(address _emitter, bytes32[] memory _topics, bytes memory _data) internal pure returns (bytes32) {
        return keccak256(abi.encode(_emitter, _topics, _data));
    }

    /// @dev Expected CheckpointWritten log for a caller-supplied independent root.
    function _checkpointEvent(uint256 _index, uint48 _block, uint48 _count, bytes32 _root)
        internal
        pure
        returns (bytes32)
    {
        bytes32[] memory topics = new bytes32[](2);
        topics[0] = keccak256("CheckpointWritten(uint256,uint48,uint48,bytes32)");
        topics[1] = bytes32(_index);
        return _event(REGISTRY, topics, abi.encode(_block, _count, _root));
    }

    /// @dev Expected exact-transfer token Transfer log.
    function _transferEvent(address _from, address _to, uint256 _amount) internal view returns (bytes32) {
        bytes32[] memory topics = new bytes32[](3);
        topics[0] = keccak256("Transfer(address,address,uint256)");
        topics[1] = bytes32(uint256(uint160(_from)));
        topics[2] = bytes32(uint256(uint160(_to)));
        return _event(address(token), topics, abi.encode(_amount));
    }

    /// @dev Assert exact ordered trace logs. The caller determines whether attempted logs may remain.
    function _requireEvents(Vm.Log[] memory _logs, bytes32[] memory _expected) internal pure {
        require(_logs.length == _expected.length, "registry events: exact trace length");
        for (uint256 i; i < _logs.length; ++i) {
            Vm.Log memory got = _logs[i];
            require(
                _event(got.emitter, got.topics, got.data) == _expected[i],
                "registry events: exact ordered emitter, topics, data"
            );
        }
    }
}
