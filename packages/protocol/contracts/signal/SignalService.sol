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

    mapping(uint64 chainId => mapping(bytes32 kind => uint64 topBlockId)) public topBlockId;
    mapping(address => bool) public isRelayerAuthorized;
    uint256[49] private __gap;

    /// @notice Emitted when a remote chain's state root or signal root is relayed locally as a
    /// signal.
    event ChainDataRelayed(
        uint64 indexed chainid,
        uint64 indexed blockId,
        bytes32 indexed kind,
        bytes32 data,
        bytes32 signal
    );

    event RelayerAuthorized(address indexed addr, bool authrized);

    error SS_EMPTY_PROOF();
    error SS_INVALID_SENDER();
    error SS_INVALID_LAST_HOP_CHAINID();
    error SS_INVALID_MID_HOP_CHAINID();
    error SS_INVALID_SIGNAL();
    error SS_INVALID_STATE();
    error SS_INVALID_VALUE();
    error SS_LOCAL_CHAIN_DATA_NOT_FOUND();
    error SS_SIGNAL_NOT_FOUND();
    error SS_UNAUTHORIZED();
    error SS_UNSUPPORTED();

    modifier validSender(address sender) {
        if (sender == address(0)) revert SS_INVALID_SENDER();
        _;
    }

    modifier nonZeroValue(bytes32 input) {
        if (input == 0) revert SS_INVALID_VALUE();
        _;
    }

    /// @dev Initializer to be called after being deployed behind a proxy.
    function init(address _addressManager) external initializer {
        __Essential_init(_addressManager);
    }

    /// @dev Authorize or deautohrize an address for calling relayChainData
    /// @dev Note that addr is supposed to be TaikoL1 and TaikoL1 contracts deployed locally.
    function authorizeRelayer(address addr, bool toAuthorize) external onlyOwner {
        if (isRelayerAuthorized[addr] == toAuthorize) revert SS_INVALID_STATE();
        isRelayerAuthorized[addr] = toAuthorize;
        emit RelayerAuthorized(addr, toAuthorize);
    }

    /// @inheritdoc ISignalService
    function sendSignal(bytes32 signal) external returns (bytes32 slot) {
        return _sendSignal(msg.sender, signal, signal);
    }

    /// @inheritdoc ISignalService
    function relayChainData(
        uint64 chainId,
        uint64 blockId,
        bytes32 kind,
        bytes32 chainData
    )
        external
        returns (bytes32 signal)
    {
        if (!isRelayerAuthorized[msg.sender]) revert SS_UNAUTHORIZED();
        return _relayChainData(chainId, blockId, kind, chainData);
    }

    /// @inheritdoc ISignalService
    /// @dev This function may revert.
    function proveSignalReceived(
        uint64 chainId,
        address sender,
        bytes32 signal,
        bytes calldata proof
    )
        public
        virtual
        validSender(sender)
        nonZeroValue(signal)
    {
        HopProof[] memory _hopProofs = abi.decode(proof, (HopProof[]));
        if (_hopProofs.length == 0) revert SS_EMPTY_PROOF();

        uint64 _chainId = chainId;
        address _sender = sender;
        bytes32 _signal = signal;
        bytes32 _value = signal;
        address _signalService = resolve(_chainId, "signal_service", false);

        HopProof memory hop;
        for (uint256 i; i < _hopProofs.length; ++i) {
            hop = _hopProofs[i];

            bytes32 signalRoot =
                _verifyHopProof(_chainId, _sender, _signal, _value, hop, _signalService);
            bool isLastHop = i == _hopProofs.length - 1;

            if (isLastHop) {
                if (hop.chainId != block.chainid) revert SS_INVALID_LAST_HOP_CHAINID();
                _signalService = address(this);
            } else {
                if (hop.chainId == 0 || hop.chainId == block.chainid) {
                    revert SS_INVALID_MID_HOP_CHAINID();
                }
                _signalService = resolve(hop.chainId, "signal_service", false);
            }

            bool isFullProof = hop.accountProof.length > 0;

            _cacheChainData(hop, _chainId, hop.blockId, signalRoot, isFullProof, isLastHop);

            bytes32 kind = isFullProof ? LibSignals.STATE_ROOT : LibSignals.SIGNAL_ROOT;
            _signal = signalForChainData(_chainId, hop.blockId, kind);
            _value = hop.rootHash;
            _chainId = hop.chainId;
            _sender = _signalService;
        }

        if (_loadSignalValue(address(this), _signal) != _value) {
            revert SS_SIGNAL_NOT_FOUND();
        }
    }

    /// @inheritdoc ISignalService
    function isChainDataRelayed(
        uint64 chainId,
        uint64 blockId,
        bytes32 kind,
        bytes32 chainData
    )
        public
        view
        nonZeroValue(chainData)
        returns (bool)
    {
        bytes32 signal = signalForChainData(chainId, blockId, kind);
        return _loadSignalValue(address(this), signal) == chainData;
    }

    /// @inheritdoc ISignalService
    function isSignalSent(address sender, bytes32 signal) public view returns (bool) {
        return _loadSignalValue(sender, signal) == signal;
    }

    /// @inheritdoc ISignalService
    function getLatestBlockData(
        uint64 chainId,
        bytes32 kind
    )
        public
        view
        returns (uint64 blockId, bytes32 blockData)
    {
        blockId = topBlockId[chainId][kind];
        bytes32 signal = signalForChainData(chainId, blockId, kind);
        blockData = _loadSignalValue(address(this), signal);
    }

    function signalForChainData(
        uint64 chainId,
        uint64 blockId,
        bytes32 kind
    )
        public
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(chainId, blockId, kind));
    }

    function getSignalSlot(
        uint64 chainId,
        address sender,
        bytes32 signal
    )
        public
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked("SIGNAL", chainId, sender, signal));
    }

    function _verifyHopProof(
        uint64 chainId,
        address sender,
        bytes32 signal,
        bytes32 value,
        HopProof memory hop,
        address relay
    )
        internal
        virtual
        validSender(sender)
        nonZeroValue(signal)
        nonZeroValue(value)
        returns (bytes32 signalRoot)
    {
        return LibTrieProof.verifyMerkleProof(
            hop.rootHash,
            relay,
            getSignalSlot(chainId, sender, signal),
            bytes.concat(value),
            hop.accountProof,
            hop.storageProof
        );
    }

    function _authorizePause(address) internal pure override {
        revert SS_UNSUPPORTED();
    }

    function _relayChainData(
        uint64 chainId,
        uint64 blockId,
        bytes32 kind,
        bytes32 chainData
    )
        private
        returns (bytes32 signal)
    {
        signal = signalForChainData(chainId, blockId, kind);
        _sendSignal(address(this), signal, chainData);

        if (topBlockId[chainId][kind] < blockId) {
            topBlockId[chainId][kind] = blockId;
        }
        emit ChainDataRelayed(chainId, blockId, kind, chainData, signal);
    }

    function _sendSignal(
        address sender,
        bytes32 signal,
        bytes32 value
    )
        private
        validSender(sender)
        nonZeroValue(signal)
        nonZeroValue(value)
        returns (bytes32 slot)
    {
        slot = getSignalSlot(uint64(block.chainid), sender, signal);
        assembly {
            sstore(slot, value)
        }
    }

    function _cacheChainData(
        HopProof memory hop,
        uint64 chainId,
        uint64 blockId,
        bytes32 signalRoot,
        bool isFullProof,
        bool isLastHop
    )
        private
    {
        // cache state root
        bool cacheStateRoot = hop.cacheOption == CacheOption.CACHE_BOTH
            || hop.cacheOption == CacheOption.CACHE_STATE_ROOT;

        if (cacheStateRoot && isFullProof && !isLastHop) {
            _relayChainData(chainId, blockId, LibSignals.STATE_ROOT, hop.rootHash);
        }

        // cache signal root
        bool cacheSignalRoot = hop.cacheOption == CacheOption.CACHE_BOTH
            || hop.cacheOption == CacheOption.CACHE_SIGNAL_ROOT;

        if (cacheSignalRoot && (!isLastHop || isFullProof)) {
            _relayChainData(chainId, blockId, LibSignals.SIGNAL_ROOT, signalRoot);
        }
    }

    function _loadSignalValue(
        address sender,
        bytes32 signal
    )
        private
        view
        validSender(sender)
        nonZeroValue(signal)
        returns (bytes32 value)
    {
        bytes32 slot = getSignalSlot(uint64(block.chainid), sender, signal);
        assembly {
            value := sload(slot)
        }
        if (value == 0) revert SS_SIGNAL_NOT_FOUND();
    }
}
