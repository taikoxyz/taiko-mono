// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

library LibTaikoConstants {
    uint256 public constant TAIKO_BLOCK_MAX_GAS_LIMIT = 5000000; // TODO
    uint256 public constant TAIKO_BLOCK_MAX_TXS = 20; // TODO
    uint256 public constant TAIKO_BLOCK_MAX_TXLIST_BYTES = 1000000; // TODO
    uint256 public constant TAIKO_TX_MIN_GAS_LIMIT = 10000; // TODO

    bytes public constant GOLD_FINGURE_PUBLIC_KEY = "";
    bytes public constant GOLD_FINGURE_PRIVATE_KEY = "";
    address public constant GOLD_FINGER_ADDRESS = address(0); // TODO
}
