// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import {EssentialContract} from "../common/EssentialContract.sol";
import {IXchainSync} from "../common/IXchainSync.sol";
import {TaikoL2Signer} from "./TaikoL2Signer.sol";

contract TaikoL2 is EssentialContract, TaikoL2Signer, IXchainSync {
    struct VerifiedBlock {
        bytes32 blockHash;
        bytes32 signalRoot;
    }
    /**********************
     * State Variables    *
     **********************/

    // Mapping from L2 block numbers to their block hashes.
    // All L2 block hashes will be saved in this mapping.
    mapping(uint256 blockNumber => bytes32 blockHash) private _l2Hashes;

    mapping(uint256 blockNumber => VerifiedBlock) private _l1VerifiedBlocks;

    // A hash to check te integrity of public inputs.
    bytes32 public publicInputHash;

    // The latest L1 block where a L2 block has been proposed.
    uint256 public latestSyncedL1Height;

    uint256[46] private __gap;

    /**********************
     * Events and Errors  *
     **********************/

    // Captures all block variables mentioned in
    // https://docs.soliditylang.org/en/v0.8.18/units-and-global-variables.html
    event BlockVars(
        uint256 number,
        bytes32 parentHash,
        uint256 timestamp,
        uint256 basefee,
        uint256 prevrandao,
        address coinbase,
        uint256 gaslimit,
        uint256 chainid
    );

    error L2_INVALID_CHAIN_ID();
    error L2_INVALID_SENDER();
    error L2_PUBLIC_INPUT_HASH_MISMATCH();
    error L2_TOO_LATE();

    /**********************
     * Constructor         *
     **********************/

    function init(address _addressManager) external initializer {
        if (block.chainid <= 1) revert L2_INVALID_CHAIN_ID();
        if (block.number > 1) revert L2_TOO_LATE();

        EssentialContract._init(_addressManager);

        (publicInputHash, ) = _calcPublicInputHash(block.number);
        if (block.number > 0) {
            uint256 parentHeight = block.number - 1;
            _l2Hashes[parentHeight] = blockhash(parentHeight);
        }
    }

    /**********************
     * External Functions *
     **********************/

    /**
     * Persist the latest L1 block height and hash to L2 for cross-layer
     * message verification (eg. bridging). This function will also check
     * certain block-level global variables because they are not part of the
     * Trie structure.
     *
     * A circuit will verify the integrity among:
     * -  l1Hash, l1SignalRoot, and l1SignalServiceAddress
     * -  (l1Hash and l1SignalServiceAddress) are both hashed into of the
     *    ZKP's instance.
     *
     * This transaction shall be the first transaction in every L2 block.
     *
     * @param l1Height The latest L1 block height when this block was proposed.
     * @param l1Hash The latest L1 block hash when this block was proposed.
     * @param l1SignalRoot The latest value of the L1 "signal service storage root".
     */

    function anchor(
        uint256 l1Height,
        bytes32 l1Hash,
        bytes32 l1SignalRoot
    ) external {
        if (msg.sender != GOLDEN_TOUCH_ADDRESS) revert L2_INVALID_SENDER();

        uint256 parentHeight = block.number - 1;
        bytes32 parentHash = blockhash(parentHeight);

        (bytes32 prevPIH, bytes32 currPIH) = _calcPublicInputHash(parentHeight);

        if (publicInputHash != prevPIH) {
            revert L2_PUBLIC_INPUT_HASH_MISMATCH();
        }

        // replace the oldest block hash with the parent's blockhash

        publicInputHash = currPIH;
        _l2Hashes[parentHeight] = parentHash;

        latestSyncedL1Height = l1Height;
        _l1VerifiedBlocks[l1Height] = VerifiedBlock(l1Hash, l1SignalRoot);

        emit XchainSynced(l1Height, l1Hash, l1SignalRoot);

        // We emit this event so circuits can grab its data to verify block variables.
        // If plonk lookup table already has all these data, we can still use this
        // event for debugging purpose.
        emit BlockVars({
            number: block.number,
            parentHash: parentHash,
            timestamp: block.timestamp,
            basefee: block.basefee,
            prevrandao: block.prevrandao,
            coinbase: block.coinbase,
            gaslimit: block.gaslimit,
            chainid: block.chainid
        });
    }

    /**********************
     * Public Functions   *
     **********************/

    function getXchainBlockHash(
        uint256 number
    ) public view override returns (bytes32) {
        uint256 _number = number == 0 ? latestSyncedL1Height : number;
        return _l1VerifiedBlocks[_number].blockHash;
    }

    function getXchainSignalRoot(
        uint256 number
    ) public view override returns (bytes32) {
        uint256 _number = number == 0 ? latestSyncedL1Height : number;
        return _l1VerifiedBlocks[_number].signalRoot;
    }

    function getBlockHash(uint256 number) public view returns (bytes32) {
        if (number >= block.number) {
            return 0;
        } else if (number < block.number && number >= block.number - 256) {
            return blockhash(number);
        } else {
            return _l2Hashes[number];
        }
    }

    /**********************
     * Private Functions  *
     **********************/

    function _calcPublicInputHash(
        uint256 blockNumber
    ) private view returns (bytes32 prevPIH, bytes32 currPIH) {
        bytes32[256] memory inputs;
        unchecked {
            // put the previous 255 blockhashes (excluding the parent's) into a
            // ring buffer.
            for (uint256 i; i < 255 && blockNumber >= i + 1; ++i) {
                uint256 j = blockNumber - i - 1;
                inputs[j % 255] = blockhash(j);
            }
        }

        inputs[255] = bytes32(block.chainid);

        assembly {
            prevPIH := keccak256(inputs, mul(256, 32))
        }

        inputs[blockNumber % 255] = blockhash(blockNumber);
        assembly {
            currPIH := keccak256(inputs, mul(256, 32))
        }
    }
}
