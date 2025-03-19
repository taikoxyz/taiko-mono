// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/common/EssentialContract.sol";
import "../iface/IPreconfRouter.sol";
import "../iface/IPreconfWhitelist.sol";

/// @title PreconfRouter
/// @custom:security-contact security@taiko.xyz
contract PreconfRouter is EssentialContract, IPreconfRouter {
    IProposeBatch public immutable proposeBatchEntrypoint;
    IPreconfWhitelist public immutable preconfWhitelist;
    address public immutable fallbackPreconfer;

    uint256[50] private __gap;

    constructor(
        address _proposeBatchEntrypoint, // TaikoInbox or TaikoWrapper
        address _preconfWhitelist,
        address _fallbackPreconfer
    )
        nonZeroAddr(_proposeBatchEntrypoint)
        nonZeroAddr(_preconfWhitelist)
        EssentialContract(address(0))
    {
        proposeBatchEntrypoint = IProposeBatch(_proposeBatchEntrypoint);
        preconfWhitelist = IPreconfWhitelist(_preconfWhitelist);
        fallbackPreconfer = _fallbackPreconfer;
    }

    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    /// @inheritdoc IProposeBatch
    function proposeBatch(
        bytes calldata _params,
        bytes calldata _txList
    )
        external
        returns (ITaikoInbox.BatchInfo memory info_, ITaikoInbox.BatchMetadata memory meta_)
    {
        // Sender must be the selected operator for the epoch
        address preconfer = preconfWhitelist.getOperatorForCurrentEpoch();
        if (preconfer != address(0)) {
            require(msg.sender == preconfer, NotPreconfer());
        } else if (fallbackPreconfer != address(0)) {
            require(msg.sender == fallbackPreconfer, NotFallbackPreconfer());
        }

        // Both TaikoInbox and TaikoWrapper implement the same ABI for proposeBatch.
        (info_, meta_) = proposeBatchEntrypoint.proposeBatch(_params, _txList);

        // Verify that the sender had set itself as the proposer
        require(meta_.proposer == msg.sender, ProposerIsNotPreconfer());
    }
}
