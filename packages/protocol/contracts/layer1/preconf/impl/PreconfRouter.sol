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

    uint256[50] private __gap;

    constructor(
        address _proposeBatchEntrypoint, // TaikoInbox or TaikoWrapper
        address _preconfWhitelist
    )
        nonZeroAddr(_proposeBatchEntrypoint)
        nonZeroAddr(_preconfWhitelist)
        EssentialContract(address(0))
    {
        proposeBatchEntrypoint = IProposeBatch(_proposeBatchEntrypoint);
        preconfWhitelist = IPreconfWhitelist(_preconfWhitelist);
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
        address operator = preconfWhitelist.getOperatorForCurrentEpoch();
        require(operator == address(0) || operator == msg.sender, NotTheOperator());

        // Both TaikoInbox and TaikoWrapper implement the same ABI for proposeBatch.
        (info_, meta_) = proposeBatchEntrypoint.proposeBatch(_params, _txList);

        // Verify that the sender had set itself as the proposer
        require(meta_.proposer == msg.sender, ProposerIsNotTheSender());
    }
}
