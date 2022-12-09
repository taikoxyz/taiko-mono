// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

/// @author dantaik <dan@taiko.xyz>
library LibConstants {
    // https://github.com/ethereum-lists/chains/pull/1611
    uint256 public constant K_CHAIN_ID = 167;
    // up to 2048 pending blocks
    uint256 public constant K_MAX_NUM_BLOCKS = 2049;
    // This number is calculated from K_MAX_NUM_BLOCKS to make
    // the 'the maximum value of the multiplier' close to 20.0
    uint256 public constant K_ZKPROOFS_PER_BLOCK = 1;
    uint256 public constant K_MAX_VERIFICATIONS_PER_TX = 20;
    uint256 public constant K_COMMIT_DELAY_CONFIRMS = 0;
    uint256 public constant K_MAX_PROOFS_PER_FORK_CHOICE = 5;
    uint256 public constant K_BLOCK_MAX_GAS_LIMIT = 5000000; // TODO
    uint256 public constant K_BLOCK_MAX_TXS = 20; // TODO
    uint256 public constant K_TXLIST_MAX_BYTES = 10240; // TODO
    uint256 public constant K_TX_MIN_GAS_LIMIT = 21000; // TODO
    uint256 public constant K_ANCHOR_TX_GAS_LIMIT = 250000;

    uint256 public constant K_BLOCK_TIME_MAF = 1024;
    uint256 public constant K_PROOF_TIME_MAF = 1024;

    uint64 public constant K_INITIAL_UNCLE_DELAY = 60 minutes;

    bytes4 public constant K_ANCHOR_TX_SELECTOR =
        bytes4(keccak256("anchor(uint256,bytes32)"));

    bytes32 public constant K_BLOCK_DEADEND_HASH = bytes32(uint256(1));
    bytes32 public constant K_INVALIDATE_BLOCK_LOG_TOPIC =
        keccak256("BlockInvalidated(bytes32)");
}
