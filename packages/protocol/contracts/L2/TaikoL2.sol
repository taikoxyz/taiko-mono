// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { EssentialContract } from "../common/EssentialContract.sol";
import { ICrossChainSync } from "../common/ICrossChainSync.sol";
import { Lib1559Math } from "../libs/Lib1559Math.sol";
import { LibMath } from "../libs/LibMath.sol";
import { Proxied } from "../common/Proxied.sol";
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

    struct EIP1559Params {
        uint64 basefee;
        uint32 gasIssuedPerSecond;
        uint64 gasExcessMax;
        uint64 gasTarget;
        uint64 ratio2x1x;
    }

    struct EIP1559Config {
        uint128 yscale;
        uint64 xscale;
        uint32 gasIssuedPerSecond;
    }

    // Mapping from L2 block numbers to their block hashes.
    // All L2 block hashes will be saved in this mapping.
    mapping(uint256 blockId => bytes32 blockHash) private _l2Hashes;
    mapping(uint256 blockId => VerifiedBlock) private _l1VerifiedBlocks;

    // A hash to check the integrity of public inputs.
    bytes32 public publicInputHash; // slot 3

    EIP1559Config public eip1559Config; // slot 4

    uint64 public parentTimestamp; // slot 5
    uint64 public latestSyncedL1Height;
    uint64 public gasExcess;
    uint64 private __reserved1;

    uint256[145] private __gap;

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

    event EIP1559ConfigUpdated(EIP1559Config config, uint64 gasExcess);

    error L2_BASEFEE_MISMATCH();
    error L2_INVALID_1559_PARAMS();
    error L2_INVALID_CHAIN_ID();
    error L2_INVALID_SENDER();
    error L2_PUBLIC_INPUT_HASH_MISMATCH();
    error L2_TOO_LATE();

    /// @notice Initializes the TaikoL2 contract.
    /// @param _addressManager Address of the {AddressManager} contract.
    /// @param _param1559 EIP-1559 parameters to set up the gas pricing model.
    function init(
        address _addressManager,
        EIP1559Params calldata _param1559
    )
        external
        initializer
    {
        EssentialContract._init(_addressManager);

        if (block.chainid <= 1 || block.chainid >= type(uint64).max) {
            revert L2_INVALID_CHAIN_ID();
        }
        if (block.number > 1) revert L2_TOO_LATE();

        parentTimestamp = uint64(block.timestamp);
        (publicInputHash,) = _calcPublicInputHash(block.number);

        if (block.number > 0) {
            uint256 parentHeight = block.number - 1;
            _l2Hashes[parentHeight] = blockhash(parentHeight);
        }

        updateEIP1559Config(_param1559);
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

        uint256 parentHeight = block.number - 1;
        bytes32 parentHash = blockhash(parentHeight);

        (bytes32 prevPIH, bytes32 currPIH) = _calcPublicInputHash(parentHeight);

        if (publicInputHash != prevPIH) {
            revert L2_PUBLIC_INPUT_HASH_MISMATCH();
        }

        // Replace the oldest block hash with the parent's blockhash
        publicInputHash = currPIH;
        _l2Hashes[parentHeight] = parentHash;

        latestSyncedL1Height = l1Height;
        _l1VerifiedBlocks[l1Height] = VerifiedBlock(l1Hash, l1SignalRoot);

        emit CrossChainSynced(l1Height, l1Hash, l1SignalRoot);

        // Check EIP-1559 basefee
        uint256 basefee;
        EIP1559Config memory config = getEIP1559Config();
        if (config.gasIssuedPerSecond != 0) {
            (basefee, gasExcess) = _calcBasefee({
                config: config,
                timeSinceParent: block.timestamp - parentTimestamp,
                parentGasUsed: parentGasUsed
            });
        }

        // On L2, basefee is not burnt, but sent to a treasury instead.
        // The circuits will need to verify the basefee recipient is the
        // designated address.
        if (block.basefee != basefee) {
            revert L2_BASEFEE_MISMATCH();
        }

        parentTimestamp = uint64(block.timestamp);

        // We emit this event so circuits can grab its data to verify block
        // variables.
        // If plonk lookup table already has all these data, we can still use
        // this event for debugging purpose.
        emit Anchored({
            number: uint64(block.number),
            basefee: uint64(basefee),
            gaslimit: uint32(block.gaslimit),
            timestamp: uint64(block.timestamp),
            parentHash: parentHash,
            prevrandao: block.prevrandao,
            coinbase: block.coinbase,
            chainid: uint64(block.chainid)
        });
    }

    /// @notice Updates EIP-1559 configurations.
    /// @param _param1559 EIP-1559 parameters to set up the gas pricing model.
    function updateEIP1559Config(EIP1559Params calldata _param1559)
        public
        onlyOwner
    {
        if (_param1559.gasIssuedPerSecond == 0) {
            delete eip1559Config;
            delete gasExcess;
        } else {
            if (
                _param1559.basefee == 0 || _param1559.gasExcessMax == 0
                    || _param1559.gasTarget == 0 || _param1559.ratio2x1x == 0
            ) revert L2_INVALID_1559_PARAMS();

            (uint128 xscale, uint128 yscale) = Lib1559Math.calculateScales({
                xExcessMax: _param1559.gasExcessMax,
                price: _param1559.basefee,
                target: _param1559.gasTarget,
                ratio2x1x: _param1559.ratio2x1x
            });

            if (xscale == 0 || xscale >= type(uint64).max || yscale == 0) {
                revert L2_INVALID_1559_PARAMS();
            }
            eip1559Config.yscale = yscale;
            eip1559Config.xscale = uint64(xscale);
            eip1559Config.gasIssuedPerSecond = _param1559.gasIssuedPerSecond;

            gasExcess = _param1559.gasExcessMax / 2;
        }

        emit EIP1559ConfigUpdated(eip1559Config, gasExcess);
    }

    /// @notice Gets the basefee and gas excess using EIP-1559 configuration for
    /// the given parameters.
    /// @param timeSinceParent Time elapsed since the parent block's timestamp.
    /// @param parentGasUsed Gas used in the parent block.
    /// @return _basefee The calculated EIP-1559 basefee.
    function getBasefee(
        uint64 timeSinceParent,
        uint32 parentGasUsed
    )
        public
        view
        returns (uint256 _basefee)
    {
        (_basefee,) = _calcBasefee({
            config: getEIP1559Config(),
            timeSinceParent: timeSinceParent,
            parentGasUsed: parentGasUsed
        });
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

    /// @notice Retrieves the current EIP-1559 configuration details.
    /// @return The current EIP-1559 configuration details, including the
    /// yscale, xscale, and gasIssuedPerSecond parameters.
    function getEIP1559Config()
        public
        view
        virtual
        returns (EIP1559Config memory)
    {
        return eip1559Config;
    }

    function _calcPublicInputHash(uint256 blockId)
        private
        view
        returns (bytes32 prevPIH, bytes32 currPIH)
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
            prevPIH := keccak256(inputs, mul(256, 32))
        }

        inputs[blockId % 255] = blockhash(blockId);
        assembly {
            currPIH := keccak256(inputs, mul(256, 32))
        }
    }

    function _calcBasefee(
        EIP1559Config memory config,
        uint256 timeSinceParent,
        uint32 parentGasUsed
    )
        private
        view
        returns (uint256 _basefee, uint64 _gasExcess)
    {
        // Unchecked is safe because:
        // - gasExcess is capped at uint64 max ever, so multiplying with a
        // uint32 value is safe
        // - 'excess' is bigger than 'issued'
        unchecked {
            uint256 issued = timeSinceParent * config.gasIssuedPerSecond;
            uint256 excess = (uint256(gasExcess) + parentGasUsed).max(issued);
            // Very important to cap _gasExcess uint64
            _gasExcess = uint64((excess - issued).min(type(uint64).max));
        }

        _basefee = Lib1559Math.calculatePrice({
            xscale: config.xscale,
            yscale: config.yscale,
            xExcess: _gasExcess,
            xPurchase: 0
        });

        if (_basefee == 0) {
            // To make sure when EIP-1559 is enabled, the basefee is non-zero
            // (Geth never uses 0 values for basefee)
            _basefee = 1;
        }
    }
}

/// @title ProxiedTaikoL2
/// @notice Proxied version of the TaikoL2 contract.
contract ProxiedTaikoL2 is Proxied, TaikoL2 { }
