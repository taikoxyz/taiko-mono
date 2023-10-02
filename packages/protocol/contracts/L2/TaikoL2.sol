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

import { Lib1559Math } from "./1559/Lib1559Math.sol";
import { TaikoL2Signer } from "./TaikoL2Signer.sol";

/// @title TaikoL2
/// @notice Taiko L2 is a smart contract that handles cross-layer message
/// verification and manages EIP-1559 gas pricing for Layer 2 (L2) operations.
/// It is used to anchor the latest L1 block details to L2 for cross-layer
/// communication, manage EIP-1559 parameters for gas pricing, and store
/// verified L1 block information.
contract TaikoL2 is EssentialContract, TaikoL2Signer, ICrossChainSync {
    using LibMath for uint256;

    uint64 public constant GAS_TARGET_PER_L1_BLOCK = 150 * 1e6;
    uint64 public constant ADJUSTMENT_QUOTIENT = 8;

    struct VerifiedBlock {
        bytes32 blockHash;
        bytes32 signalRoot;
    }

    // Mapping from L2 block numbers to their block hashes.
    // All L2 block hashes will be saved in this mapping.
    mapping(uint256 blockId => bytes32 blockHash) private _l2Hashes;
    mapping(uint256 blockId => VerifiedBlock) private _l1VerifiedBlocks;

    // A hash to check the integrity of public inputs.
    bytes32 public publicInputHash; // slot 3
    uint128 public gasExcess;
    uint64 public latestSyncedL1Height;

    uint256[146] private __gap;

    // Captures all block variables mentioned in
    // https://docs.soliditylang.org/en/v0.8.20/units-and-global-variables.html
    event Anchored(
        uint64 number,
        uint256 basefee,
        uint32 gaslimit,
        uint64 timestamp,
        bytes32 parentHash,
        uint256 prevrandao,
        address coinbase,
        uint64 chainid
    );

    error L2_BASEFEE_MISMATCH();
    error L2_INVALID_1559_PARAMS();
    error L2_INVALID_CHAIN_ID();
    error L2_INVALID_SENDER();
    error L2_PUBLIC_INPUT_HASH_MISMATCH();
    error L2_TOO_LATE();

    /// @notice Initializes the TaikoL2 contract.
    /// @param _addressManager Address of the {AddressManager} contract.
    function init(
        address _addressManager,
        uint128 _gasExcess
    )
        external
        initializer
    {
        EssentialContract._init(_addressManager);

        if (block.chainid <= 1 || block.chainid >= type(uint64).max) {
            revert L2_INVALID_CHAIN_ID();
        }
        if (block.number > 1) revert L2_TOO_LATE();

        (publicInputHash,) = _calcPublicInputHash(block.number);

        gasExcess = _gasExcess;

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
        if (msg.sender != GOLDEN_TOUCH_ADDRESS) revert L2_INVALID_SENDER();

        // verify ancestor hashes
        (bytes32 publicInputHashOld, bytes32 publicInputHashNew) =
            _calcPublicInputHash(block.number - 1);
        if (publicInputHash != publicInputHashOld) {
            revert L2_PUBLIC_INPUT_HASH_MISMATCH();
        }
        publicInputHash = publicInputHashNew;

        // Verify the base fee per gas is correct
        if (block.basefee != _update1559BaseFee(l1Height, parentGasUsed)) {
            revert L2_BASEFEE_MISMATCH();
        }

        bytes32 parentHash = blockhash(block.number - 1);
        _l2Hashes[block.number - 1] = parentHash;
        latestSyncedL1Height = l1Height;
        _l1VerifiedBlocks[l1Height] = VerifiedBlock(l1Hash, l1SignalRoot);

        emit CrossChainSynced(l1Height, l1Hash, l1SignalRoot);

        // We emit this event so circuits can grab its data to verify block
        // variables.
        // If plonk lookup table already has all these data, we can still use
        // this event for debugging purpose.
        emit Anchored({
            number: uint64(block.number),
            basefee: block.basefee,
            gaslimit: uint32(block.gaslimit),
            timestamp: uint64(block.timestamp),
            parentHash: parentHash,
            prevrandao: block.prevrandao,
            coinbase: block.coinbase,
            chainid: uint64(block.chainid)
        });
    }

    function _update1559BaseFee(
        uint64 l1Height,
        uint32 gasInBlock
    )
        private
        returns (uint256 baseFeePerGas)
    {
        if (gasExcess == 0) return 1;

        (baseFeePerGas, gasExcess) = Lib1559Math.calcBaseFee({
            numL1Blocks: l1Height - latestSyncedL1Height,
            gasExcessIssued: gasExcess,
            gasInBlock: gasInBlock,
            gasTarget: GAS_TARGET_PER_L1_BLOCK,
            adjustmentQuotient: ADJUSTMENT_QUOTIENT
        });
        if (gasExcess == 0) gasExcess = 1;
    }

    /// @notice Gets the basefee and gas excess using EIP-1559 configuration for
    /// the given parameters.
    /// @param numL1Blocks Time elapsed since the parent block's timestamp.
    /// @param gasInBlock Gas used in the parent block.
    /// @return baseFeePerGas The calculated EIP-1559 base fee per gas.
    function getBasefee(
        uint64 numL1Blocks,
        uint32 gasInBlock
    )
        public
        view
        returns (uint256 baseFeePerGas)
    {
        // TODO
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

    function _calcPublicInputHash(uint256 blockId)
        private
        view
        returns (bytes32 publicInputHashOld, bytes32 publicInputHashNew)
    {
        bytes32[256] memory inputs;

        // Unchecked is safe because it cannot overflow.
        unchecked {
            // Put the previous 255 blockhashes (excluding the parent's) into a
            // ring buffer.
            for (uint256 i; i < 255 && blockId >= i + 1; ++i) {
                uint256 j = blockId - i - 1;
                inputs[j % 255] = blockhash(j);
            }
        }

        inputs[255] = bytes32(block.chainid);

        assembly {
            publicInputHashOld := keccak256(inputs, 8192 /*mul(256, 32)*/ )
        }

        inputs[blockId % 255] = blockhash(blockId);
        assembly {
            publicInputHashNew := keccak256(inputs, 8192 /*mul(256, 32)*/ )
        }
    }
}

/// @title ProxiedTaikoL2
/// @notice Proxied version of the TaikoL2 contract.
contract ProxiedTaikoL2 is Proxied, TaikoL2 { }
