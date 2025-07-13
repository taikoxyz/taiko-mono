// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../mainnet/MainnetInbox.sol";
import "./LibWriteTransition.sol";

/// @title HeklaInbox
/// @dev Labeled in address resolver as "taiko"
/// @custom:security-contact security@taiko.xyz
contract HeklaInbox is MainnetInbox {
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

    function _getForkHeights() internal pure override returns (ITaikoInbox.ForkHeights memory) {
        return ITaikoInbox.ForkHeights({
            ontake: 840_512,
            pacaya: 1_299_888,
            shasta: 0,
            unzen: 0,
            etna: 0,
            fuji: 0
        });
    }
}
