// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./ForkRouter.sol";

/// @title IOntakeFork
/// @dev Derived from TaikoL1.sol in the Taiko Ontake fork
/// https://github.com/taikoxyz/taiko-mono/releases/tag/protocol-v1.11.0
/// @custom:security-contact security@taiko.xyz
interface IOntakeFork {
    function proposeBlockV2(bytes calldata, bytes calldata) external;
    function proposeBlocksV2(bytes[] calldata, bytes[] calldata) external;
    function proveBlock(uint64, bytes calldata) external;
    function proveBlocks(uint64[] calldata, bytes[] calldata, bytes calldata) external;
    function verifyBlocks(uint64) external;
    function getVerifiedBlockProver(uint64) external view;
    function getLastVerifiedBlock() external view;
    function getBlockV2(uint64) external view;
    function getTransition(uint64, uint32) external view;
    function getTransition(uint64, bytes32) external;
    function getTransitions(uint64[] calldata, bytes32[] calldata) external;
    function lastProposedIn() external view;
    function getStateVariables() external view;
    function getConfig() external pure;
    function resolve(uint64, bytes32, bool) external view;
    function resolve(bytes32, bool) external view;
}

/// @title PacayaForkRouter
/// @notice This contract routes calls to the current fork.
/// @custom:security-contact security@taiko.xyz
contract PacayaForkRouter is ForkRouter {
    constructor(address _oldFork, address _newFork) ForkRouter(_oldFork, _newFork) { }

    function shouldRouteToOldFork(bytes4 _selector) public pure override returns (bool) {
        if (
            _selector == IOntakeFork.proposeBlockV2.selector
                || _selector == IOntakeFork.proposeBlocksV2.selector
                || _selector == IOntakeFork.proveBlock.selector
                || _selector == IOntakeFork.proveBlocks.selector
                || _selector == IOntakeFork.verifyBlocks.selector
                || _selector == IOntakeFork.getVerifiedBlockProver.selector
                || _selector == IOntakeFork.getLastVerifiedBlock.selector
                || _selector == IOntakeFork.getBlockV2.selector
                || _selector == bytes4(keccak256("getTransition(uint64,uint32)"))
                || _selector == bytes4(keccak256("getTransition(uint64,bytes32)"))
                || _selector == IOntakeFork.getTransitions.selector
                || _selector == IOntakeFork.lastProposedIn.selector
                || _selector == IOntakeFork.getStateVariables.selector
                || _selector == IOntakeFork.getConfig.selector
                || _selector == bytes4(keccak256("resolve(uint64,bytes32,bool)"))
                || _selector == bytes4(keccak256("resolve(bytes32,bool)"))
        ) return true;

        return false;
    }
}
