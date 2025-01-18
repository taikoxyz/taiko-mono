// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../iface/IPreconfRouter.sol";
import "../iface/IPreconfWhitelist.sol";
import "src/layer1/based/ITaikoInbox.sol";
import "src/shared/libs/LibStrings.sol";
import "src/shared/common/EssentialContract.sol";

/// @title PreconfRouter
/// @custom:security-contact security@taiko.xyz
contract PreconfRouter is EssentialContract, IPreconfRouter {
    function init(address _owner, address _sharedResolver) external initializer {
        __Essential_init(_owner, _sharedResolver);
    }

    /// @inheritdoc IPreconfRouter
    function proposePreconfedBlocks(
        bytes calldata,
        bytes calldata _batchParams,
        bytes calldata _batchTxList
    )
        external
        returns (ITaikoInbox.BatchMetadata memory)
    {
        // Sender must be the selected operator for the epoch
        address selectedOperator =
            IPreconfWhitelist(resolve(LibStrings.B_PRECONF_WHITELIST, false)).getOperatorForEpoch();
        require(msg.sender == selectedOperator, NOT_THE_OPERATOR());

        // Force set the `proposer` field in the batch params to be the sender
        ITaikoInbox.BatchParams memory batchParams =
            abi.decode(_batchParams, (ITaikoInbox.BatchParams));
        batchParams.proposer = msg.sender;

        // Call the proposeBatch function on the TaikoInbox
        address taikoInbox = resolve(LibStrings.B_TAIKO, false);
        return ITaikoInbox(taikoInbox).proposeBatch(abi.encode(batchParams), _batchTxList);
    }
}
