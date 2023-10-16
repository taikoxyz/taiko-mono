// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { EssentialContract } from "../common/EssentialContract.sol";
import { ICrossChainSync } from "../common/ICrossChainSync.sol";
import { ISignalService } from "../signal/ISignalService.sol";
import { Proxied } from "../common/Proxied.sol";
import { LibMath } from "../libs/LibMath.sol";
import { TaikoToken } from "../L1/TaikoToken.sol";

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

    struct Config {
        uint64 gasTargetPerL1Block;
        uint256 basefeeAdjustmentQuotient;
        uint256 blockRewardPerL1Block;
        uint128 blockRewardPoolMax;
        uint8 blockRewardPoolPctg;
    }

    // TODO(david): figure out this value from internal devnet.
    uint32 public constant ANCHOR_GAS_DEDUCT = 40_000;

    // Mapping from L2 block numbers to their block hashes.
    // All L2 block hashes will be saved in this mapping.
    mapping(uint256 blockId => bytes32 blockHash) public l2Hashes;
    mapping(uint256 l1height => ICrossChainSync.Snippet) public snippets;

    // A hash to check the integrity of public inputs.
    bytes32 public publicInputHash; // slot 3

    uint128 public gasExcess; // slot 4
    uint128 public accumulatedReward;

    address public parentProposer; // slot 5
    uint64 public latestSyncedL1Height;
    uint32 public avgGasUsed;

    uint256[145] private __gap;

    event Anchored(bytes32 parentHash, uint128 gasExcess, uint128 blockReward);

    error L2_BASEFEE_MISMATCH();
    error L2_INVALID_CHAIN_ID();
    error L2_INVALID_SENDER();
    error L2_GAS_EXCESS_TOO_LARGE();
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

        if (block.number > 0) {
            uint256 parentHeight = block.number - 1;
            l2Hashes[parentHeight] = blockhash(parentHeight);
        }

        gasExcess = _gasExcess;
        (publicInputHash,) = _calcPublicInputHash(block.number);
    }

    /// @notice Anchors the latest L1 block details to L2 for cross-layer
    /// message verification.
    /// @param l1BlockHash The latest L1 block hash when this block was
    /// proposed.
    /// @param l1SignalRoot The latest value of the L1 signal root.
    /// @param l1Height The latest L1 block height when this block was proposed.
    /// @param parentGasUsed The gas used in the parent block.
    function anchor(
        bytes32 l1BlockHash,
        bytes32 l1SignalRoot,
        uint64 l1Height,
        uint32 parentGasUsed
    )
        external
    {
        if (msg.sender != GOLDEN_TOUCH_ADDRESS) revert L2_INVALID_SENDER();

        uint256 parentId;
        unchecked {
            parentId = block.number - 1;
        }

        // Verify ancestor hashes
        (bytes32 publicInputHashOld, bytes32 publicInputHashNew) =
            _calcPublicInputHash(parentId);
        if (publicInputHash != publicInputHashOld) {
            revert L2_PUBLIC_INPUT_HASH_MISMATCH();
        }

        Config memory config = getConfig();

        // Verify the base fee per gas is correct
        uint256 basefee;
        (basefee, gasExcess) = _calc1559BaseFee(config, l1Height, parentGasUsed);
        if (block.basefee != basefee) {
            revert L2_BASEFEE_MISMATCH();
        }

        // Store the L1's signal root as a signal to the local signal service to
        // allow for multi-hop bridging.
        if (l1SignalRoot != 0) {
            ISignalService(resolve("signal_service", false)).sendSignal(
                l1SignalRoot
            );
        }
        emit CrossChainSynced(l1Height, l1BlockHash, l1SignalRoot);

        // Reward block reward in Taiko token to the parent block's proposer
        uint128 blockReward =
            _rewardParentBlock(config, l1Height, parentGasUsed);

        // Update state variables
        l2Hashes[parentId] = blockhash(parentId);
        snippets[l1Height] = ICrossChainSync.Snippet(l1BlockHash, l1SignalRoot);
        publicInputHash = publicInputHashNew;
        latestSyncedL1Height = l1Height;
        parentProposer = block.coinbase;

        emit Anchored(blockhash(parentId), gasExcess, blockReward);
    }

    /// @inheritdoc ICrossChainSync
    function getSyncedSnippet(uint64 blockId)
        public
        view
        override
        returns (ICrossChainSync.Snippet memory)
    {
        uint256 id = blockId == 0 ? latestSyncedL1Height : blockId;
        return snippets[id];
    }

    /// @notice Gets the basefee and gas excess using EIP-1559 configuration for
    /// the given parameters.
    /// @param l1Height The synced L1 height in the next Taiko block
    /// @param parentGasUsed Gas used in the parent block.
    /// @return basefee The calculated EIP-1559 base fee per gas.
    function getBasefee(
        uint64 l1Height,
        uint32 parentGasUsed
    )
        public
        view
        returns (uint256 basefee)
    {
        (basefee,) = _calc1559BaseFee(getConfig(), l1Height, parentGasUsed);
    }

    /// @notice Retrieves the block hash for the given L2 block number.
    /// @param blockId The L2 block number to retrieve the block hash for.
    /// @return The block hash for the specified L2 block id, or zero if the
    /// block id is greater than or equal to the current block number.
    function getBlockHash(uint64 blockId) public view returns (bytes32) {
        if (blockId >= block.number) return 0;
        if (blockId >= block.number - 256) return blockhash(blockId);
        return l2Hashes[blockId];
    }

    /// @notice Returns EIP1559 related configurations
    function getConfig() public pure virtual returns (Config memory config) {
        config.gasTargetPerL1Block = 15 * 1e6 * 10; // 10x Ethereum gas target
        config.basefeeAdjustmentQuotient = 8;
        config.blockRewardPerL1Block = 1e15; // 0.001 Taiko token;
        config.blockRewardPoolMax = 12e18; // 12 Taiko token
        config.blockRewardPoolPctg = 40; // 40%
    }

    // In situations where the network lacks sufficient transactions for the
    // proposer to profit, they are still obligated to pay the prover the
    // proving fee, which can be a substantial cost compared to the total L2
    // transaction fees collected. As a solution, Taiko mints additional Taiko
    // tokens per second as block rewards.
    //
    // The block reward doesn't undergo automatic halving; instead, we depend on
    // Taiko DAO to make necessary adjustments to the rewards. uint96
    // rewardBase;
    //
    // Reward block proposers with Taiko tokens to encourage chain adoption and
    // ensure liveness. Rewards are issued only if `blockRewardPerL1Block` and
    // `blockRewardPoolMax` are set to nonzero values in the configuration.
    //
    // Mint additional tokens into the reward pool as L1 block numbers increase,
    // to incentivize future proposers.
    function _rewardParentBlock(
        Config memory config,
        uint64 l1Height,
        uint32 parentGasUsed
    )
        private
        returns (uint128 blockReward)
    {
        if (
            config.blockRewardPerL1Block == 0 || config.blockRewardPoolMax == 0
                || config.blockRewardPoolPctg == 0 || latestSyncedL1Height == 0
                || accumulatedReward == 0
        ) return 0;

        if (latestSyncedL1Height < l1Height) {
            uint256 extraRewardMinted = uint256(l1Height - latestSyncedL1Height)
                * config.blockRewardPerL1Block;

            // Reward pool is capped to `blockRewardPoolMax`
            accumulatedReward = uint128(
                (extraRewardMinted + accumulatedReward).min(
                    config.blockRewardPoolMax
                )
            );
        }

        if (avgGasUsed == 0) {
            avgGasUsed = parentGasUsed;
            return 0;
        }

        avgGasUsed = avgGasUsed / 1024 * 1023 + parentGasUsed / 1024;

        uint128 maxBlockReward =
            accumulatedReward / 100 * config.blockRewardPoolPctg;
        accumulatedReward -= maxBlockReward;

        if (
            parentGasUsed <= ANCHOR_GAS_DEDUCT
                || avgGasUsed <= ANCHOR_GAS_DEDUCT || parentProposer == address(0)
        ) {
            return 0;
        }

        address tt = resolve("taiko_token", true);
        if (tt == address(0)) return 0;

        // The ratio is in [0-200]
        uint128 ratio = uint128(
            (
                uint256(parentGasUsed - ANCHOR_GAS_DEDUCT) * 100
                    / (avgGasUsed - ANCHOR_GAS_DEDUCT)
            ).min(200)
        );

        blockReward = maxBlockReward * ratio / 200;
        TaikoToken(tt).mint(parentProposer, blockReward);
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

    function _calc1559BaseFee(
        Config memory config,
        uint64 l1Height,
        uint32 parentGasUsed
    )
        private
        view
        returns (uint256 _basefee, uint128 _gasExcess)
    {
        // gasExcess being 0 indicate the dynamic 1559 base fee is disabled.
        if (gasExcess > 0) {
            // We always add the gas used by parent block to the gas excess
            // value as this has already happend
            uint256 excess = uint256(gasExcess) + parentGasUsed;

            // Calculate how much more gas to issue to offset gas excess.
            // after each L1 block time, config.gasTarget more gas is issued,
            // the gas excess will be reduced accordingly.
            // Note that when latestSyncedL1Height is zero, we skip this step.
            uint128 numL1Blocks;
            if (latestSyncedL1Height > 0 && l1Height > latestSyncedL1Height) {
                numL1Blocks = l1Height - latestSyncedL1Height;
            }

            if (numL1Blocks > 0) {
                uint128 issuance = numL1Blocks * config.gasTargetPerL1Block;
                excess = excess > issuance ? excess - issuance : 1;
            }

            _gasExcess = uint128(excess.min(type(uint128).max));

            // The base fee per gas used by this block is the spot price at the
            // bonding curve, regardless the actual amount of gas used by this
            // block, however, the this block's gas used will affect the next
            // block's base fee.
            _basefee = Lib1559Math.basefee(
                _gasExcess,
                config.basefeeAdjustmentQuotient * config.gasTargetPerL1Block
            );
        }

        // Always make sure basefee is nonzero, this is required by the node.
        if (_basefee == 0) _basefee = 1;
    }
}

/// @title ProxiedTaikoL2
/// @notice Proxied version of the TaikoL2 contract.
contract ProxiedTaikoL2 is Proxied, TaikoL2 { }
