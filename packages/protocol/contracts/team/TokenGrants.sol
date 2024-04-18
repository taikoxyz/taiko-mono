// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./TokenGrant.sol";

/// @title TokenGrant3m4y4y1c
/// @notice For cofounders and employees
/// @custom:security-contact security@taiko.xyz
contract TokenGrant3m4y4y1c is TokenGrant {
    function config() public pure override returns (Config memory c) {
        // 3 months
        c.vestCliff = 90 days;
        // 4 years
        c.vestDuration = 4 * 365 days;
        // 4 years
        c.unlockDuration = 4 * 365 days;
        // 1 cent, assuming the stable coin used has 6 decimals.
        c.costPerTko = 10_000;
    }
}

/// @title TokenGrant3m4y4y1c
/// @notice For investors.
/// @custom:security-contact security@taiko.xyz
contract TokenGrant0m0y4y0c is TokenGrant {
    function config() public pure override returns (Config memory c) {
        // 4 years
        c.unlockDuration = 4 * 365 days;
    }
}
