// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../mainnet/MainnetInbox.sol";
import "./LibWriteTransition.sol";

/// @title TaikoHoodiInbox
/// @dev Labeled in address resolver as "taiko"
/// @custom:security-contact security@taiko.xyz
contract TaikoHoodiInbox is MainnetInbox {
    constructor(
        address _wrapper,
        address _verifier,
        address _bondToken,
        address _signalService
    )
        MainnetInbox(_wrapper, _verifier, _bondToken, _signalService)
    { }

    /// @notice Manually write a transition for a batch.
    /// @dev This function is supposed to be used by the owner to force prove a transition for a
    /// block that has not been verified.
    function writeTransition(
        uint64 _batchId,
        bytes32 _parentHash,
        bytes32 _blockHash,
        bytes32 _stateRoot,
        address _prover,
        bool _inProvingWindow
    )
        external
        onlyOwner
    {
        LibWriteTransition.writeTransition(
            state,
            _getConfig(),
            _batchId,
            _parentHash,
            _blockHash,
            _stateRoot,
            _prover,
            _inProvingWindow
        );
    }

    /// @dev Never change the following two values!!!
    function _getRingbufferConfig()
        internal
        pure
        override
        returns (uint64 maxUnverifiedBatches_, uint64 batchRingBufferSize_)
    {
        maxUnverifiedBatches_ = 324_000;
        batchRingBufferSize_ = 324_512;
    }
}
