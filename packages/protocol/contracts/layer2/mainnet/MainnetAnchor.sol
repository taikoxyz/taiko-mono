// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../based/TaikoAnchor.sol";

/// @title MainnetAnchor
/// @custom:security-contact security@taiko.xyz
contract MainnetAnchor is TaikoAnchor {
    function pacayaForkHeight() public pure override returns (uint64) {
        return 538_304 * 2; // TODO
    }
}
