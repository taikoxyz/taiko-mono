// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import {ChainData, IXchainSync} from "../common/IXchainSync.sol";
import {
    OwnableUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import {console2} from "forge-std/console2.sol";

contract TaikoL2 is OwnableUpgradeable, IXchainSync {
    /**********************
     * State Variables    *
     **********************/

    // Mapping from L2 block numbers to their block hashes.
    // All L2 block hashes will be saved in this mapping.
    mapping(uint256 blockNumber => bytes32 blockHash) private _l2Hashes;

    mapping(uint256 blockNumber => ChainData) private _l1ChainData;

    // A hash to check te integrity of public inputs.
    bytes32 public publicInputHash;

    // The latest L1 block where a L2 block has been proposed.
    uint256 public latestSyncedL1Height;

    uint256[46] private __gap;

    /**********************
     * Events and Errors  *
     **********************/

    event BlockInvalidated(bytes32 indexed txListHash);

    error L2_PUBLIC_INPUT_HASH_MISMATCH(bytes32 current, bytes32 expected);

    /**********************
     * Constructor         *
     **********************/

    function init() external initializer {
        (publicInputHash, ) = hashPublicInputs(0);
        console2.log("genesis:", uint(publicInputHash));
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
     * Note: This transaction shall be the first transaction in every L2 block.
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
        uint256 parentHeight = block.number - 1;
        bytes32 parentHash = blockhash(parentHeight);

        (bytes32 expected, bytes32 next) = hashPublicInputs(parentHash);

        if (publicInputHash != expected)
            revert L2_PUBLIC_INPUT_HASH_MISMATCH(publicInputHash, expected);

        publicInputHash = next;
        _l2Hashes[parentHeight] = parentHash;

        latestSyncedL1Height = l1Height;

        ChainData memory chainData = ChainData(l1Hash, l1SignalRoot);
        _l1ChainData[l1Height] = chainData;

        // A circuit will verify the integratity among:
        // l1Hash, l1SignalRoot, and l1SignalServiceAddress
        // (l1Hash and l1SignalServiceAddress) are both hased into of the ZKP's
        // instance.

        emit XchainSynced(l1Height, chainData);
    }

    /**********************
     * Public Functions   *
     **********************/

    function getXchainBlockHash(
        uint256 number
    ) public view override returns (bytes32) {
        uint256 _number = number == 0 ? latestSyncedL1Height : number;
        return _l1ChainData[_number].blockHash;
    }

    function getXchainSignalRoot(
        uint256 number
    ) public view override returns (bytes32) {
        uint256 _number = number == 0 ? latestSyncedL1Height : number;
        return _l1ChainData[_number].signalRoot;
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

    // TODO: optimize this function to remove the ancestors ringbuffer and
    // avoid abi.encodePacked by using assembly
    function hashPublicInputs(
        bytes32 parentHash
    ) public view returns (bytes32 expected, bytes32 next) {
        bytes32[255] memory ancestors;
        uint256 number = block.number;

        // put the previous 255 blockhashes (excluding the parent's) into a
        // ring buffer.
        for (uint256 i = 2; i <= 256 && number >= i; ) {
            unchecked {
                uint j = number - i;

                ancestors[j % 255] = blockhash(j);
                ++i;
            }
        }

        bytes memory extra = bytes.concat(
            bytes32(block.chainid),
            bytes32(number),
            bytes32(0) //placeholder for EIP-1559 baseFee
        );

        expected = keccak256(abi.encodePacked(extra, ancestors));
        // replace the oldest block hash with the parent's blockhash

        ancestors[(number - 1) % 255] = parentHash;
        next = keccak256(abi.encodePacked(extra, ancestors));
    }
}
