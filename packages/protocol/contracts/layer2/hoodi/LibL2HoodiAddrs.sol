// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title LibL2HoodiAddrs
/// @notice L2 contract addresses for Taiko Hoodi testnet (chain ID 167013)
/// @custom:security-contact security@taiko.xyz
library LibL2HoodiAddrs {
    address public constant HOODI_DELEGATE_CONTROLLER = 0xF7176c3aC622be8bab1B839b113230396E6877ab;
    address public constant HOODI_SIGNAL_SERVICE = 0x1670130000000000000000000000000000000005;
    address public constant HOODI_ANCHOR = 0x1670130000000000000000000000000000010001;
    address public constant HOODI_BRIDGE = 0x1670130000000000000000000000000000000001;
    address public constant HOODI_ERC20_VAULT = 0x1670130000000000000000000000000000000002;
    // This placeholder is updated once Hoodi USDC is deployed.
    address public constant HOODI_USDC_TOKEN = address(0);
}
