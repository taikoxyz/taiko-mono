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

import "lib/openzeppelin-contracts/contracts/utils/math/SafeCast.sol";
import "../common/EssentialContract.sol";
import "../common/ICrossChainSync.sol";
import "../libs/LibTrieProof.sol";
import "../thirdparty/optimism/trie/SecureMerkleTrie.sol";
import "../thirdparty/optimism/rlp/RLPReader.sol";
import "./ISignalService.sol";

import "forge-std/console2.sol";
import "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
/// @title SignalService
/// @dev Labeled in AddressResolver as "signal_service"
/// @notice See the documentation in {ISignalService} for more details.
///
/// @dev Authorization Guide for Multi-Hop Bridging:
/// For facilitating multi-hop bridging, authorize all deployed TaikoL1 and
/// TaikoL2 contracts involved in the bridging path.
/// Use the respective chain IDs as labels for authorization.
/// Note: SignalService should not authorize Bridges or other Bridgable
/// applications.

contract SignalService is EssentialContract, ISignalService {
    using SafeCast for uint256;

    mapping(uint64 hopChainId => mapping(uint64 srcChainId => address signalService)) public
        trustedRelays;

    uint256[49] private __gap;

    event TrustedRelayUpdated(uint64 indexed hopChainId, uint64 indexed srcChainId, address hop);
    event ChainDataRelayed(
        uint64 indexed chainid, bytes32 indexed kind, bytes32 data, bytes32 signal
    );

    error SS_INVALID_PARAMS();
    error SS_INVALID_PROOF();
    error SS_EMPTY_PROOF();
    error SS_INVALID_APP();
    error SS_INVALID_HOP_PROOF();
    error SS_INVALID_LAST_HOP_CHAINID();
    error SS_INVALID_MID_HOP_CHAINID();
    error SS_INVALID_RELAY();
    error SS_INVALID_SIGNAL();
    error SS_INVALID_STATE_ROOT();
    error SS_LOCAL_CHAIN_DATA_NOT_FOUND();
    error SS_UNSUPPORTED();

    /// @dev Initializer to be called after being deployed behind a proxy.
    function init(address _addressManager) external initializer {
        __Essential_init(_addressManager);
    }

    function setTrustedRelay(
        uint64 hopChainId,
        uint64 srcChainId,
        address signalService
    )
        external
        onlyOwner
    {
        if (hopChainId == 0 || srcChainId == 0 || hopChainId == srcChainId) {
            revert SS_INVALID_PARAMS();
        }
        if (trustedRelays[hopChainId][srcChainId] == signalService) {
            revert SS_INVALID_PARAMS();
        }
        trustedRelays[hopChainId][srcChainId] = signalService;
        emit TrustedRelayUpdated(hopChainId, srcChainId, signalService);
    }

    /// @inheritdoc ISignalService
    function sendSignal(bytes32 signal) public returns (bytes32 slot) {
        return _sendSignal(msg.sender, signal);
    }

    /// @inheritdoc ISignalService
    function relayChainData(
        uint64 chainId,
        bytes32 kind,
        bytes32 data
    )
        external
        onlyFromNamed("taiko")
        returns (bytes32 slot)
    {
        return _relayChainData(chainId, kind, data);
    }

    /// @inheritdoc ISignalService
    function isSignalSent(address app, bytes32 signal) public view returns (bool) {
        if (signal == 0) revert SS_INVALID_SIGNAL();
        if (app == address(0)) revert SS_INVALID_APP();
        bytes32 slot = getSignalSlot(uint64(block.chainid), app, signal);
        uint256 value;
        assembly {
            value := sload(slot)
        }
        return value == 1;
    }

    struct HopProof {
        uint64 chainId;
        bool cacheChainData;
        bytes32 rootHash;
        bytes[] accountProof;
        bytes[] storageProof;
    }

    /// @inheritdoc ISignalService
    /// @dev This function may revert.
    function proveSignalReceived(
        uint64 chainId,
        address app,
        bytes32 signal,
        bytes calldata proof
    )
        public
        virtual
        returns (bool)
    {
        if (app == address(0) || signal == 0) revert SS_INVALID_PARAMS();

        HopProof[] memory _hopProofs = abi.decode(proof, (HopProof[]));
        if (_hopProofs.length == 0) revert SS_EMPTY_PROOF();

        uint64 _chainId = chainId;
        address _app = app;
        bytes32 _signal = signal;

        for (uint256 i; i < _hopProofs.length; ++i) {
            console2.log("\n-------------------------->");
            HopProof memory hop = _hopProofs[i];
            bool isLastHop = i == _hopProofs.length - 1;

            address relay;
            if (isLastHop) {
                if (hop.chainId != block.chainid) revert SS_INVALID_LAST_HOP_CHAINID();
                relay = address(this);
            } else {
                if (hop.chainId == 0 || hop.chainId == block.chainid) {
                    revert SS_INVALID_MID_HOP_CHAINID();
                }
                relay = trustedRelays[hop.chainId][_chainId];
                if (relay == address(0)) revert SS_INVALID_RELAY();
            }

            bytes32 signalRoot = _verifyHopProof(_chainId, _app, _signal, hop, relay);
            bool isFullProof = hop.accountProof.length > 0;

            if (hop.cacheChainData) {
                if (isLastHop) _relayChainData(_chainId, "signal_root", signalRoot);
                else if (isFullProof) _relayChainData(_chainId, "state_root", hop.rootHash);
                else _relayChainData(_chainId, "signal_root", hop.rootHash);
            }

            bytes32 kind = isFullProof ? bytes32("state_root") : bytes32("signal_root");
            _signal = signalForChainData(_chainId, kind, hop.rootHash);
            console2.log("hop.rootHash:", uint(hop.rootHash));
            console2.log("hop.kind:", uint(kind));
            console2.log("hop._chainId:", _chainId);
            _chainId = hop.chainId;
            _app = relay;
        }

        if (!isSignalSent(_app, _signal)) revert SS_LOCAL_CHAIN_DATA_NOT_FOUND();

        return true;
    }

    /// @notice Get the storage slot of the signal.
    /// @param chainId The address's chainId.
    /// @param app The address that initiated the signal.
    /// @param signal The signal to get the storage slot of.
    /// @return The unique storage slot of the signal which is
    /// created by encoding the sender address with the signal (message).
    function getSignalSlot(
        uint64 chainId,
        address app,
        bytes32 signal
    )
        public
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked("SIGNAL", chainId, app, signal));
    }

    function signalForChainData(
        uint64 chainId,
        bytes32 kind,
        bytes32 data
    )
        public
        view
        returns (bytes32 signal)
    {
        signal = keccak256(abi.encode(chainId, kind, data));
    }

    function _authorizePause(address) internal pure override {
        revert SS_UNSUPPORTED();
    }

    function _relayChainData(
        uint64 chainId,
        bytes32 kind,
        bytes32 data
    )
        internal
        returns (bytes32 slot)
    {
        bytes32 signal = signalForChainData(chainId, kind, data);
        emit ChainDataRelayed(chainId, kind, data, signal);

        console2.log("--->_relayChainData");
        console2.log("  chainId:", chainId);
        console2.log("  kind:", (uint256(kind)));
        console2.log("  data:", (uint256(data)));
        console2.log("  signal:", (uint256(signal)));

        return _sendSignal(address(this), signal);
    }

    function _sendSignal(address sender, bytes32 signal) internal returns (bytes32 slot) {
        if (signal == 0) revert SS_INVALID_SIGNAL();
        slot = getSignalSlot(uint64(block.chainid), sender, signal);
        assembly {
            sstore(slot, 1)
        }
    }

    function _verifyHopProof(
        uint64 chainId,
        address app,
        bytes32 signal,
        HopProof memory hop,
        address relay
    )
        internal
        virtual
        returns (bytes32 signalRoot)
    {
        signalRoot = LibTrieProof.verifyMerkleProof(
            hop.rootHash,
            relay,
            getSignalSlot(chainId, app, signal),
            hex"01",
            hop.accountProof,
            hop.storageProof
        );

        console2.log("---> returned from verify: ", uint256(signalRoot));
    }
}
