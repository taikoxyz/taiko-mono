// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import {EssentialContract} from "../common/EssentialContract.sol";
import {IHeaderSync} from "../common/IHeaderSync.sol";

contract TaikoL2 is EssentialContract, IHeaderSync {
    /**********************
     * State Variables    *
     **********************/

    // Mapping from L2 block numbers to their block hashes.
    // All L2 block hashes will be saved in this mapping.
    mapping(uint256 blockNumber => bytes32 blockHash) private _l2Hashes;

    // Mapping from L1 block numbers to their block hashes.
    // Note that only hashes of L1 blocks where at least one L2
    // block has been proposed will be saved in this mapping.
    mapping(uint256 blockNumber => bytes32 blockHash) private _l1Hashes;

    // Known L1 SignalService storage roots.
    mapping(uint256 blockNumber => bytes32 storageRoot) private _l1Sssrs;

    uint256 public l1ChainId;
    // A hash to check te integrity of public inputs.
    bytes32 private _publicInputHash;

    // The latest L1 block where a L2 block has been proposed.
    uint256 public latestSyncedL1Height;

    uint256[44] private __gap;

    /**********************
     * Events and Errors  *
     **********************/

    event BlockInvalidated(bytes32 indexed txListHash);

    error L2_INVALID_CHAIN_ID();
    error L2_PUBLIC_INPUT_HASH_MISMATCH();

    /**********************
     * Constructor         *
     **********************/

    function init(
        address _addressManager,
        uint256 _l1ChainId
    ) external initializer {
        EssentialContract._init(_addressManager);
        l1ChainId = _l1ChainId;

        if (block.chainid == 0 && block.chainid == _l1ChainId) {
            revert L2_INVALID_CHAIN_ID();
        }

        bytes32[255] memory ancestors;
        uint256 number = block.number;
        for (uint256 i; i < 255 && number >= i + 2; ++i) {
            ancestors[i] = blockhash(number - i - 2);
        }

        _publicInputHash = _hashPublicInputs({
            chainId: block.chainid,
            number: number,
            baseFee: 0,
            ancestors: ancestors
        });
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
     * @param l1Sssr The latest value of the L1 "signal service storage root".
     * @param l1SssrProof Merkel proof for l1Sssr.
     */
    function anchor(
        uint256 l1Height,
        bytes32 l1Hash,
        bytes32 l1Sssr,
        bytes calldata l1SssrProof
    ) external {
        _checkPublicInputs();

        latestSyncedL1Height = l1Height;
        _l1Hashes[l1Height] = l1Hash;

        address l1SignalService = resolve(l1ChainId, "signal_service", false);
        // TODO(daniel): perform merkle verification to check the consistency among:
        // l1Hash, l1SignalService, and l1Sssr using
        // l1SssrProof
        _l1Sssrs[l1Height] = l1Sssr;

        emit HeaderSynced(l1Height, l1Hash);
    }

    /**********************
     * Public Functions   *
     **********************/

    function getSyncedHeader(
        uint256 number
    ) public view override returns (bytes32) {
        return _l1Hashes[number];
    }

    function getLatestSyncedHeader() public view override returns (bytes32) {
        return _l1Hashes[latestSyncedL1Height];
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

    function _checkPublicInputs() private {
        // Check the latest 256 block hashes (excluding the parent hash).
        bytes32[255] memory ancestors;
        uint256 number = block.number;
        uint256 chainId = block.chainid;

        // put the previous 255 blockhashes (excluding the parent's) into a
        // ring buffer.
        for (uint256 i = 2; i <= 256 && number >= i; ++i) {
            ancestors[(number - i) % 255] = blockhash(number - i);
        }

        uint256 parentHeight = number - 1;
        bytes32 parentHash = blockhash(parentHeight);

        if (
            _publicInputHash !=
            _hashPublicInputs({
                chainId: chainId,
                number: parentHeight,
                baseFee: 0,
                ancestors: ancestors
            })
        ) {
            revert L2_PUBLIC_INPUT_HASH_MISMATCH();
        }

        // replace the oldest block hash with the parent's blockhash
        ancestors[parentHeight % 255] = parentHash;
        _publicInputHash = _hashPublicInputs({
            chainId: chainId,
            number: number,
            baseFee: 0,
            ancestors: ancestors
        });

        _l2Hashes[parentHeight] = parentHash;
    }

    function _hashPublicInputs(
        uint256 chainId,
        uint256 number,
        uint256 baseFee,
        bytes32[255] memory ancestors
    ) private pure returns (bytes32) {
        bytes memory extra = bytes.concat(
            bytes32(chainId),
            bytes32(number),
            bytes32(baseFee)
        );
        return keccak256(abi.encodePacked(extra, ancestors));
    }
}
