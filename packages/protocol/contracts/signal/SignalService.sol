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
import "../common/AuthorizableContract.sol";
import "../common/ICrossChainSync.sol";
import "../libs/LibTrieProof.sol";
import "../thirdparty/optimism/trie/SecureMerkleTrie.sol";
import "../thirdparty/optimism/rlp/RLPReader.sol";
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
contract SignalService is AuthorizableContract, ISignalService {
    using SafeCast for uint256;

    // merkleProof represents ABI-encoded tuple of (key, value, and proof)
    // returned from the eth_getProof() API.
    struct Hop {
        address relayerContract;
        bytes32 stateRoot;
        bytes merkleProof; // Merkle proof consists of account proof and storage proof encoded (concatenated) together.
    }

    struct Proof {
        address crossChainSync;
        uint64 height;
        bytes merkleProof; // Merkle proof consists of account proof and storage proof encoded (concatenated) together.
        Hop[] hops;
    }

    error SS_INVALID_FUNC_PARAMS();
    error SS_INVALID_PROOF_PARAMS();
    error SS_CROSS_CHAIN_SYNC_UNAUTHORIZED(uint256 chaindId);
    error SS_CROSS_CHAIN_SYNC_ZERO_STATE_ROOT();
    error SS_HOP_RELAYER_UNAUTHORIZED();
    error SS_INVALID_APP();
    error SS_INVALID_APP_PROOF();
    error SS_INVALID_HOP_PROOF();
    error SS_INVALID_SIGNAL();
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
            revert SS_INVALID_FUNC_PARAMS();
        }

        Proof memory p = abi.decode(proof, (Proof));
        if (p.crossChainSync == address(0) || p.merkleProof.length == 0) {
            revert SS_INVALID_PROOF_PARAMS();
        }

        for (uint256 i; i < p.hops.length; ++i) {
            if (p.hops[i].stateRoot == 0 || p.hops[i].merkleProof.length == 0) {
                revert SS_INVALID_PROOF_PARAMS();
            }
        }

        // p.crossChainSync is either a TaikoL1 contract or a TaikoL2 contract
        if (!isAuthorizedAs(p.crossChainSync, bytes32(block.chainid))) {
            revert SS_CROSS_CHAIN_SYNC_UNAUTHORIZED(block.chainid);
        }

        bytes32 stateRoot = ICrossChainSync(p.crossChainSync).getSyncedSnippet(p.height).stateRoot;
        if (stateRoot == 0) revert SS_CROSS_CHAIN_SYNC_ZERO_STATE_ROOT();

        // If a signal is sent from chainA -> chainB -> chainC (this chain), we verify the proofs in
        // the following order:
        // 1. using chainC's latest stateRoot to verify that chainB's TaikoL1/TaikoL2 contract has
        // sent a given hop stateRoot on chainB using its own signal service.
        // 2. using the verified hop stateRoot to verify that the source app on chainA has sent a
        // signal using its own signal service.
        // We always verify the proofs in the reversed order.
        for (uint256 i; i < p.hops.length; ++i) {
            Hop memory hop = p.hops[i];
            if (hop.stateRoot == stateRoot) revert SS_INVALID_HOP_PROOF();

            bytes32 label = authorizedAddresses[hop.relayerContract];
            if (label == 0) revert SS_HOP_RELAYER_UNAUTHORIZED();

            uint64 hopChainId = uint256(label).toUint64();

            verifyMerkleProof(
                stateRoot, hopChainId, hop.relayerContract, hop.stateRoot, hop.merkleProof
            );
            stateRoot = hop.stateRoot;
        }

        verifyMerkleProof(stateRoot, srcChainId, app, signal, p.merkleProof);
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
        address signalService = resolve(srcChainId, "signal_service", false);

        bytes32 slot = getSignalSlot(srcChainId, srcApp, srcSignal);
        bool verified = LibTrieProof.verifyWithAccountProof(stateRoot, signalService, slot, hex"01", merkleProof);

        if (!verified) revert SS_INVALID_APP_PROOF();
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

    function _authorizePause(address) internal pure override {
        revert SS_UNSUPPORTED();
    }
}
