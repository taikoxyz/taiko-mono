// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.18;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {
    ReentrancyGuard
} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import {AddressResolver} from "../common/AddressResolver.sol";
import {IHeaderSync} from "../common/IHeaderSync.sol";
import {LibAnchorSignature} from "../libs/LibAnchorSignature.sol";
import {LibInvalidTxList} from "../libs/LibInvalidTxList.sol";
import {LibSharedConfig} from "../libs/LibSharedConfig.sol";
import {LibTxDecoder} from "../libs/LibTxDecoder.sol";
import {TaikoData} from "../L1/TaikoData.sol";

contract TaikoL2 is AddressResolver, ReentrancyGuard, IHeaderSync {
    using LibTxDecoder for bytes;

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

    // A hash to check te integrity of public inputs.
    bytes32 private _publicInputHash;

    // The latest L1 block where a L2 block has been proposed.
    uint256 public latestSyncedL1Height;

    uint256[46] private __gap;

    /**********************
     * Events and Errors  *
     **********************/

    event BlockInvalidated(bytes32 indexed txListHash);

    error L2_INVALID_SENDER();
    error L2_INVALID_CHAIN_ID();
    error L2_INVALID_GAS_PRICE();
    error L2_PUBLIC_INPUT_HASH_MISMATCH();

    /**********************
     * Constructor         *
     **********************/

    constructor(address _addressManager) {
        if (block.chainid == 0) revert L2_INVALID_CHAIN_ID();
        AddressResolver._init(_addressManager);

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
     */
    function anchor(uint256 l1Height, bytes32 l1Hash) external {
        TaikoData.Config memory config = getConfig();
        if (config.enablePublicInputsCheck) {
            _checkPublicInputs();
        }

        latestSyncedL1Height = l1Height;
        _l1Hashes[l1Height] = l1Hash;
        emit HeaderSynced(l1Height, l1Hash);
    }

    /**
     * Invalidate a L2 block by verifying its txList is not intrinsically valid.
     *
     * @param txList The L2 block's txlist.
     * @param hint A hint for this method to invalidate the txList.
     * @param txIdx If the hint is for a specific transaction in txList,
     *        txIdx specifies which transaction to check.
     */
    function invalidateBlock(
        bytes calldata txList,
        LibInvalidTxList.Hint hint,
        uint256 txIdx
    ) external {
        if (msg.sender != LibAnchorSignature.K_GOLDEN_TOUCH_ADDRESS)
            revert L2_INVALID_SENDER();

        if (tx.gasprice != 0) revert L2_INVALID_GAS_PRICE();

        TaikoData.Config memory config = getConfig();
        LibInvalidTxList.verifyTxListInvalid({
            config: config,
            encoded: txList,
            hint: hint,
            txIdx: txIdx
        });

        if (config.enablePublicInputsCheck) {
            _checkPublicInputs();
        }

        emit BlockInvalidated(txList.hashTxList());
    }

    /**********************
     * Public Functions   *
     **********************/

    function getConfig()
        public
        view
        virtual
        returns (TaikoData.Config memory config)
    {
        config = LibSharedConfig.getConfig();
        config.chainId = block.chainid;
    }

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
