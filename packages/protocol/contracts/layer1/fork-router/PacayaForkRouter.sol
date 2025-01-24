// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./ForkRouter.sol";

/// @title ITaikoL1
/// @dev https://github.com/taikoxyz/taiko-mono/releases/tag/protocol-v1.11.0
interface ITaikoL1 {
    function proposeBlockV2(bytes calldata, bytes calldata) external;
    function proposeBlocksV2(bytes[] calldata, bytes[] calldata) external;
    function proveBlock(uint64, bytes calldata) external;
    function proveBlocks(uint64[] calldata, bytes[] calldata, bytes calldata) external;
    function verifyBlocks(uint64) external;
    function getVerifiedBlockProver(uint64) external view;
    function getBlockV2(uint64) external view;
    function getTransition(uint64, uint32) external view;
    function getTransition(uint64, bytes32) external;
    function getTransitions(uint64[] calldata, bytes32[] calldata) external;
    function lastProposedIn() external view;
    function getConfig() external pure;
}

/// @title PacayaForkRouter
/// @custom:security-contact security@taiko.xyz
/// @notice This contract routes calls to the current fork.
contract PacayaForkRouter is ForkRouter {
    constructor(address _oldFork, address _newFork) ForkRouter(_oldFork, _newFork) { }

    function shouldRouteToOldFork(bytes4 _selector) public pure override returns (bool) {
        if (
            _selector == ITaikoL1.proposeBlockV2.selector
                || _selector == ITaikoL1.proposeBlocksV2.selector
                || _selector == ITaikoL1.proveBlock.selector
                || _selector == ITaikoL1.proveBlocks.selector
                || _selector == ITaikoL1.verifyBlocks.selector
                || _selector == ITaikoL1.getVerifiedBlockProver.selector
                || _selector == ITaikoL1.getBlockV2.selector
                || _selector == bytes4(keccak256("getTransition(uint64,uint32)"))
                || _selector == bytes4(keccak256("getTransition(uint64,bytes32)"))
                || _selector == ITaikoL1.getTransitions.selector
                || _selector == ITaikoL1.lastProposedIn.selector
                || _selector == ITaikoL1.getConfig.selector
        ) return true;

        return false;
    }
}
