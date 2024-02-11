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
import "../thirdparty/optimism/trie/SecureMerkleTrie.sol";
import "../thirdparty/optimism/rlp/RLPReader.sol";
import "./IHopRelayRegistry.sol";
import "./ISignalService.sol";
import "./LibSignals.sol";

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

    // merkleProof represents ABI-encoded tuple of (key, value, and proof)
    // returned from the eth_getProof() API.
    struct Hop {
        uint64 chainId;
        bytes32 rootHash;
        bool isStateRoot;
        bytes merkleProof;
        address relay;
        bool cacheRootHash;
    }

    struct Proof {
        bytes32 rootHash;
        bool isStateRoot;
        bytes merkleProof;
        bool cacheSignalServiceStorageRoot;
        // Ensure that hops are ordered such that those closer to the signal's source chain come
        // before others.
        Hop[] hops;
    }

    event StateRootRelayed(uint64 indexed blockId, bytes32 indexed stateRoot);
    event SignalRootRelayed(uint64 indexed blockId, bytes32 indexed signalRoot);

    uint256[50] private __gap;

    error SS_INVALID_PARAMS();
    error SS_INVALID_PROOF();
    error SS_INVALID_APP();
    error SS_INVALID_RELAY();
    error SS_INVALID_SIGNAL();
    error SS_INVALID_ROOT_HASH();
    error SS_MULTIHOP_DISABLED();
    error SS_UNSUPPORTED();

    /// @dev Initializer to be called after being deployed behind a proxy.
    function init(address _addressManager) external initializer {
        __Essential_init(_addressManager);
    }

    /// @inheritdoc ISignalService
    function sendSignal(bytes32 signal) external returns (bytes32 slot) {
        return _sendSignal(signal);
    }

    function relayStateRoot(
        uint64 chainId,
        bytes32 stateRoot
    )
        external
        onlyFromNamed("taiko")
        returns (bytes32)
    {
        return _relayStateRoot(chainId, stateRoot);
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
        if (app == address(0) || signal == 0 || chainId == 0 || chainId == block.chainid) {
            revert SS_INVALID_PARAMS();
        }

        Proof memory p = abi.decode(proof, (Proof));
        if (!isMultiHopEnabled() && p.hops.length > 0) {
            revert SS_MULTIHOP_DISABLED();
        }

        // Verify hop proofs
        IHopRelayRegistry hrr;
        if (p.hops.length > 0) {
            hrr = IHopRelayRegistry(resolve("hop_relay_registry", false));
        }

        bytes32 _signal = signal;
        uint64 _chainId = chainId;
        address _app = app;

        // If a signal is sent from chainA -> chainB -> chainC (this chain), we verify the proofs in
        // the following order:
        // 1. using chainC's latest parent's stateRoot to verify that chainB's TaikoL1/TaikoL2
        // contract has
        // sent a given hop stateRoot on chainB using its own signal service.
        // 2. using the verified hop stateRoot to verify that the source app on chainA has sent a
        // signal using its own signal service.
        // We always verify the proofs in the reversed order (top to bottom).
        for (uint256 i; i < p.hops.length; ++i) {
            Hop memory hop = p.hops[i];

            bool isHopTrusted = hrr.isRelayRegistered(_chainId, hop.chainId, hop.relay);
            if (!isHopTrusted) revert SS_INVALID_RELAY();

            verifyMerkleProof(
                _chainId, _app, _signal, hop.rootHash, hop.isStateRoot, hop.merkleProof
            );

            if (hop.cacheRootHash) {
                if (hop.isStateRoot) _relayStateRoot(_chainId, hop.rootHash);
                else _relaySignalRoot(_chainId, hop.rootHash);
            }

            _signal = hop.isStateRoot
                ? LibSignals.signalForStateRoot(_chainId, hop.rootHash)
                : LibSignals.signalForSignalRoot(_chainId, hop.rootHash);

            _chainId = hop.chainId;
            _app = hop.relay;
        }

        // check p.rootHash is trusted locally -- this is true only when it has been locally
        // relayed as a signal.
        bytes32 lastSignal = p.isStateRoot
            ? LibSignals.signalForStateRoot(_chainId, p.rootHash)
            : LibSignals.signalForSignalRoot(_chainId, p.rootHash);

        bool lastSignalRelayed = isSignalSent(resolve("taiko", false), lastSignal);
        if (!lastSignalRelayed) revert SS_INVALID_ROOT_HASH();

        bytes32 signalRoot =
            verifyMerkleProof(_chainId, _app, _signal, p.rootHash, p.isStateRoot, p.merkleProof);

        if (p.isStateRoot && p.cacheSignalServiceStorageRoot) {
            _relaySignalRoot(_chainId, signalRoot);
        }
        return true;
    }

    function verifyMerkleProof(
        uint64 chainId,
        address app,
        bytes32 signal,
        bytes32 rootHash,
        bool isStateRoot,
        bytes memory merkleProof
    )
        public
        view
        virtual
        returns (bytes32 signalRoot)
    {
        if (rootHash == 0) revert SS_INVALID_ROOT_HASH();
        if (merkleProof.length == 0) revert SS_INVALID_PROOF();

        bool verified;

        if (isStateRoot) {
            // TODO: verify against storage root
        } else {
            // TODO: verify against signal root
        }

        if (!verified) revert SS_INVALID_PROOF();
    }

    /// @notice Checks if multi-hop is enabled.
    /// @return Returns true if multi-hop bridging is enabled.
    function isMultiHopEnabled() public view virtual returns (bool) {
        return false;
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

    function _sendSignal(bytes32 signal) internal returns (bytes32 slot) {
        if (signal == 0) revert SS_INVALID_SIGNAL();
        slot = getSignalSlot(uint64(block.chainid), msg.sender, signal);
        assembly {
            sstore(slot, 1)
        }
    }

    function _relayStateRoot(uint64 chainId, bytes32 stateRoot) internal returns (bytes32) {
        if (chainId == block.chainid) revert SS_INVALID_PARAMS();
        emit StateRootRelayed(chainId, stateRoot);
        return _sendSignal(LibSignals.signalForStateRoot(chainId, stateRoot));
    }

    function _relaySignalRoot(uint64 chainId, bytes32 signalRoot) internal returns (bytes32) {
        if (chainId == block.chainid) revert SS_INVALID_PARAMS();
        emit SignalRootRelayed(chainId, signalRoot);
        return _sendSignal(LibSignals.signalForSignalRoot(chainId, signalRoot));
    }

    function _authorizePause(address) internal pure override {
        revert SS_UNSUPPORTED();
    }
}
