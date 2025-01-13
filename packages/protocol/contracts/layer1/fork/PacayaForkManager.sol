// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./ForkManager.sol";

/// @title OntakeSelectors
/// @custom:security-contact security@taiko.xyz
/// @notice This interface is used to route specific transactions to the v2 version of the contract.
/// @dev Function selectors are calculated independently of the return type. Therefore,
/// we have omitted the `returns` statements from all functions to avoid maintaining
/// the return struct definitions.
interface OntakeSelectors {
    function proposeBlocksV2(bytes[] calldata, bytes[] calldata) external;
    function proveBlocks(uint64[] calldata, bytes[] calldata, bytes calldata) external;
    function getBlockV2(uint64) external;
    function getTransition(uint64, uint32) external;
    function getConfig() external;
}

/// @title PacayaForkManager (Ontake -> Pacaya)
/// @custom:security-contact security@taiko.xyz
contract PacayaForkManager is ForkManager {
    constructor(address _ontakeFork, address _pacayaFork) ForkManager(_ontakeFork, _pacayaFork) { }

    function shouldRouteToOldFork(bytes4 _selector) internal pure override returns (bool) {
        return _selector == OntakeSelectors.proposeBlocksV2.selector
            || _selector == OntakeSelectors.proveBlocks.selector
            || _selector == OntakeSelectors.getBlockV2.selector
            || _selector == OntakeSelectors.getTransition.selector
            || _selector == OntakeSelectors.getConfig.selector;
    }
}
