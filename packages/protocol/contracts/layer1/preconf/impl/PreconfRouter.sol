// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/common/EssentialContract.sol";
import "../iface/IPreconfRouter.sol";
import "../iface/IPreconfWhitelist.sol";
import "src/layer1/based/ITaikoInbox.sol";

/// @title PreconfRouter
/// @custom:security-contact security@taiko.xyz
contract PreconfRouter is EssentialContract, IPreconfRouter {
    IProposeBatch public immutable proposeBatchEntrypoint;
    IPreconfWhitelist public immutable preconfWhitelist;
    address public immutable fallbackPreconfer;
    uint64 public immutable shastaForkTimestamp;

    error InvalidLastBlockId(uint96 _actual, uint96 _expected);
    error ShastaForkAlreadyActivated();

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
        address _fallbackPreconfer,
        uint64 _shastaForkTimestamp
    )
        nonZeroAddr(_proposeBatchEntrypoint)
        nonZeroAddr(_preconfWhitelist)
        EssentialContract(address(0))
    {
        proposeBatchEntrypoint = IProposeBatch(_proposeBatchEntrypoint);
        preconfWhitelist = IPreconfWhitelist(_preconfWhitelist);
        fallbackPreconfer = _fallbackPreconfer;
        shastaForkTimestamp = _shastaForkTimestamp;
    }

    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    function proposeBatch(
        bytes calldata _params,
        bytes calldata _txList
    )
        external
        returns (ITaikoInbox.BatchMetadata memory meta_, uint64 lastBlockId_)
    {
        return _proposeBatch(_params, _txList);
    }

    function proposeBatchWithExpectedLastBlockId(
        bytes calldata _params,
        bytes calldata _txList,
        uint96 _expectedLastBlockId
    )
        external
        returns (ITaikoInbox.BatchMetadata memory meta_, uint64 lastBlockId_)
    {
        (meta_, lastBlockId_) = _proposeBatch(_params, _txList);

        // Verify that the last block id is as expected
        require(
            lastBlockId_ == _expectedLastBlockId,
            InvalidLastBlockId(uint96(lastBlockId_), _expectedLastBlockId)
        );
    }

    /// @inheritdoc IPreconfRouter
    function getConfig() external pure returns (IPreconfRouter.Config memory) {
        return IPreconfRouter.Config({ handOverSlots: 8 });
    }

    function _proposeBatch(
        bytes calldata _params,
        bytes calldata _txList
    )
        internal
        onlyFromPreconferOrFallback
        returns (ITaikoInbox.BatchMetadata memory meta_, uint64 lastBlockId_)
    {
        uint64 currentTimestamp = uint64(block.timestamp);
        if (currentTimestamp >= shastaForkTimestamp) {
            revert ShastaForkAlreadyActivated();
        }

        // Both TaikoInbox and TaikoWrapper implement the same ABI for proposeBatch.
        (meta_, lastBlockId_) = IProposeBatch(proposeBatchEntrypoint).proposeBatch(_params, _txList);

        // Verify that the sender had set itself as the proposer
        require(meta_.proposer == msg.sender, ProposerIsNotPreconfer());
    }
}
