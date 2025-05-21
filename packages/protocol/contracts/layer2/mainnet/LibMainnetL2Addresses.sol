// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title LibMainnetL2Addresses
/// @custom:security-contact security@taiko.xyz
library LibMainnetL2Addresses {
    address public constant DELEGATE_CONTROLLER = address(0); // TODO
    address public constant TAIKO_TOKEN = 0xA9d23408b9bA935c230493c40C73824Df71A0975;
    address public constant PERMISSIONLESS_EXECUTOR = 0x4EBeC8a624ac6f01Bb6C7F13947E6Af3727319CA;
    address public constant BRIDGE = 0x1670000000000000000000000000000000000001;

    // Third party contracts
    address public constant MULTICALL3 = 0xcA11bde05977b3631167028862bE2a173976CA11;
}
