// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/
//
//   Email: security@taiko.xyz
//   Website: https://taiko.xyz
//   GitHub: https://github.com/taikoxyz
//   Discord: https://discord.gg/taikoxyz
//   Twitter: https://twitter.com/taikoxyz
//   Blog: https://mirror.xyz/labs.taiko.eth
//   Youtube: https://www.youtube.com/@taikoxyz

pragma solidity 0.8.24;

import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "../common/EssentialContract.sol";
import "../libs/LibTrieProof.sol";
import "./ISignalService.sol";
import "./LibSignals.sol";

/// @title SignalService
/// @custom:security-contact security@taiko.xyz
/// @dev Labeled in AddressResolver as "signal_service"
/// @notice See the documentation in {ISignalService} for more details.
contract SignalService is EssentialContract, ISignalService {
    enum CacheOption {
        CACHE_NOTHING,
        CACHE_SIGNAL_ROOT,
        CACHE_STATE_ROOT,
        CACHE_BOTH
    }

    struct HopProof {
        uint64 chainId;
        uint64 blockId;
        bytes32 rootHash;
        CacheOption cacheOption;
        bytes[] accountProof;
        bytes[] storageProof;
    }

    mapping(uint64 chainId => mapping(bytes32 kind => uint64 blockId)) public topBlockId; // slot 1
    mapping(address addr => bool authorized) public isAuthorized; // slot 2
    uint256[48] private __gap;

    event SignalSent(address app, bytes32 signal, bytes32 slot, bytes32 value);
    event Authorized(address indexed addr, bool authrized);

    error SS_EMPTY_PROOF();
    error SS_INVALID_SENDER();
    error SS_INVALID_LAST_HOP_CHAINID();
    error SS_INVALID_MID_HOP_CHAINID();
    error SS_INVALID_STATE();
    error SS_INVALID_VALUE();
    error SS_SIGNAL_NOT_FOUND();
    error SS_UNAUTHORIZED();
    error SS_UNSUPPORTED();

    modifier validSender(address _app) {
        if (_app == address(0)) revert SS_INVALID_SENDER();
        _;
    }

    modifier nonZeroValue(bytes32 _input) {
        if (_input == 0) revert SS_INVALID_VALUE();
        _;
    }

    /// @notice Initializes the contract.
    /// @param _owner The owner of this contract. msg.sender will be used if this value is zero.
    /// @param _addressManager The address of the {AddressManager} contract.
    function init(address _owner, address _addressManager) external initializer {
        __Essential_init(_owner, _addressManager);
    }

    /// @dev Authorize or deautohrize an address for calling syncChainData
    /// @dev Note that addr is supposed to be TaikoL1 and TaikoL1 contracts deployed locally.
    /// @param _addr The address to be authorized or deauthorized.
    /// @param _toAuthorize True if authorize, false otherwise.
    function authorize(address _addr, bool _toAuthorize) external onlyOwner {
        if (isAuthorized[_addr] == _toAuthorize) revert SS_INVALID_STATE();
        isAuthorized[_addr] = _toAuthorize;
        emit Authorized(_addr, _toAuthorize);
    }

    /// @inheritdoc ISignalService
    function sendSignal(bytes32 _signal) external returns (bytes32) {
        return _sendSignal(msg.sender, _signal, _signal);
    }

    /// @inheritdoc ISignalService
    function syncChainData(
        uint64 _chainId,
        bytes32 _kind,
        uint64 _blockId,
        bytes32 _chainData
    )
        external
        returns (bytes32)
    {
        if (!isAuthorized[msg.sender]) revert SS_UNAUTHORIZED();
        return _syncChainData(_chainId, _kind, _blockId, _chainData);
    }

    /// @inheritdoc ISignalService
    /// @dev This function may revert.
    function proveSignalReceived(
        uint64 _chainId,
        address _app,
        bytes32 _signal,
        bytes calldata _proof
    )
        public
        virtual
        validSender(_app)
        nonZeroValue(_signal)
    {
        HopProof[] memory _hopProofs = abi.decode(_proof, (HopProof[]));
        if (_hopProofs.length == 0) revert SS_EMPTY_PROOF();

        uint64 chainId_ = _chainId;
        address app_ = _app;
        bytes32 signal_ = _signal;
        bytes32 value_ = _signal;
        address signalService = resolve(chainId_, "signal_service", false);

        HopProof memory hop;
        for (uint256 i; i < _hopProofs.length; ++i) {
            hop = _hopProofs[i];

            bytes32 signalRoot =
                _verifyHopProof(chainId_, app_, signal_, value_, hop, signalService);
            bool isLastHop = i == _hopProofs.length - 1;

            if (isLastHop) {
                if (hop.chainId != block.chainid) revert SS_INVALID_LAST_HOP_CHAINID();
                signalService = address(this);
            } else {
                if (hop.chainId == 0 || hop.chainId == block.chainid) {
                    revert SS_INVALID_MID_HOP_CHAINID();
                }
                signalService = resolve(hop.chainId, "signal_service", false);
            }

            bool isFullProof = hop.accountProof.length > 0;

            _cacheChainData(hop, chainId_, hop.blockId, signalRoot, isFullProof, isLastHop);

            bytes32 kind = isFullProof ? LibSignals.STATE_ROOT : LibSignals.SIGNAL_ROOT;
            signal_ = signalForChainData(chainId_, kind, hop.blockId);
            value_ = hop.rootHash;
            chainId_ = hop.chainId;
            app_ = signalService;
        }

        if (value_ == 0 || value_ != _loadSignalValue(address(this), signal_)) {
            revert SS_SIGNAL_NOT_FOUND();
        }
    }

    /// @inheritdoc ISignalService
    function isChainDataSynced(
        uint64 _chainId,
        bytes32 _kind,
        uint64 _blockId,
        bytes32 _chainData
    )
        public
        view
        nonZeroValue(_chainData)
        returns (bool)
    {
        bytes32 signal = signalForChainData(_chainId, _kind, _blockId);
        return _loadSignalValue(address(this), signal) == _chainData;
    }

    /// @inheritdoc ISignalService
    function isSignalSent(address _app, bytes32 _signal) public view returns (bool) {
        return _loadSignalValue(_app, _signal) != 0;
    }

    /// @inheritdoc ISignalService
    function getSyncedChainData(
        uint64 _chainId,
        bytes32 _kind,
        uint64 _blockId
    )
        public
        view
        returns (uint64 blockId_, bytes32 chainData_)
    {
        blockId_ = _blockId != 0 ? _blockId : topBlockId[_chainId][_kind];

        if (blockId_ != 0) {
            bytes32 signal = signalForChainData(_chainId, _kind, blockId_);
            chainData_ = _loadSignalValue(address(this), signal);
            if (chainData_ == 0) revert SS_SIGNAL_NOT_FOUND();
        }
    }

    /// @inheritdoc ISignalService
    function signalForChainData(
        uint64 _chainId,
        bytes32 _kind,
        uint64 _blockId
    )
        public
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(_chainId, _kind, _blockId));
    }

    function getSignalSlot(
        uint64 _chainId,
        address _app,
        bytes32 _signal
    )
        public
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked("SIGNAL", _chainId, _app, _signal));
    }

    function _verifyHopProof(
        uint64 _chainId,
        address _app,
        bytes32 _signal,
        bytes32 _value,
        HopProof memory _hop,
        address _signalService
    )
        internal
        virtual
        validSender(_app)
        nonZeroValue(_signal)
        nonZeroValue(_value)
        returns (bytes32)
    {
        return LibTrieProof.verifyMerkleProof(
            _hop.rootHash,
            _signalService,
            getSignalSlot(_chainId, _app, _signal),
            _value,
            _hop.accountProof,
            _hop.storageProof
        );
    }

    function _authorizePause(address) internal pure override {
        revert SS_UNSUPPORTED();
    }

    function _syncChainData(
        uint64 _chainId,
        bytes32 _kind,
        uint64 _blockId,
        bytes32 _chainData
    )
        private
        returns (bytes32 signal_)
    {
        signal_ = signalForChainData(_chainId, _kind, _blockId);
        _sendSignal(address(this), signal_, _chainData);

        if (topBlockId[_chainId][_kind] < _blockId) {
            topBlockId[_chainId][_kind] = _blockId;
        }
        emit ChainDataSynced(_chainId, _blockId, _kind, _chainData, signal_);
    }

    function _sendSignal(
        address _app,
        bytes32 _signal,
        bytes32 _value
    )
        private
        validSender(_app)
        nonZeroValue(_signal)
        nonZeroValue(_value)
        returns (bytes32 slot_)
    {
        slot_ = getSignalSlot(uint64(block.chainid), _app, _signal);
        assembly {
            sstore(slot_, _value)
        }
        emit SignalSent(_app, _signal, slot_, _value);
    }

    function _cacheChainData(
        HopProof memory _hop,
        uint64 _chainId,
        uint64 _blockId,
        bytes32 _signalRoot,
        bool _isFullProof,
        bool _isLastHop
    )
        private
    {
        // cache state root
        bool cacheStateRoot = _hop.cacheOption == CacheOption.CACHE_BOTH
            || _hop.cacheOption == CacheOption.CACHE_STATE_ROOT;

        if (cacheStateRoot && _isFullProof && !_isLastHop) {
            _syncChainData(_chainId, LibSignals.STATE_ROOT, _blockId, _hop.rootHash);
        }

        // cache signal root
        bool cacheSignalRoot = _hop.cacheOption == CacheOption.CACHE_BOTH
            || _hop.cacheOption == CacheOption.CACHE_SIGNAL_ROOT;

        if (cacheSignalRoot && (_isFullProof || !_isLastHop)) {
            _syncChainData(_chainId, LibSignals.SIGNAL_ROOT, _blockId, _signalRoot);
        }
    }

    function _loadSignalValue(
        address _app,
        bytes32 _signal
    )
        private
        view
        validSender(_app)
        nonZeroValue(_signal)
        returns (bytes32 value_)
    {
        bytes32 slot = getSignalSlot(uint64(block.chainid), _app, _signal);
        assembly {
            value_ := sload(slot)
        }
    }
}
