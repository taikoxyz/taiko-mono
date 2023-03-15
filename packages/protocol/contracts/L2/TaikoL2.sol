// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import {ChainData, IXchainSync} from "../common/IXchainSync.sol";
import {EssentialContract} from "../common/EssentialContract.sol";

contract TaikoL2 is EssentialContract, IXchainSync {
    /**********************
     * State Variables    *
     **********************/

    // Mapping from L2 block numbers to their block hashes.
    // All L2 block hashes will be saved in this mapping.
    mapping(uint256 blockNumber => bytes32 blockHash) private _l2Hashes;

    mapping(uint256 blockNumber => ChainData) private _l1ChainData;

    uint256 public l1ChainId;
    // A hash to check te integrity of public inputs.
    bytes32 private publicInputHash;

    // The latest L1 block where a L2 block has been proposed.
    uint256 public latestSyncedL1Height;

    uint256[45] private __gap;

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

    function init(
        address _addressManager,
        uint256 _l1ChainId
    ) external initializer {
        if (block.number > 1) revert L2_TOO_LATE();

        EssentialContract._init(_addressManager);
        l1ChainId = _l1ChainId;

        if (block.chainid == 0 || block.chainid == _l1ChainId) {
            revert L2_INVALID_CHAIN_ID();
        }

        bytes32[255] memory ancestors;
        uint256 number = block.number;
        for (uint256 i; i < 255 && number >= i + 2; ) {
            ancestors[i] = blockhash(number - i - 2);
            unchecked {
                ++i;
            }
        }

        uint baseFee = 0;

        bytes32[258] memory inputs;
        if (block.number == 1) {
            inputs[0] = blockhash(0);
        }
        inputs[255] = bytes32(block.chainid);
        inputs[256] = bytes32(baseFee);
        inputs[257] = bytes32(block.number);
        publicInputHash = keccak256(abi.encodePacked(inputs));
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
        bytes32[255] calldata /*publicInput*/,
        uint256 l1Height,
        bytes32 l1Hash,
        bytes32 l1SignalRoot
    ) external {
        // Check public inputs
        uint n = block.number;
        bytes32 parentHash = blockhash(block.number - 1);
        uint baseFee = 0;
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
                // loc = (n + 255 - i - 2) % 255
                let loc := mod(sub(sub(add(n, 255), i), 2), 255)
                calldatacopy(
                    add(ptr, mul(loc, 32)), // location
                    add(4, mul(i, 32)), // index on calldata
                    32
                )
            }

            mstore(add(ptr, mul(255, 32)), chainid())
            mstore(add(ptr, mul(256, 32)), baseFee)
            mstore(add(ptr, mul(257, 32)), sub(n, 1))

            prevPublicInputHash := keccak256(ptr, mul(32, 258))

            let loc := mod(sub(n, 1), 255)
            mstore(add(ptr, mul(loc, 32)), parentHash)
            mstore(add(ptr, mul(256, 32)), n)
            currPublicInputHash := keccak256(ptr, mul(32, 258))
        }

        if (publicInputHash != 0 && prevPublicInputHash != publicInputHash) {
            revert L2_PUBLIC_INPUT_HASH_MISMATCH();
        }
        publicInputHash = currPublicInputHash;

        latestSyncedL1Height = l1Height;
        ChainData memory chainData = ChainData(l1Hash, l1SignalRoot);
        _l1ChainData[l1Height] = chainData;
        _l2Hashes[n - 1] = parentHash;

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
