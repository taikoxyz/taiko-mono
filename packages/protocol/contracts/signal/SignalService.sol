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
import "./IHopRelayRegistry.sol";
import "./ISignalService.sol";

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
        address relay;
        bytes32 stateRoot;
        bytes merkleProof;
    }

    struct Proof {
        uint64 height;
        bytes merkleProof;
       // Ensure that hops are ordered such that those closer to the signal's source chain come before others.
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
    function init(address _addressManager) external initializer {
        __Essential_init(_addressManager);
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
        if (!isMultiHopEnabled() && p.hops.length > 0) {
            revert SS_MULTIHOP_DISABLED();
        }

        uint64 _srcChainId = srcChainId;
        address _srcApp = app;
        bytes32 _srcSignal = signal;

        // Verify hop proofs
        IHopRelayRegistry hrr;
        if (p.hops.length > 0) {
            hrr = IHopRelayRegistry(resolve("hop_relay_registry", false));
        }
        for (uint256 i; i < p.hops.length; ++i) {
            Hop memory hop = p.hops[i];

            if (!hrr.isRelayRegistered(_srcChainId, hop.chainId, hop.relay)) {
                revert SS_INVALID_RELAYER();
            }

            verifyMerkleProof(hop.stateRoot, _srcChainId, _srcApp, _srcSignal, hop.merkleProof);

            _srcChainId = hop.chainId;
            _srcApp = hop.relay;
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
        bytes memory merkleProof
    )
        public
        view
        virtual
    {
        if (stateRoot == 0) revert SS_INVALID_STATE_ROOT();
        if (merkleProof.length == 0) revert SS_INVALID_PROOF();

        bool verified;

        // TODO(dani): implement this please

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

    /// @notice Checks if we need to check real proof or it is a test.
    /// @return Returns true to skip checking inclusion proofs.
    function skipProofCheck() public pure virtual returns (bool) {
        return false;
    }

    function _authorizePause(address) internal pure override {
        revert SS_UNSUPPORTED();
    }
}
