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

    error InvalidLastBlockId(uint96 _actual, uint96 _expected);

    uint256[50] private __gap;

    modifier onlyFromPreconferOrFallback() {
        require(
            msg.sender == fallbackPreconfer
                || msg.sender == preconfWhitelist.getOperatorForCurrentEpoch(),
            NotPreconferOrFallback()
        );
        _;
    }

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
        returns (ITaikoInbox.BatchInfo memory, ITaikoInbox.BatchMetadata memory)
    {
        return _proposeBatch(_params, _txList);
    }

    function proposeBatchWithExpectedLastBlockId(
        bytes calldata _params,
        bytes calldata _txList,
        uint96 _expectedLastBlockId
    )
        external
        returns (ITaikoInbox.BatchInfo memory info_, ITaikoInbox.BatchMetadata memory meta_)
    {
        (info_, meta_) = _proposeBatch(_params, _txList);

        // Verify that the last block id is as expected
        require(
            info_.lastBlockId == _expectedLastBlockId,
            InvalidLastBlockId(info_.lastBlockId, _expectedLastBlockId)
        );
    }

    /// @inheritdoc IPreconfRouter
    function getConfig() external pure returns (IPreconfRouter.Config memory) {
        // TODO(jeff): determine the correct number of hand over slots before we deploy
        return IPreconfRouter.Config({ handOverSlots: 4 });
    }

    function _proposeBatch(
        bytes calldata _params,
        bytes calldata _txList
    )
        internal
        onlyFromPreconferOrFallback
        returns (ITaikoInbox.BatchInfo memory info_, ITaikoInbox.BatchMetadata memory meta_)
    {
        // Both TaikoInbox and TaikoWrapper implement the same ABI for proposeBatch.
        (info_, meta_) = IProposeBatch(proposeBatchEntrypoint).proposeBatch(_params, _txList);

        // Verify that the sender had set itself as the proposer
        require(meta_.proposer == msg.sender, ProposerIsNotPreconfer());
    }
}
