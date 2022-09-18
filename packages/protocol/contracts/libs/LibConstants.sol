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
    uint256 public constant TAIKO_CHAIN_ID = 1337; // TODO
    uint256 public constant TAIKO_MAX_PENDING_BLOCKS = 2048;
    uint256 public constant TAIKO_MAX_FINALIZATIONS_PER_TX = 20;
    uint256 public constant TAIKO_COMMIT_DELAY_CONFIRMATIONS = 4;
    uint256 public constant TAIKO_MAX_PROOFS_PER_FORK_CHOICE = 5;
    uint256 public constant TAIKO_BLOCK_MAX_GAS_LIMIT = 5000000; // TODO
    uint256 public constant TAIKO_BLOCK_MAX_TXS = 20; // TODO
    bytes32 public constant TAIKO_BLOCK_DEADEND_HASH = bytes32(uint256(1));

    uint256 public constant TAIKO_TXLIST_MAX_BYTES = 10240; // TODO
    uint256 public constant TAIKO_TX_MIN_GAS_LIMIT = 21000; // TODO

    // Taiko L2 releated constants
    uint256 public constant V1_ANCHOR_TX_GAS_LIMIT = 1000000; // TODO

    bytes4 public constant V1_ANCHOR_TX_SELECTOR =
        bytes4(keccak256("anchor(uint256,bytes32)"));

    bytes32 public constant V1_INVALIDATE_BLOCK_LOG_TOPIC =
        keccak256("BlockInvalidated(bytes32)");
}
