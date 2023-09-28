// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { EssentialContract } from "../common/EssentialContract.sol";
import { ICrossChainSync } from "../common/ICrossChainSync.sol";
import { Proxied } from "../common/Proxied.sol";

import { LibMath } from "../libs/LibMath.sol";

import { Lib1559Math } from "./Lib1559Math.sol";
import { TaikoL2Signer } from "./TaikoL2Signer.sol";

/// @title TaikoL2
/// @notice Taiko L2 is a smart contract that handles cross-layer message
/// verification and manages EIP-1559 gas pricing for Layer 2 (L2) operations.
/// It is used to anchor the latest L1 block details to L2 for cross-layer
/// communication, manage EIP-1559 parameters for gas pricing, and store
/// verified L1 block information.
contract TaikoL2 is EssentialContract, TaikoL2Signer, ICrossChainSync {
    using LibMath for uint256;

    struct VerifiedBlock {
        bytes32 blockHash;
        bytes32 signalRoot;
    }

    struct Config {
        uint32 blockGasTarget;
        uint64 minBasefee;
        bool checkBasefee;
    }

    // Mapping from L2 block numbers to their block hashes.
    // All L2 block hashes will be saved in this mapping.
    mapping(uint256 blockId => bytes32 blockHash) private _l2Hashes;
    mapping(uint256 blockId => VerifiedBlock) private _l1VerifiedBlocks;

    // A hash to check the integrity of public inputs.
    bytes32 public publicInputHash; // slot 3
    uint64 public latestSyncedL1Height; // slot 4
    uint64 public basefee;

    uint256[146] private __gap;

    // Captures all block variables mentioned in
    // https://docs.soliditylang.org/en/v0.8.20/units-and-global-variables.html
    event Anchored(
        uint64 number,
        uint64 basefee,
        uint32 gaslimit,
        uint64 timestamp,
        bytes32 parentHash,
        uint256 prevrandao,
        address coinbase,
        uint64 chainid
    );

    error L2_BASEFEE_MISMATCH();
    error L2_INVALID_BASEFEE();
    error L2_INVALID_CHAIN_ID();
    error L2_INVALID_SENDER();
    error L2_PUBLIC_INPUT_HASH_MISMATCH();
    error L2_TOO_LATE();

    /// @notice Initializes the TaikoL2 contract.
    /// @param _addressManager Address of the {AddressManager} contract.
    function init(
        address _addressManager,
        uint64 _basefee
    )
        external
        initializer
    {
        EssentialContract._init(_addressManager);

        if (block.chainid <= 1 || block.chainid >= type(uint64).max) {
            revert L2_INVALID_CHAIN_ID();
        }
        if (block.number > 1) revert L2_TOO_LATE();

        Config memory config = getConfig();
        if (_basefee < config.minBasefee) revert L2_INVALID_BASEFEE();
        basefee = _basefee;

        (publicInputHash,,) = _calcPublicInputHash(block.number);

        if (block.number > 0) {
            uint256 parentHeight = block.number - 1;
            _l2Hashes[parentHeight] = blockhash(parentHeight);
        }
    }

    /// @notice Anchors the latest L1 block details to L2 for cross-layer
    /// message verification.
    /// @param l1Hash The latest L1 block hash when this block was proposed.
    /// @param l1SignalRoot The latest value of the L1 signal service storage
    /// root.
    /// @param l1Height The latest L1 block height when this block was proposed.
    /// @param parentGasUsed The gas used in the parent block.
    function anchor(
        bytes32 l1Hash,
        bytes32 l1SignalRoot,
        uint64 l1Height,
        uint32 parentGasUsed
    )
        external
    {
        unchecked {
            // Check the message sender must be the protocol specific golden
            // touch
            // address.
            if (msg.sender != GOLDEN_TOUCH_ADDRESS) revert L2_INVALID_SENDER();

            // Verify the base fee is correct
            Config memory config = getConfig();
            basefee = calcBasefee(basefee, parentGasUsed, config);
            if (config.checkBasefee && block.basefee != basefee) {
                revert L2_BASEFEE_MISMATCH();
            }

            (
                bytes32 _publicInputHash,
                bytes32 _publicInputHashNew,
                bytes32 _parentHash
            ) = _calcPublicInputHash(block.number - 1);

            // Verify the 256 ancestor block hashes match our record
            if (publicInputHash != _publicInputHash) {
                revert L2_PUBLIC_INPUT_HASH_MISMATCH();
            }

            // Replace the oldest block hash with the parent's blockhash
            publicInputHash = _publicInputHashNew;

            // Update other state data
            _l2Hashes[block.number - 1] = _parentHash;
            latestSyncedL1Height = l1Height;
            _l1VerifiedBlocks[l1Height] = VerifiedBlock(l1Hash, l1SignalRoot);

            // We emit this event so circuits can grab its data to verify block
            // variables.
            emit Anchored({
                number: uint64(block.number),
                basefee: basefee,
                gaslimit: uint32(block.gaslimit),
                timestamp: uint64(block.timestamp),
                parentHash: _parentHash,
                prevrandao: block.prevrandao,
                coinbase: block.coinbase,
                chainid: uint64(block.chainid)
            });

            emit CrossChainSynced(l1Height, l1Hash, l1SignalRoot);
        }
    }

    /// @inheritdoc ICrossChainSync
    function getCrossChainBlockHash(uint64 blockId)
        public
        view
        override
        returns (bytes32)
    {
        uint256 id = blockId == 0 ? latestSyncedL1Height : blockId;
        return _l1VerifiedBlocks[id].blockHash;
    }

    /// @inheritdoc ICrossChainSync
    function getCrossChainSignalRoot(uint64 blockId)
        public
        view
        override
        returns (bytes32)
    {
        uint256 id = blockId == 0 ? latestSyncedL1Height : blockId;
        return _l1VerifiedBlocks[id].signalRoot;
    }

    /// @notice Retrieves the block hash for the given L2 block number.
    /// @param blockId The L2 block number to retrieve the block hash for.
    /// @return The block hash for the specified L2 block id, or zero if the
    /// block id is greater than or equal to the current block number.
    function getBlockHash(uint64 blockId) public view returns (bytes32) {
        if (blockId >= block.number) {
            return 0;
        } else if (blockId < block.number && blockId >= block.number - 256) {
            return blockhash(blockId);
        } else {
            return _l2Hashes[blockId];
        }
    }

    function calcBasefee(
        uint256 prevBasefee,
        uint32 gasUsed,
        Config memory config
    )
        public
        pure
        returns (uint64)
    {
        uint256 _basefee =
            Lib1559Math.calcBasefee(prevBasefee, gasUsed, config.blockGasTarget);
        if (_basefee < config.minBasefee) {
            _basefee = config.minBasefee;
        }
        return uint64(_basefee.min(type(uint64).max));
    }

    function getConfig() public pure virtual returns (Config memory config) {
        config.blockGasTarget = 20_000_000;
        config.minBasefee = 1_000_000_000 / 10_000; // 1/10000 Gwei;
        config.checkBasefee = true;
    }

    function _calcPublicInputHash(uint256 blockId)
        private
        view
        returns (
            bytes32 _publicInputHash,
            bytes32 _publicInputHashNew,
            bytes32 _parentHash
        )
    {
        // This is a ring buffer to hash the block hashes.
        bytes32[256] memory inputs;

        // Unchecked is safe because it cannot overflow.
        unchecked {
            // Put the previous 255 block hashes (excluding the parent's) into a
            // ring buffer.
            for (uint256 i; i < 255 && blockId >= i + 1; ++i) {
                uint256 j = blockId - i - 1;
                inputs[j % 255] = blockhash(j);
            }
        }

        inputs[255] = bytes32(block.chainid);

        assembly {
            _publicInputHash := keccak256(inputs, 8192 /*mul(256, 32)*/ )
        }

        _parentHash = blockhash(blockId);
        inputs[blockId % 255] = _parentHash;
        assembly {
            _publicInputHashNew := keccak256(inputs, 8192 /*mul(256, 32)*/ )
        }
    }
}

/// @title ProxiedTaikoL2
/// @notice Proxied version of the TaikoL2 contract.
contract ProxiedTaikoL2 is Proxied, TaikoL2 { }
