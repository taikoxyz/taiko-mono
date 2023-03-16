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

    // A hash to check te integrity of public inputs.
    bytes32 private _publicInputHash;

    // The latest L1 block where a L2 block has been proposed.
    uint256 public latestSyncedL1Height;

    uint256[46] private __gap;

    /**********************
     * Events and Errors  *
     **********************/

    error L2_INVALID_CHAIN_ID();
    error L2_PARENT_HASH_MISMATCH();
    error L2_PUBLIC_INPUT_HASH_MISMATCH();
    error L2_TOO_LATE();

    /**********************
     * Constructor         *
     **********************/

    function init(address _addressManager) external initializer {
        if (block.chainid <= 1) revert L2_INVALID_CHAIN_ID();
        if (block.number > 1) revert L2_TOO_LATE();
        EssentialContract._init(_addressManager);

        bytes32[257] memory inputs;
        uint256 n = block.number;

        unchecked {
            for (uint256 i; i < 255 && n >= i + 1; ++i) {
                uint j = n - i - 1;
                inputs[j % 255] = blockhash(j);
            }
        }

        inputs[255] = bytes32(block.chainid);
        // TODO(daniel): uncomment the next line when London
        // fork (including EIP-1559) is enabled on L2.
        // inputs[256] = bytes32(block.basefee);
        _publicInputHash = _hashInputs(inputs);

        _l2Hashes[n - 1] = blockhash(n - 1);
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
     * A circuit will verify the integratity among:
     * -  l1Hash, l1SignalRoot, and l1SignalServiceAddress
     * -  (l1Hash and l1SignalServiceAddress) are both hased into of the
     *    ZKP's instance.
     *
     * This transaction shall be the first transaction in every L2 block.
     *
     * @param l1Height The latest L1 block height when this block was proposed.
     * @param l1Hash The latest L1 block hash when this block was proposed.
     * @param l1SignalRoot The latest value of the L1 "signal service storage root".
     * @param l2parentHash The expected parent hash.
     */
    function anchor(
        uint256 l1Height,
        bytes32 l1Hash,
        bytes32 l1SignalRoot,
        bytes32 l2parentHash
    ) external {
        {
            uint256 n = block.number;
            uint256 m; // parent block height
            unchecked {
                m = n - 1;
            }

            if (l2parentHash != blockhash(m)) revert L2_PARENT_HASH_MISMATCH();

            // Check the latest 256 block hashes (excluding the parent hash).
            // TODO(daniel & brecht):
            //    we can move this to circuits to free L2 blockspace.
            bytes32[257] memory inputs;
            unchecked {
                // put the previous 255 blockhashes (excluding the parent's) into a
                // ring buffer.
                for (uint256 i; i < 255 && n >= i + 2; ++i) {
                    uint j = n - i - 2;
                    inputs[j % 255] = blockhash(j);
                }
            }

            // All block properties mentioned in
            // https://docs.soliditylang.org/en/v0.8.17/units-and-global-variables.html
            // but not part of a L2 block header shall be added to the list.
            inputs[255] = bytes32(block.chainid);

            // TODO(daniel): uncomment the next line when London
            // fork (including EIP-1559) is enabled on L2.
            // inputs[256] = bytes32(block.basefee);

            if (_publicInputHash != _hashInputs(inputs))
                revert L2_PUBLIC_INPUT_HASH_MISMATCH();

            // replace the oldest block hash with the parent's blockhash
            inputs[m % 255] = l2parentHash;
            _publicInputHash = _hashInputs(inputs);

            _l2Hashes[m] = l2parentHash;
        }

        latestSyncedL1Height = l1Height;
        ChainData memory chainData = ChainData(l1Hash, l1SignalRoot);
        _l1ChainData[l1Height] = chainData;

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

    /**********************
     * Private Functions  *
     **********************/

    function _hashInputs(
        bytes32[257] memory inputs
    ) private pure returns (bytes32 hash) {
        assembly {
            hash := keccak256(inputs, mul(257, 32))
        }
    }
}
