// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./ForkRouter.sol";

/// @title IPacayaFork
/// @dev Derived from TaikoInbox.sol in the Pacaya fork
/// https://github.com/taikoxyz/taiko-mono/tree/taiko-alethia-protocol-v2.2.0
/// @custom:security-contact security@taiko.xyz
interface IPacayaFork {
    // Return value types, visibility, or mutability modifiers do not affect the function selector.
    function proposeBatch(bytes calldata, bytes calldata) external;
    function proveBatches(bytes calldata, bytes calldata) external;
    function verifyBatches(uint64) external;
    function depositBond(uint256) external;
    function withdrawBond(uint256) external;
    function bondBalanceOf(address) external;
    function bondToken() external;
    function inboxWrapper() external;
    function verifier() external;
    function getStats1() external;
    function getStats2() external;
    function getBatch(uint64) external;
    function getTransitionById(uint64, uint24) external;
    function getTransitionByParentHash(uint64, bytes32) external;
    function getLastVerifiedTransition() external;
    function getLastSyncedTransition() external;
    function getBatchVerifyingTransition(uint64) external;
    function pacayaConfig() external;
    function isOnL1() external;
    function v4GetConfig() external;
    function pause() external;
    function unpause() external;
    function paused() external;
}

/// @title ShastaForkRouter
/// @notice This contract routes calls to the current fork.
/// @custom:security-contact security@taiko.xyz
contract ShastaForkRouter is ForkRouter {
    constructor(address _oldFork, address _newFork) ForkRouter(_oldFork, _newFork) { }

    function shouldRouteToOldFork(bytes4 _selector) public pure override returns (bool) {
        if (
            _selector == IPacayaFork.proposeBatch.selector
                || _selector == IPacayaFork.proveBatches.selector
                || _selector == IPacayaFork.verifyBatches.selector
                || _selector == IPacayaFork.depositBond.selector
                || _selector == IPacayaFork.withdrawBond.selector
                || _selector == IPacayaFork.bondBalanceOf.selector
                || _selector == IPacayaFork.bondToken.selector
                || _selector == IPacayaFork.inboxWrapper.selector
                || _selector == IPacayaFork.verifier.selector
                || _selector == IPacayaFork.getStats1.selector
                || _selector == IPacayaFork.getStats2.selector
                || _selector == IPacayaFork.getBatch.selector
                || _selector == IPacayaFork.getTransitionById.selector
                || _selector == IPacayaFork.getTransitionByParentHash.selector
                || _selector == IPacayaFork.getLastVerifiedTransition.selector
                || _selector == IPacayaFork.getLastSyncedTransition.selector
                || _selector == IPacayaFork.getBatchVerifyingTransition.selector
                || _selector == IPacayaFork.pacayaConfig.selector
                || _selector == IPacayaFork.isOnL1.selector
                || _selector == IPacayaFork.v4GetConfig.selector
                || _selector == IPacayaFork.pause.selector || _selector == IPacayaFork.unpause.selector
                || _selector == IPacayaFork.paused.selector
        ) return true;

        return false;
    }
}
