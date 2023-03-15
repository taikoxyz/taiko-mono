// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import {ChainData, IXchainSync} from "../common/IXchainSync.sol";
import {EssentialContract} from "../common/EssentialContract.sol";
import "forge-std/console2.sol";

contract TaikoL2 is EssentialContract, IXchainSync {
    /**********************
     * State Variables    *
     **********************/

    // Mapping from L2 block numbers to their block hashes.
    // All L2 block hashes will be saved in this mapping.
    mapping(uint256 blockNumber => bytes32 blockHash) private _l2Hashes;

    mapping(uint256 blockNumber => ChainData) private _l1ChainData;

    bytes32 public publicInputHash;
    uint256 public latestSyncedL1Height;

    uint256[46] private __gap;

    /**********************
     * Events and Errors  *
     **********************/

    event BlockInvalidated(bytes32 indexed txListHash);

    error L2_INVALID_CHAIN_ID();
    error L2_PUBLIC_INPUT_HASH_MISMATCH();
    error L2_TOO_LATE();

    /**********************
     * Constructor         *
     **********************/

    function init(address _addressManager) external initializer {
        uint256 n = block.number;

        // This contract must be initialized in genesis
        if (n > 1) revert L2_TOO_LATE();
        if (block.chainid <= 1) revert L2_INVALID_CHAIN_ID();

        // _addressManager is current not used but is kept for future
        // usage.
        EssentialContract._init(_addressManager);

        bytes32 parentHash;

        if (n == 1) {
            parentHash = blockhash(0);
        }

        bytes32 hash;
       assembly {
            // Load the free memory pointer and allocate memory for the concatenated arguments
            let ptr := mload(64)
            for {
                let i := 0
            } lt(i, 255) {
                i := add(i, 1)
            } {
                mstore(add(ptr, mul(i, 32)), 0 )
            }

            mstore(ptr, parentHash)
            mstore(add(ptr, mul(255, 32)), chainid()) // chain id
            mstore(add(ptr, mul(256, 32)), 0) // fee base
            mstore(add(ptr, mul(257, 32)), n) // current block height

            hash := keccak256(ptr, mul(32, 258))
        }
        console2.log("init:",uint(hash));
        publicInputHash = hash;

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
     * @param ancestors The 255 ancestor hashes excluding the parent.
     * @param l1Height The latest L1 block height when this block was proposed.
     * @param l1Hash The latest L1 block hash when this block was proposed.
     * @param l1SignalRoot The latest value of the L1 "signal service storage root".
     */
    function anchor(
        bytes32[255] calldata ancestors,
        uint256 l1Height,
        bytes32 l1Hash,
        bytes32 l1SignalRoot
    ) external {
        // Check public inputs
        uint256 n = block.number;
        bytes32 parentHash = blockhash(n-1);
        uint256 baseFee = 0;
        bytes32 prevPublicInputHash;
        bytes32 currPublicInputHash;

        assembly {
            // Load the free memory pointer and allocate memory for the concatenated arguments
            let ptr := mload(64)
            for {
                let i := 0
            } lt(i, 255) {
                i := add(i, 1)
            } {
                // loc = (n + 510 - i - 2) % 255
                let loc := mod(sub(sub(add(n, 510), i), 2), 255)
                calldatacopy(
                    add(ptr, mul(loc, 32)), // location
                    add(4, mul(i, 32)), // index on calldata
                    32
                )
            }

            mstore(add(ptr, mul(255, 32)), chainid()) // chain id
            mstore(add(ptr, mul(256, 32)), baseFee) // fee base

            mstore(add(ptr, mul(257, 32)), sub(n, 1)) // parent block height
            prevPublicInputHash := keccak256(ptr, mul(32, 258))

            let loc := mod(sub(n, 1), 255)
            mstore(add(ptr, mul(loc, 32)), parentHash)
            mstore(add(ptr, mul(257, 32)), n) // current block height
            currPublicInputHash := keccak256(ptr, mul(32, 258))
        }

        console2.log("now:",uint(publicInputHash));
        console2.log("pre : ", uint(prevPublicInputHash));
        console2.log("curr: ", uint(currPublicInputHash));
        // if (publicInputHash != 0 && prevPublicInputHash != publicInputHash) {
        //     revert L2_PUBLIC_INPUT_HASH_MISMATCH();
        // }
        publicInputHash = currPublicInputHash;


        latestSyncedL1Height = l1Height;
        _l2Hashes[n-1] = parentHash;

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
}
