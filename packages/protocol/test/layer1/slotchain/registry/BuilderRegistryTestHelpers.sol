// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { BuilderRegistry } from "../../../../contracts/layer1/slotchain/impl/BuilderRegistry.sol";
import { SlotChainTypes } from "../../../../contracts/shared/slotchain/SlotChainTypes.sol";
import {
    LibSlotChainEncoding
} from "../../../../contracts/shared/slotchain/libs/LibSlotChainEncoding.sol";

/// @dev Deploys raw Registry init code with CREATE and doubles as the pinned activator.
contract BuilderRegistryDeployHarness {
    function deploy(bytes calldata _initCode) external returns (address deployed_) {
        bytes memory initCode = _initCode;
        assembly ("memory-safe") {
            deployed_ := create(0, add(initCode, 32), mload(initCode))
            if iszero(deployed_) {
                let size := returndatasize()
                let ptr := mload(0x40)
                returndatacopy(ptr, 0, size)
                revert(ptr, size)
            }
        }
    }

    function activate(address _registry) external {
        BuilderRegistry(_registry).activateRegistryV1();
    }
}

library BuilderRegistryMerkleTracker {
    uint8 internal constant REGISTRY = 1;
    uint8 internal constant ADMISSION = 2;
    uint8 internal constant TRANCHE = 3;

    struct Tree {
        bytes32[] nodes;
        uint16 leafCount;
        uint8 kind;
    }

    function emptyRegistryTree() internal pure returns (Tree memory tree_) {
        tree_ = _emptyTree(64, REGISTRY);
    }

    function emptyAdmissionTree() internal pure returns (Tree memory tree_) {
        tree_ = _emptyTree(2048, ADMISSION);
    }

    function emptyTrancheTree() internal pure returns (Tree memory tree_) {
        tree_ = _emptyTree(512, TRANCHE);
    }

    function root(Tree memory _tree) internal pure returns (bytes32 root_) {
        return _tree.nodes[1];
    }

    function proof(
        Tree memory _tree,
        uint16 _index
    )
        internal
        pure
        returns (bytes32[] memory siblings_)
    {
        if (_index >= _tree.leafCount) revert InvalidTestTreeIndex();
        uint256 depth = _depth(_tree.leafCount);
        siblings_ = new bytes32[](depth);
        uint256 position = uint256(_tree.leafCount) + _index;
        for (uint256 height; height < depth; ++height) {
            siblings_[height] = _tree.nodes[position ^ 1];
            position >>= 1;
        }
    }

    function update(Tree memory _tree, uint16 _index, bytes32 _leaf) internal pure {
        if (_index >= _tree.leafCount) revert InvalidTestTreeIndex();
        uint256 position = uint256(_tree.leafCount) + _index;
        _tree.nodes[position] = _leaf;
        uint256 height;
        while (position > 1) {
            uint256 parent = position >> 1;
            bytes32 left = _tree.nodes[parent << 1];
            bytes32 right = _tree.nodes[(parent << 1) | 1];
            _tree.nodes[parent] = _hashNode(_tree.kind, uint8(height), left, right);
            position = parent;
            ++height;
        }
    }

    function encodeProof(bytes32[] memory _siblings) internal pure returns (bytes memory encoded_) {
        encoded_ = new bytes(_siblings.length * 32);
        for (uint256 i; i < _siblings.length; ++i) {
            bytes32 sibling = _siblings[i];
            assembly ("memory-safe") {
                mstore(add(add(encoded_, 32), mul(i, 32)), sibling)
            }
        }
    }

    function registryLeaf(
        uint8 _index,
        bool _occupied,
        SlotChainTypes.RegistryCellV1 memory _cell
    )
        internal
        pure
        returns (bytes32 leaf_)
    {
        return LibSlotChainEncoding.hashRegistryLeaf(_index, _occupied, _cell);
    }

    function admissionLeaf(
        uint16 _index,
        bool _occupied,
        uint8 _location,
        SlotChainTypes.RegistryCellV1 memory _cell
    )
        internal
        pure
        returns (bytes32 leaf_)
    {
        return LibSlotChainEncoding.hashAdmissionLeaf(_index, _occupied, _location, _cell);
    }

    function trancheLeaf(SlotChainTypes.TrancheLeafV1 memory _leaf)
        internal
        pure
        returns (bytes32 leaf_)
    {
        return LibSlotChainEncoding.hashTrancheLeaf(_leaf);
    }

    function emptyTrancheLeaf(uint16 _index)
        internal
        pure
        returns (SlotChainTypes.TrancheLeafV1 memory leaf_)
    {
        leaf_ = SlotChainTypes.TrancheLeafV1({
            index: _index,
            window: type(uint64).max,
            state: uint8(SlotChainTypes.TrancheState.EMPTY),
            amount: 0,
            liableUntil: 0
        });
    }

    function _emptyTree(
        uint16 _leafCount,
        uint8 _kind
    )
        private
        pure
        returns (Tree memory tree_)
    {
        tree_.nodes = new bytes32[](uint256(_leafCount) * 2);
        tree_.leafCount = _leafCount;
        tree_.kind = _kind;
        SlotChainTypes.RegistryCellV1 memory emptyCell;
        for (uint16 i; i < _leafCount; ++i) {
            if (_kind == REGISTRY) {
                tree_.nodes[uint256(_leafCount) + i] =
                    LibSlotChainEncoding.hashRegistryLeaf(uint8(i), false, emptyCell);
            } else if (_kind == ADMISSION) {
                tree_.nodes[uint256(_leafCount) + i] =
                    LibSlotChainEncoding.hashAdmissionLeaf(i, false, 0, emptyCell);
            } else {
                tree_.nodes[uint256(_leafCount) + i] =
                    LibSlotChainEncoding.hashTrancheLeaf(emptyTrancheLeaf(i));
            }
        }

        uint256 width = _leafCount;
        uint8 height;
        while (width > 1) {
            uint256 childStart = width;
            uint256 parentStart = width >> 1;
            for (uint256 i; i < width; i += 2) {
                tree_.nodes[parentStart + i / 2] = _hashNode(
                    _kind, height, tree_.nodes[childStart + i], tree_.nodes[childStart + i + 1]
                );
            }
            width >>= 1;
            ++height;
        }
    }

    function _hashNode(
        uint8 _kind,
        uint8 _height,
        bytes32 _left,
        bytes32 _right
    )
        private
        pure
        returns (bytes32 hash_)
    {
        if (_kind == REGISTRY) {
            return LibSlotChainEncoding.hashRegistryNode(_height, _left, _right);
        }
        if (_kind == ADMISSION) {
            return LibSlotChainEncoding.hashAdmissionNode(_height, _left, _right);
        }
        return LibSlotChainEncoding.hashTrancheNode(_height, _left, _right);
    }

    function _depth(uint16 _leafCount) private pure returns (uint256 depth_) {
        while (_leafCount > 1) {
            _leafCount >>= 1;
            ++depth_;
        }
    }

    error InvalidTestTreeIndex();
}

contract BuilderLeaseTokenMock {
    uint8 internal constant MODE_NORMAL = 0;
    uint8 internal constant MODE_EMPTY_RETURN = 1;
    uint8 internal constant MODE_FALSE_RETURN = 2;
    uint8 internal constant MODE_SHORT_RETURN = 3;
    uint8 internal constant MODE_TRAILING_RETURN = 4;
    uint8 internal constant MODE_REVERT = 5;
    uint8 internal constant MODE_OOG = 6;
    uint8 internal constant MODE_FEE = 7;
    uint8 internal constant MODE_REENTRY = 8;

    uint8 private immutable _tokenDecimals;
    uint8 private _balanceMode;
    uint8 private _transferMode;
    address private _reentryTarget;
    bytes private _reentryCalldata;
    bytes[] private _reentryMatrix;
    bytes4 private _expectedReentryError;

    mapping(address owner => uint256 balance) private _balances;
    mapping(address owner => mapping(address spender => uint256 allowance)) private _allowances;

    constructor(uint8 _decimals) {
        _tokenDecimals = _decimals;
    }

    function decimals() external view returns (uint8 decimals_) {
        _applyViewFault(_balanceMode);
        return _tokenDecimals;
    }

    function balanceOf(address _owner) external view returns (uint256 balance_) {
        _applyViewFault(_balanceMode);
        return _balances[_owner];
    }

    function approve(address _spender, uint256 _amount) external returns (bool approved_) {
        _allowances[msg.sender][_spender] = _amount;
        return true;
    }

    function transfer(
        address _recipient,
        uint256 _amount
    )
        external
        returns (bool transferred_)
    {
        _move(msg.sender, _recipient, _amount);
        _finishTransfer();
        return true;
    }

    function transferFrom(
        address _owner,
        address _recipient,
        uint256 _amount
    )
        external
        returns (bool transferred_)
    {
        uint256 allowed = _allowances[_owner][msg.sender];
        if (allowed != type(uint256).max) _allowances[_owner][msg.sender] = allowed - _amount;
        _move(_owner, _recipient, _amount);
        _finishTransfer();
        return true;
    }

    function mint(address _recipient, uint256 _amount) external {
        _balances[_recipient] += _amount;
    }

    function forceTransfer(address _from, address _recipient, uint256 _amount) external {
        _move(_from, _recipient, _amount);
    }

    function setBalanceMode(uint8 _mode) external {
        _balanceMode = _mode;
    }

    function setTransferMode(uint8 _mode) external {
        _transferMode = _mode;
    }

    function configureReentry(
        address _target,
        bytes calldata _calldata,
        bytes4 _expectedError
    )
        external
    {
        _reentryTarget = _target;
        _reentryCalldata = _calldata;
        delete _reentryMatrix;
        _expectedReentryError = _expectedError;
        _transferMode = MODE_REENTRY;
    }

    function configureReentryMatrix(
        address _target,
        bytes[] calldata _calldata,
        bytes4 _expectedError
    )
        external
    {
        _reentryTarget = _target;
        delete _reentryCalldata;
        delete _reentryMatrix;
        for (uint256 i; i < _calldata.length; ++i) {
            _reentryMatrix.push(_calldata[i]);
        }
        _expectedReentryError = _expectedError;
        _transferMode = MODE_REENTRY;
    }

    function rawBalance(address _owner) external view returns (uint256 balance_) {
        return _balances[_owner];
    }

    function _move(address _owner, address _recipient, uint256 _amount) private {
        _balances[_owner] -= _amount;
        uint256 received = _transferMode == MODE_FEE && _amount != 0 ? _amount - 1 : _amount;
        _balances[_recipient] += received;
    }

    function _finishTransfer() private {
        uint8 mode = _transferMode;
        if (mode == MODE_REENTRY) {
            if (_reentryMatrix.length == 0) {
                _requireExpectedReentry(_reentryCalldata);
            } else {
                for (uint256 i; i < _reentryMatrix.length; ++i) {
                    _requireExpectedReentry(_reentryMatrix[i]);
                }
            }
            return;
        }
        if (mode == MODE_EMPTY_RETURN) {
            assembly ("memory-safe") {
                return(0, 0)
            }
        }
        if (mode == MODE_FALSE_RETURN) {
            assembly ("memory-safe") {
                mstore(0, 0)
                return(0, 32)
            }
        }
        if (mode == MODE_SHORT_RETURN) {
            assembly ("memory-safe") {
                mstore(0, 1)
                return(31, 1)
            }
        }
        if (mode == MODE_TRAILING_RETURN) {
            assembly ("memory-safe") {
                mstore(0, 1)
                mstore(32, 0)
                return(0, 64)
            }
        }
        if (mode == MODE_REVERT) revert TokenFault();
        if (mode == MODE_OOG) {
            assembly ("memory-safe") {
                for { } 1 { } { }
            }
        }
    }

    function _requireExpectedReentry(bytes memory _calldata) private {
        (bool success, bytes memory returndata) = _reentryTarget.call(_calldata);
        if (success || returndata.length < 4 || bytes4(returndata) != _expectedReentryError) {
            revert UnexpectedReentryResult();
        }
    }

    function _applyViewFault(uint8 _mode) private pure {
        if (_mode == MODE_SHORT_RETURN) {
            assembly ("memory-safe") {
                mstore(0, 1)
                return(31, 1)
            }
        }
        if (_mode == MODE_TRAILING_RETURN) {
            assembly ("memory-safe") {
                mstore(0, 1)
                mstore(32, 0)
                return(0, 64)
            }
        }
        if (_mode == MODE_REVERT) revert TokenFault();
        if (_mode == MODE_OOG) {
            assembly ("memory-safe") {
                for { } 1 { } { }
            }
        }
    }

    error TokenFault();
    error UnexpectedReentryResult();
}

contract BuilderProofVerifierMock {
    bytes4 internal constant CONFIG_SELECTOR = 0x0d1c9932;
    bytes4 internal constant COMPONENT_CONFIG_SELECTOR = 0xf6c0f7d2;
    bytes4 internal constant IDENTITY_SELECTOR = 0x7c09d62d;
    bytes4 internal constant PROOF_SELECTOR = 0xa9ca9190;

    mapping(bytes4 selector => bytes response) private _responses;
    mapping(bytes32 calldataHash => bytes response) private _callResponses;
    mapping(bytes4 selector => uint8 mode) private _modes;

    constructor() {
        bytes32 configurationHash = expectedConfigurationHash();
        bytes memory response = new bytes(512);
        _storeWord(response, 0, bytes32(bytes4(0x42505631)));
        _storeWord(response, 1, bytes32(uint256(1)));
        _storeWord(response, 2, bytes32(uint256(64)));
        _storeWord(response, 3, bytes32(uint256(1136)));
        _storeWord(response, 4, bytes32(uint256(2048)));
        _storeWord(response, 5, bytes32(uint256(512)));
        _storeWord(response, 6, bytes32(uint256(6)));
        _storeWord(response, 7, bytes32(uint256(11)));
        _storeWord(response, 8, bytes32(uint256(9)));
        _storeWord(response, 9, bytes32(uint256(18)));
        _storeWord(response, 10, bytes32(uint256(350_000)));
        _storeWord(response, 11, bytes32(uint256(120_000)));
        _storeWord(response, 12, bytes32(uint256(160_000)));
        _storeWord(response, 13, bytes32(uint256(700_000)));
        _storeWord(response, 14, bytes32(uint256(450_000)));
        _storeWord(response, 15, configurationHash);
        _responses[CONFIG_SELECTOR] = response;
        _responses[COMPONENT_CONFIG_SELECTOR] = abi.encode(configurationHash);
    }

    function expectedConfigurationHash() public pure returns (bytes32 hash_) {
        bytes memory packed = bytes.concat(
            abi.encodePacked(
                uint8(1),
                uint16(64),
                uint16(1136),
                uint16(2048),
                uint16(512),
                uint8(6),
                uint8(11),
                uint8(9),
                uint8(18)
            ),
            abi.encodePacked(
                uint32(350_000),
                uint32(120_000),
                uint32(160_000),
                uint32(700_000),
                uint32(450_000),
                IDENTITY_SELECTOR,
                PROOF_SELECTOR,
                bytes4(0x42505631),
                bytes4(0x45495631),
                bytes4(0x42505231),
                bytes4(0x42504f31)
            ),
            abi.encodePacked(
                uint16(512),
                uint16(320),
                uint16(192),
                uint16(432),
                uint16(531),
                uint16(6770),
                uint16(2727)
            )
        );
        assert(packed.length == 71);
        return keccak256(
            abi.encodePacked("slot-chain-builder-proof-verifier-config-v1", uint16(71), packed)
        );
    }

    function _storeWord(bytes memory _output, uint256 _index, bytes32 _value) private pure {
        assembly ("memory-safe") {
            mstore(add(add(_output, 32), mul(_index, 32)), _value)
        }
    }

    function setResponse(bytes4 _selector, bytes calldata _response) external {
        _responses[_selector] = _response;
    }

    function setCallResponse(bytes calldata _calldata, bytes calldata _response) external {
        _callResponses[keccak256(_calldata)] = _response;
    }

    function setMode(bytes4 _selector, uint8 _mode) external {
        _modes[_selector] = _mode;
    }

    fallback() external {
        uint8 mode = _modes[msg.sig];
        if (mode == 1) revert VerifierFault();
        if (mode == 2) {
            assembly ("memory-safe") {
                for { } 1 { } { }
            }
        }
        bytes memory response = _callResponses[keccak256(msg.data)];
        if (response.length == 0) response = _responses[msg.sig];
        if (mode == 3 && response.length != 0) {
            assembly ("memory-safe") {
                return(add(response, 32), sub(mload(response), 1))
            }
        }
        if (mode == 4) {
            assembly ("memory-safe") {
                mstore(add(add(response, 32), mload(response)), 0)
                return(add(response, 32), add(mload(response), 32))
            }
        }
        if (mode == 5) {
            assembly ("memory-safe") {
                return(0, 8192)
            }
        }
        assembly ("memory-safe") {
            return(add(response, 32), mload(response))
        }
    }

    error VerifierFault();
}

abstract contract BuilderExactPeerMock {
    uint8 internal constant MODE_NORMAL = 0;
    uint8 internal constant MODE_REVERT = 1;
    uint8 internal constant MODE_OOG = 2;
    uint8 internal constant MODE_SHORT = 3;
    uint8 internal constant MODE_TRAILING = 4;
    uint8 internal constant MODE_BOMB = 5;

    bytes32 private immutable _configurationHash;
    mapping(bytes4 selector => bytes response) private _responses;
    mapping(bytes4 selector => uint8 mode) private _modes;

    constructor(bytes32 _configHash) {
        _configurationHash = _configHash;
    }

    function componentConfigHashV2() external view returns (bytes32 configHash_) {
        return _configurationHash;
    }

    function setResponse(bytes4 _selector, bytes calldata _response) external {
        _responses[_selector] = _response;
    }

    function setMode(bytes4 _selector, uint8 _mode) external {
        _modes[_selector] = _mode;
    }

    fallback() external {
        uint8 mode = _modes[msg.sig];
        if (mode == MODE_REVERT) revert PeerFault();
        if (mode == MODE_OOG) {
            assembly ("memory-safe") {
                for { } 1 { } { }
            }
        }
        bytes memory response = _responses[msg.sig];
        if (mode == MODE_SHORT && response.length != 0) {
            assembly ("memory-safe") {
                return(add(response, 32), sub(mload(response), 1))
            }
        }
        if (mode == MODE_TRAILING) {
            assembly ("memory-safe") {
                mstore(add(add(response, 32), mload(response)), 0)
                return(add(response, 32), add(mload(response), 32))
            }
        }
        if (mode == MODE_BOMB) {
            assembly ("memory-safe") {
                return(0, 8192)
            }
        }
        assembly ("memory-safe") {
            return(add(response, 32), mload(response))
        }
    }

    error PeerFault();
}

contract BuilderRouterMock is BuilderExactPeerMock {
    constructor(bytes32 _configHash) BuilderExactPeerMock(_configHash) { }
}

contract BuilderScheduleOracleMock is BuilderExactPeerMock {
    constructor() BuilderExactPeerMock(keccak256("unused-schedule-config")) { }
}

contract BuilderLifecycleFacetMock {
    bytes4 private constant _BRF1_MAGIC = 0x42524631;
    bytes32 private constant _STORAGE_LAYOUT_HASH =
        0x5b676bdd8dd5b37f6353a4b46a59d7d24f6b0cc66b28cf1222b3deafe36402bd;
    bytes32 private constant _SEAT_SELECTOR_SET_HASH =
        0x92e9dd5f246684dbc6137c40eb276993130005222bc31be614359dbc1164bbf5;
    bytes32 private constant _LEASE_SELECTOR_SET_HASH =
        0x895e8723291f0a1f397a981815290e003eab16a87807eadc3b3bc0d805b8fb78;
    bytes32 private constant _SEAT_CONFIGURATION_HASH =
        0x5844c0d5e26f8e8006907c41fcf7c121537202827fa671a15099730c1dd38d6b;
    bytes32 private constant _LEASE_CONFIGURATION_HASH =
        0x768f741248a8cd1b1fc84f9134261736305ad3d373ac5a5b346057a7c1b9680a;

    uint8 private immutable _kind;
    uint8 private immutable _configFault;
    uint16 private immutable _responseSize;
    bool private immutable _revertResponse;

    constructor(uint8 _facetKind, uint8 _facetConfigFault, uint16 _size, bool _revertData) {
        _kind = _facetKind;
        _configFault = _facetConfigFault;
        _responseSize = _size;
        _revertResponse = _revertData;
    }

    function componentConfigHashV2() external view returns (bytes32 configHash_) {
        configHash_ = _configurationHash();
        if (_configFault == 7) configHash_ = bytes32(uint256(configHash_) ^ 1);
    }

    function builderRegistryLifecycleFacetConfigV1()
        external
        view
        returns (bytes4, uint8, uint8, bytes32, bytes32, bytes32)
    {
        bytes4 magic = _configFault == 1 ? bytes4(0) : _BRF1_MAGIC;
        uint8 schema = _configFault == 2 ? 2 : 1;
        uint8 kind = _configFault == 3 ? (_kind == 1 ? 2 : 1) : _kind;
        bytes32 layoutHash =
            _configFault == 4 ? bytes32(uint256(_STORAGE_LAYOUT_HASH) ^ 1) : _STORAGE_LAYOUT_HASH;
        bytes32 selectors = _selectorSetHash();
        if (_configFault == 5) selectors = bytes32(uint256(selectors) ^ 1);
        bytes32 configuration = _configurationHash();
        if (_configFault == 6) configuration = bytes32(uint256(configuration) ^ 1);
        return (magic, schema, kind, layoutHash, selectors, configuration);
    }

    fallback() external {
        bytes memory output = new bytes(_responseSize);
        if (output.length >= 4) {
            assembly ("memory-safe") {
                mstore(add(output, 32), shl(224, 0xfeedbeef))
            }
        }
        if (output.length >= 36) {
            assembly ("memory-safe") {
                mstore(add(output, 36), 0x1234)
            }
        }
        bool revertResponse = _revertResponse;
        assembly ("memory-safe") {
            if revertResponse { revert(add(output, 32), mload(output)) }
            return(add(output, 32), mload(output))
        }
    }

    function _selectorSetHash() private view returns (bytes32) {
        return _kind == 1 ? _SEAT_SELECTOR_SET_HASH : _LEASE_SELECTOR_SET_HASH;
    }

    function _configurationHash() private view returns (bytes32) {
        return _kind == 1 ? _SEAT_CONFIGURATION_HASH : _LEASE_CONFIGURATION_HASH;
    }
}
