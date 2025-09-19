// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// import "urc/src/IRegistry.sol";
import "src/shared/common/EssentialContract.sol";
import "src/layer1/based/IProposeBatch.sol";
import "../iface/IPreconfWhitelist.sol";

/// @title PreconfRouter
/// @custom:security-contact security@taiko.xyz
contract PreconfRouter is EssentialContract, IProposeBatch {
    IProposeBatch public immutable iProposeBatch;
    IPreconfWhitelist public immutable preconfWhitelist;

    error ForcedInclusionNotSupported();
    error NotPreconfer();
    error ProposerIsNotPreconfer();

    uint256[50] private __gap;

    constructor(
        address _iProposeBatch, // TaikoInbox or TaikoWrapper
        address _preconfWhitelist
    )
        nonZeroAddr(_iProposeBatch)
        nonZeroAddr(_preconfWhitelist)
    {
        iProposeBatch = IProposeBatch(_iProposeBatch);
        preconfWhitelist = IPreconfWhitelist(_preconfWhitelist);
    }

    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    /// @inheritdoc IProposeBatch
    function v4ProposeBatch(
        bytes calldata _params,
        bytes calldata _txList,
        bytes calldata /* _additionalData */
    )
        external
        returns (ITaikoInbox.BatchInfo memory info_, ITaikoInbox.BatchMetadata memory meta_)
    {
        // Sender must be the selected operator for the epoch
        address preconfer = preconfWhitelist.getOperatorForCurrentEpoch();
        require(preconfer != address(0), ProposerIsNotPreconfer());
        require(msg.sender == preconfer, NotPreconfer());

        // Both TaikoInbox and TaikoWrapper implement the same ABI for IProposeBatch.
        (info_, meta_) = iProposeBatch.v4ProposeBatch(_params, _txList, "");

        // Verify that the sender had set itself as the proposer
        require(info_.proposer == msg.sender, ProposerIsNotPreconfer());
    }
}
