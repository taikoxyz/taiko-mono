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

        bytes32 parentHash =  n == 1? blockhash(n - 1): bytes32(0);

        bytes32 ptr;
        assembly {
            // Load the free memory pointer and allocate memory for the concatenated arguments
            ptr := mload(64)
        }

            for (uint256 i = 0; i < 255; ++i) {
                if (n >= i + 2) {
                    assembly {
                        let m := sub(sub(n, i), 2)
                        let offset := mul(mod(m, 255), 32)
                        mstore(add(ptr, offset), blockhash(m))
                    }
                } else {
                    assembly {
                        let m := sub(sub(add(n, 255), i), 2)
                        let offset := mul(mod(m, 255), 32)
                        mstore(add(ptr, offset), 0)
                    }
                }
                unchecked {
                    ++i;
                }
            }

        assembly {
            mstore(add(ptr, mul(255, 32)), chainid()) // chain id
            mstore(add(ptr, mul(256, 32)), 0) // fee base

            let offset := mul(mod(sub(add(n, 255), 1), 255), 32)
            mstore(add(ptr, offset), parentHash) // parentHash
            mstore(add(ptr, mul(257, 32)), n) // current block height
            sstore(publicInputHash.slot, keccak256(ptr, mul(32, 258)))
        }

        console2.log("----------");
        console2.log("number:", block.number);
        console2.log("now  :", uint(publicInputHash));
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
        uint256 n = block.number;
        bytes32 parentHash = blockhash(n - 1);
        bytes32 prevPublicInputHash;
        bytes32 currPublicInputHash;

        bytes32 ptr;
        assembly {
            // Load the free memory pointer and allocate memory for the concatenated arguments
            ptr := mload(64)
        }

            for (uint256 i = 0; i < 255; ++i) {
                if (n >= i + 2) {
                    assembly {
                        let m := sub(sub(n, i), 2)
                        let offset := mul(mod(m, 255), 32)
                        mstore(add(ptr, offset), blockhash(m))
                    }
                } else {
                    assembly {
                        let m := sub(sub(add(n, 255), i), 2)
                        let offset := mul(mod(m, 255), 32)
                        mstore(add(ptr, offset), 0)
                    }
                }
                unchecked {
                    ++i;
                }
            }

        assembly {
            mstore(add(ptr, mul(255, 32)), chainid()) // chain id
            mstore(add(ptr, mul(256, 32)), 0) // fee base

            mstore(add(ptr, mul(257, 32)), sub(n, 1)) // parent block height
            prevPublicInputHash := keccak256(ptr, mul(32, 258))

            let offset := mul(mod(sub(add(n, 255), 1), 255), 32)
            mstore(add(ptr, offset), parentHash) // parentHash
            mstore(add(ptr, mul(257, 32)), n) // current block height
            currPublicInputHash := keccak256(ptr, mul(32, 258))
        }
        console2.log("----------");
        console2.log("number:", block.number);
        console2.log("now  :", uint(publicInputHash));
        console2.log("pre  :", uint(prevPublicInputHash));
        console2.log("curr :", uint(currPublicInputHash));
        // if (prevPublicInputHash != publicInputHash) {
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
