// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../based/TaikoAnchor.sol";

/// @title HeklaAnchor
/// @custom:security-contact security@taiko.xyz
contract HeklaAnchor is TaikoAnchor {
    function pacayaForkHeight() public pure override returns (uint64) {
        return 840_512 * 2; // TODO
    }
}
