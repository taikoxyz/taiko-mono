// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../common/EssentialContract.sol";
import "../libs/LibTrieProof.sol";
import "./ISignalService.sol";

/// @title LegacySignalService
/// @notice SignalService contract pre shasta for compatibility reasons during the fork.
///          It keeps only the minimal functionality needed during the transition.
/// @custom:security-contact security@taiko.xyz
abstract contract LegacySignalService is EssentialContract {

    // ---------------------------------------------------------------
    // Structs, enums and events
    // ---------------------------------------------------------------
    
    enum CacheOption {
        CACHE_NOTHING,
        CACHE_SIGNAL_ROOT,
        CACHE_STATE_ROOT,
        CACHE_BOTH
    }

    struct CacheAction {
        bytes32 rootHash;
        bytes32 signalRoot;
        uint64 chainId;
        uint64 blockId;
        bool isFullProof;
        bool isLastHop;
        CacheOption option;
    }

    struct HopProof {
        /// @notice This hop's destination chain ID. If there is a next hop, this ID is the next
        /// hop's source chain ID.
        uint64 chainId;
        /// @notice The ID of a source chain block whose state root has been synced to the hop's
        /// destination chain.
        /// Note that this block ID must be greater than or equal to the block ID where the signal
        /// was sent on the source chain.
        uint64 blockId;
        /// @notice The state root or signal root of the source chain at the above blockId. This
        /// value has been synced to the destination chain.
        /// @dev To get both the blockId and the rootHash, apps should subscribe to the
        /// ChainDataSynced event or query `topBlockId` first using the source chain's ID and
        /// LibStrings.H_STATE_ROOT to get the most recent block ID synced, then call
        /// `getSyncedChainData` to read the synchronized data.
        bytes32 rootHash;
        /// @notice Options to cache either the state roots or signal roots of middle-hops to the
        /// current chain.
        CacheOption cacheOption;
        /// @notice The signal service's account proof. If this value is empty, then `rootHash` will
        /// be used as the signal root, otherwise, `rootHash` will be used as the state root.
        bytes[] accountProof;
        /// @notice The signal service's storage proof.
        bytes[] storageProof;
    }

    /// @notice Emitted when a remote chain's state root or signal root is
    /// synced locally as a signal.
    /// @param chainId The remote chainId.
    /// @param blockId The chain data's corresponding blockId.
    /// @param kind A value to mark the data type.
    /// @param data The remote data.
    /// @param signal The signal for this chain data.
    event ChainDataSynced(
        uint64 indexed chainId,
        uint64 indexed blockId,
        bytes32 indexed kind,
        bytes32 data,
        bytes32 signal
    );

    // ---------------------------------------------------------------
    // Immutable Variables
    // ---------------------------------------------------------------

    /// @dev Address of the remote signal service.
    address internal immutable _remoteSignalService;

    // ---------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------

    /// @notice Mapping to store the top blockId.
    /// @dev Slot 1.
    mapping(uint64 chainId => mapping(bytes32 kind => uint64 blockId)) public topBlockId;

    /// @notice Mapping to store the authorized addresses.
    /// @dev Slot 2.
    mapping(address addr => bool authorized) public isAuthorized;

    mapping(bytes32 signalSlot => bool received) internal _receivedSignals;

    uint256[47] private __gap;

    
    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    constructor(address remoteSignalService) {
        require(remoteSignalService != address(0), ZERO_ADDRESS());
        _remoteSignalService = remoteSignalService;
    }

    // ---------------------------------------------------------------
    // Public Functions(used by both implementations)
    // ---------------------------------------------------------------
    /// @notice Returns the slot for a signal.
    /// @param _chainId The chainId of the signal.
    /// @param _app The address that initiated the signal.
    /// @param _signal The signal (message) that was sent.
    /// @return The slot for the signal.
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

    // ---------------------------------------------------------------
    // Public Functions(legacy)
    // ---------------------------------------------------------------
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
        return _syncChainDataLegacy(_chainId, _kind, _blockId, _chainData);
    }

    function isChainDataSynced(
        uint64 _chainId,
        bytes32 _kind,
        uint64 _blockId,
        bytes32 _chainData
    )
        public
        view
        nonZeroBytes32(_chainData)
        returns (bool)
    {
        bytes32 signal = signalForChainData(_chainId, _kind, _blockId);
        return _loadSignalValueLegacy(address(this), signal) == _chainData;
    }

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
            chainData_ = _loadSignalValueLegacy(address(this), signal);
            if (chainData_ == 0) revert SS_SIGNAL_NOT_FOUND();
        }
    }

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

    // ---------------------------------------------------------------
    // Internal Functions
    // ---------------------------------------------------------------

    function _verifyHopProofLegacy(
        uint64 _chainId,
        address _app,
        bytes32 _signal,
        bytes32 _value,
        HopProof memory _hop,
        address _signalService
    )
        internal
        view
        virtual
        nonZeroAddr(_app)
        nonZeroBytes32(_signal)
        nonZeroBytes32(_value)
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


    function _syncChainDataLegacy(
        uint64 _chainId,
        bytes32 _kind,
        uint64 _blockId,
        bytes32 _chainData
    )
        private
        returns (bytes32 signal_)
    {
        signal_ = signalForChainData(_chainId, _kind, _blockId);
        _sendSignalLegacy(address(this), signal_, _chainData);

        if (topBlockId[_chainId][_kind] < _blockId) {
            topBlockId[_chainId][_kind] = _blockId;
        }
        emit ChainDataSynced(_chainId, _blockId, _kind, _chainData, signal_);
    }

    function _sendSignalLegacy(
        address _app,
        bytes32 _signal,
        bytes32 _value
    )
        private
        nonZeroAddr(_app)
        nonZeroBytes32(_signal)
        nonZeroBytes32(_value)
        returns (bytes32 slot_)
    {
        slot_ = getSignalSlot(uint64(block.chainid), _app, _signal);
        assembly {
            sstore(slot_, _value)
        }
        emit ISignalService.SignalSent(_app, _signal, slot_, _value);
    }

    function _cacheLegacy(CacheAction memory _action) internal returns (uint256 numCacheOps_) {
        // cache state root
        bool cacheStateRoot = _action.option == CacheOption.CACHE_BOTH
            || _action.option == CacheOption.CACHE_STATE_ROOT;

        if (cacheStateRoot && _action.isFullProof && !_action.isLastHop) {
            numCacheOps_ = 1;
            _syncChainDataLegacy(
                _action.chainId, keccak256("STATE_ROOT"), _action.blockId, _action.rootHash
            );
        }

        // cache signal root
        bool cacheSignalRoot = _action.option == CacheOption.CACHE_BOTH
            || _action.option == CacheOption.CACHE_SIGNAL_ROOT;

        if (cacheSignalRoot && (_action.isFullProof || !_action.isLastHop)) {
            numCacheOps_ += 1;
            _syncChainDataLegacy(
                _action.chainId, keccak256("SIGNAL_ROOT"), _action.blockId, _action.signalRoot
            );
        }
    }

    function _loadSignalValueLegacy(
        address _app,
        bytes32 _signal
    )
        private
        view
        nonZeroAddr(_app)
        nonZeroBytes32(_signal)
        returns (bytes32)
    {
        bytes32 slot = getSignalSlot(uint64(block.chainid), _app, _signal);
        return _loadSignalValueLegacy(slot);
    }

    function _loadSignalValueLegacy(bytes32 _signalSlot) private view returns (bytes32 value_) {
        assembly {
            value_ := sload(_signalSlot)
        }
    }

    /// @dev Verifies a signal received by a legacy signal service.
    /// IMPORTANT: This function does not use the resolver anymore, but instead uses the `_remoteSignalService` address.
    /// This is ok, since the communication happens only between L1<>L2.
    function _verifySignalReceivedLegacy(
        uint64 _chainId,
        address _app,
        bytes32 _signal,
        bytes calldata _proof,
        bool _prepareCaching
    )
        internal
        view
        nonZeroAddr(_app)
        nonZeroBytes32(_signal)
        returns (CacheAction[] memory actions)
    {
        if (_proof.length == 0) {
            require(
                _receivedSignals[getSignalSlot(_chainId, _app, _signal)], SS_SIGNAL_NOT_RECEIVED()
            );
            return new CacheAction[](0);
        }

        HopProof[] memory hopProofs = abi.decode(_proof, (HopProof[]));
        if (hopProofs.length == 0) revert SS_EMPTY_PROOF();

        uint64[] memory trace = new uint64[](hopProofs.length - 1);

        actions = new CacheAction[](_prepareCaching ? hopProofs.length : 0);

        uint64 chainId = _chainId;
        address app = _app;
        bytes32 signal = _signal;
        bytes32 value = _signal;
        address signalService = _remoteSignalService;
        if (signalService == address(this)) revert SS_INVALID_MID_HOP_CHAINID();

        HopProof memory hop;
        bytes32 signalRoot;
        bool isFullProof;
        bool isLastHop;

        for (uint256 i; i < hopProofs.length; ++i) {
            hop = hopProofs[i];

            for (uint256 j; j < i; ++j) {
                if (trace[j] == hop.chainId) revert SS_INVALID_HOPS_WITH_LOOP();
            }

            signalRoot = _verifyHopProofLegacy(chainId, app, signal, value, hop, signalService);
            isLastHop = i == trace.length;
            if (isLastHop) {
                if (hop.chainId != block.chainid) revert SS_INVALID_LAST_HOP_CHAINID();
                signalService = address(this);
            } else {
                trace[i] = hop.chainId;

                if (hop.chainId == 0 || hop.chainId == block.chainid) {
                    revert SS_INVALID_MID_HOP_CHAINID();
                }
                signalService = _remoteSignalService;
                if (signalService == address(this)) revert SS_INVALID_MID_HOP_CHAINID();
            }

            isFullProof = hop.accountProof.length != 0;

            if (_prepareCaching) {
                actions[i] = CacheAction(
                    hop.rootHash,
                    signalRoot,
                    chainId,
                    hop.blockId,
                    isFullProof,
                    isLastHop,
                    hop.cacheOption
                );
            }

            signal = signalForChainData(
                chainId,
                isFullProof ? keccak256("STATE_ROOT") : keccak256("SIGNAL_ROOT"),
                hop.blockId
            );
            value = hop.rootHash;
            chainId = hop.chainId;
            app = signalService;
        }

        if (value == 0 || value != _loadSignalValueLegacy(address(this), signal)) {
            revert SS_SIGNAL_NOT_FOUND();
        }
    }


    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------
    error SS_EMPTY_PROOF();
    error SS_INVALID_HOPS_WITH_LOOP();
    error SS_INVALID_LAST_HOP_CHAINID();
    error SS_INVALID_MID_HOP_CHAINID();
    error SS_INVALID_STATE();
    error SS_SIGNAL_NOT_FOUND();
    error SS_SIGNAL_NOT_RECEIVED();
    error SS_UNAUTHORIZED();
}