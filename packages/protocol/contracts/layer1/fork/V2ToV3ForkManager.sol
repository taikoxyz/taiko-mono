// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./ForkManager.sol";

/// @title TaikoV2Selectors (Ontake)
/// @custom:security-contact security@taiko.xyz
/// @notice This interface is used to route specific transactions to the v2 version of the contract.
/// @dev Function selectors are calculated independently of the return type. Therefore,
/// we have omitted the `returns` statements from all functions to avoid maintaining
/// the return struct definitions.
interface TaikoV2Selectors {
    function proposeBlocksV2(bytes[] calldata, bytes[] calldata) external;
    function proveBlocks(uint64[] calldata, bytes[] calldata, bytes calldata) external;
    function getBlockV2(uint64) external;
    function getTransition(uint64, uint32) external;
    function getConfig() external;
}

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
        return _selector == TaikoV2Selectors.proposeBlocksV2.selector
            || _selector == TaikoV2Selectors.proveBlocks.selector
            || _selector == TaikoV2Selectors.getBlockV2.selector
            || _selector == TaikoV2Selectors.getTransition.selector
            || _selector == TaikoV2Selectors.getConfig.selector;
    }
}
