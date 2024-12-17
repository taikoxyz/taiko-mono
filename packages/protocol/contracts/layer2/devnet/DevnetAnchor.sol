// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../based/TaikoAnchor.sol";

/// @title DevnetAnchor
/// @custom:security-contact security@taiko.xyz
contract DevnetAnchor is TaikoAnchor {
    function pacayaForkHeight() public pure override returns (uint64) {
        return 0;
    }
}
