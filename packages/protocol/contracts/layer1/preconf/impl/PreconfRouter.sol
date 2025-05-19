// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/common/EssentialContract.sol";
import "../iface/IPreconfRouter.sol";
import "../iface/IPreconfWhitelist.sol";

/// @title PreconfRouter
/// @custom:security-contact security@taiko.xyz
contract PreconfRouter is EssentialContract, IPreconfRouter {
    address public immutable proposeBlockEntrypoint;
    address public immutable preconfWhitelist;

    error InvalidLastBlockId(uint96 _actual, uint96 _expected);

    uint256[50] private __gap;

    constructor(
        address _proposeBlockEntrypoint, // TaikoInbox or TaikoWrapper
        address _preconfWhitelist
    )
        nonZeroAddr(_proposeBlockEntrypoint)
        nonZeroAddr(_preconfWhitelist)
        EssentialContract(address(0))
    {
        proposeBlockEntrypoint = _proposeBlockEntrypoint;
        preconfWhitelist = _preconfWhitelist;
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
        address selectedOperator = IPreconfWhitelist(preconfWhitelist).getOperatorForCurrentEpoch();
        require(msg.sender == selectedOperator, NotTheOperator());

        // Both TaikoInbox and TaikoWrapper implement the same ABI for proposeBatch.
        (info_, meta_) = IProposeBatch(proposeBlockEntrypoint).proposeBatch(_params, _txList);

        // Verify that the sender had set itself as the proposer
        require(meta_.proposer == msg.sender, ProposerIsNotTheSender());
    }

    function proposeBatchWithExpectedLastBlockId(
        bytes calldata _params,
        bytes calldata _txList,
        uint96 _expectedLastBlockId
    )
        external
        returns (ITaikoInbox.BatchInfo memory info_, ITaikoInbox.BatchMetadata memory meta_)
    {
        (info_, meta_) = this.proposeBatch(_params, _txList);

        // Verify that the last block id is as expected
        require(
            info_.lastBlockId == _expectedLastBlockId,
            InvalidLastBlockId(info_.lastBlockId, _expectedLastBlockId)
        );
    }
}
