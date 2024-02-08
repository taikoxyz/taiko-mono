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
import "../thirdparty/optimism/trie/SecureMerkleTrie.sol";
import "../thirdparty/optimism/rlp/RLPReader.sol";
import "./ISignalService.sol";
import "./MultihopGraph.sol";

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
        address relayer;
        bytes32 stateRoot;
        bytes[] merkleProof;
    }

    struct Proof {
        uint64 height;
        bytes[] merkleProof;
        Hop[] hops;
    }

    uint256[50] private __gap;

    error SS_INVALID_PARAMS();
    error SS_INVALID_PROOF();
    error SS_INVALID_APP();
    error SS_INVALID_RELAYER();
    error SS_INVALID_SIGNAL();
    error SS_INVALID_STATE_ROOT();
    error SS_MULTIHOP_DISABLED();
    error SS_UNSUPPORTED();

    /// @dev Initializer to be called after being deployed behind a proxy.
    function init() external initializer {
        __OwnerUUPSUpgradable_init();
    }

    /// @inheritdoc ISignalService
    function sendSignal(bytes32 signal) public returns (bytes32 slot) {
        if (signal == 0) revert SS_INVALID_SIGNAL();
        slot = getSignalSlot(uint64(block.chainid), msg.sender, signal);
        assembly {
            sstore(slot, 1)
        }
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
        uint64 srcChainId,
        address app,
        bytes32 signal,
        bytes calldata proof
    )
        public
        view
        virtual
        returns (bool)
    {
        if (skipProofCheck()) return true;

        if (app == address(0) || signal == 0 || srcChainId == 0 || srcChainId == block.chainid) {
            revert SS_INVALID_PARAMS();
        }

        Proof memory p = abi.decode(proof, (Proof));
        if (!isMultihopEnabled() && p.hops.length > 0) {
            revert SS_MULTIHOP_DISABLED();
        }

        uint64 _srcChainId = srcChainId;
        address _srcApp = app;
        bytes32 _srcSignal = signal;

        // Verify hop proofs
        IMultihopGraph graph;
        if (p.hops.length > 0) {
            graph = IMultihopGraph(resolve("multihop_graph", false));
        }
        for (uint256 i; i < p.hops.length; ++i) {
            Hop memory hop = p.hops[i];

            if (!graph.isTrustedRelayer(_srcChainId, hop.chainId, hop.relayer)) {
                revert SS_INVALID_RELAYER();
            }

            verifyMerkleProof(hop.stateRoot, _srcChainId, _srcApp, _srcSignal, hop.merkleProof);

            _srcChainId = hop.chainId;
            _srcApp = hop.relayer;
            _srcSignal = hop.stateRoot;
        }

        ICrossChainSync ccs = ICrossChainSync(resolve("taiko", false));
        bytes32 stateRoot = ccs.getSyncedSnippet(p.height).stateRoot;

        verifyMerkleProof(stateRoot, _srcChainId, _srcApp, _srcSignal, p.merkleProof);

        return true;
    }

    function verifyMerkleProof(
        bytes32 stateRoot,
        uint64 srcChainId,
        address srcApp,
        bytes32 srcSignal,
        bytes[] memory merkleProof
    )
        public
        view
        virtual
    {
        if (stateRoot == 0) revert SS_INVALID_STATE_ROOT();
        if (merkleProof.length == 0) revert SS_INVALID_PROOF();

        // I do not think this line is needed here.
        //address signalService = resolve(srcChainId, "signal_service", false);
        // TODO: we need to use this signal service

        bytes32 slot = getSignalSlot(srcChainId, srcApp, srcSignal);
        bool verified = SecureMerkleTrie.verifyInclusionProof(
            bytes.concat(slot), hex"01", merkleProof, stateRoot
        );

        if (!verified) revert SS_INVALID_PROOF();
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

    /// @notice Tells if we need to check real proof or it is a test.
    /// @return Returns true to skip checking inclusion proofs.
    function skipProofCheck() public pure virtual returns (bool) {
        return false;
    }

    function isMultihopEnabled() public pure virtual returns (bool) {
        return false;
    }

    function _authorizePause(address) internal pure override {
        revert SS_UNSUPPORTED();
    }
}
