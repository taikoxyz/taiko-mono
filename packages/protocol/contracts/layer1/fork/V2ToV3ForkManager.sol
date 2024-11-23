// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../based/ITaikoL1v2.sol";
import "./ForkManager.sol";

/// @title V2ToV3ForkManager (Ontake -> Pacaya)
/// @custom:security-contact security@taiko.xyz
contract V2ToV3ForkManager is ForkManager {
    constructor(
        address _v2OntakeFork,
        address _v3PacayaFork
    )
        ForkManager(_v2OntakeFork, _v3PacayaFork)
    { }

    function shouldRouteToOldFork(bytes4 _selector) internal pure override returns (bool) {
        return _selector == ITaikoL1v2.proposeBlocksV2.selector
            || _selector == ITaikoL1v2.proveBlocks.selector
            || _selector == ITaikoL1v2.getBlockV2.selector
            || _selector == ITaikoL1v2.getTransition.selector
            || _selector == ITaikoL1v2.getConfig.selector;
    }
}
