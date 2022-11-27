// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "../common/AddressResolver.sol";
import "../common/IHeaderSync.sol";
import "../libs/LibInvalidTxList.sol";
import "../libs/LibConstants.sol";
import "../libs/LibTxDecoder.sol";

/// @author dantaik <dan@taiko.xyz>
contract V1TaikoL2 is AddressResolver, ReentrancyGuard, IHeaderSync {
    using LibTxDecoder for bytes;

    /**********************
     * State Variables    *
     **********************/

    mapping(uint256 => bytes32) private l2Hashes;
    mapping(uint256 => bytes32) private l1Hashes;
    bytes32 public publicInputHash;
    bytes32 public latestSyncedHeader;

    uint256[46] private __gap;

    /**********************
     * Events             *
     **********************/

    event BlockInvalidated(bytes32 indexed txListHash);

    /**********************
     * Constructor         *
     **********************/

    constructor(address _addressManager) {
        require(block.chainid != 0, "L2:chainId");
        AddressResolver._init(_addressManager);

        bytes32[255] memory ancestors;
        uint256 number = block.number;
        for (uint256 i = 0; i < 255 && number >= i + 2; i++) {
            ancestors[i] = blockhash(number - i - 2);
        }

        publicInputHash = _hashPublicInputs({
            chainId: block.chainid,
            number: number,
            feeBase: 0,
            ancestors: ancestors
        });
    }

    /**********************
     * External Functions *
     **********************/

    /** Persist the latest L1 block height and hash to L2 for cross-layer
     *        bridging. This function will also check certain block-level global
     *        variables because they are not part of the Trie structure.
     *
     *        Note that this transaction shall be the first transaction in every
     *        L2 block.
     *
     * @param l1Height The latest L1 block height when this block was proposed.
     * @param l1Hash The latest L1 block hash when this block was proposed.
     */
    function anchor(uint256 l1Height, bytes32 l1Hash) external {
        _checkPublicInputs();

        l1Hashes[l1Height] = l1Hash;
        latestSyncedHeader = l1Hash;
        emit HeaderSynced(block.number, l1Height, l1Hash);
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
        LibInvalidTxList.Reason hint,
        uint256 txIdx
    ) external {
        LibInvalidTxList.Reason reason = LibInvalidTxList.isTxListInvalid({
            encoded: txList,
            hint: hint,
            txIdx: txIdx
        });
        require(reason != LibInvalidTxList.Reason.OK, "L2:reason");

        _checkPublicInputs();

        emit BlockInvalidated(txList.hashTxList());
    }

    /**********************
     * Public Functions   *
     **********************/

    function getSyncedHeader(
        uint256 number
    ) public view override returns (bytes32) {
        return l1Hashes[number];
    }

    function getLatestSyncedHeader() public view override returns (bytes32) {
        return latestSyncedHeader;
    }

    function getBlockHash(uint256 number) public view returns (bytes32) {
        if (number >= block.number) {
            return 0;
        } else if (number < block.number && number >= block.number - 256) {
            return blockhash(number);
        } else {
            return l2Hashes[number];
        }
    }

    /**********************
     * Private Functions  *
     **********************/

    // NOTE: If the order of the return values of this function changes, then
    // some test cases that using this function in generate_genesis.test.ts
    // may also needs to be modified accordingly.
    function getConstants()
        public
        pure
        returns (
            uint256, // K_ZKPROOFS_PER_BLOCK
            uint256, // K_CHAIN_ID
            uint256, // K_MAX_NUM_BLOCKS
            uint256, // K_MAX_VERIFICATIONS_PER_TX
            uint256, // K_COMMIT_DELAY_CONFIRMS
            uint256, // K_MAX_PROOFS_PER_FORK_CHOICE
            uint256, // K_BLOCK_MAX_GAS_LIMIT
            uint256, // K_BLOCK_MAX_TXS
            uint256, // K_TXLIST_MAX_BYTES
            uint256, // K_TX_MIN_GAS_LIMIT
            uint256 // K_ANCHOR_TX_GAS_LIMIT
        )
    {
        return (
            LibConstants.K_ZKPROOFS_PER_BLOCK,
            LibConstants.K_CHAIN_ID,
            LibConstants.K_MAX_NUM_BLOCKS,
            LibConstants.K_MAX_VERIFICATIONS_PER_TX,
            LibConstants.K_COMMIT_DELAY_CONFIRMS,
            LibConstants.K_MAX_PROOFS_PER_FORK_CHOICE,
            LibConstants.K_BLOCK_MAX_GAS_LIMIT,
            LibConstants.K_BLOCK_MAX_TXS,
            LibConstants.K_TXLIST_MAX_BYTES,
            LibConstants.K_TX_MIN_GAS_LIMIT,
            LibConstants.K_ANCHOR_TX_GAS_LIMIT
        );
    }

    function _checkPublicInputs() private {
        // Check the latest 256 block hashes (excluding the parent hash).
        bytes32[255] memory ancestors;
        uint256 number = block.number;
        uint256 chainId = block.chainid;

        for (uint256 i = 2; i <= 256 && number >= i; i++) {
            ancestors[(number - i) % 255] = blockhash(number - i);
        }

        uint256 parentHeight = number - 1;
        bytes32 parentHash = blockhash(parentHeight);

        require(
            publicInputHash ==
                _hashPublicInputs({
                    chainId: chainId,
                    number: parentHeight,
                    feeBase: 0,
                    ancestors: ancestors
                }),
            "L2:publicInputHash"
        );

        ancestors[parentHeight % 255] = parentHash;
        publicInputHash = _hashPublicInputs({
            chainId: chainId,
            number: number,
            feeBase: 0,
            ancestors: ancestors
        });

        l2Hashes[parentHeight] = parentHash;
    }

    function _hashPublicInputs(
        uint256 chainId,
        uint256 number,
        uint256 feeBase,
        bytes32[255] memory ancestors
    ) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(chainId, number, feeBase, ancestors));
    }
}
