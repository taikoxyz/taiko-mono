// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/common/EssentialContract.sol";
import "../iface/IPreconfRouter.sol";
import "../iface/IPreconfWhitelist.sol";

/// @title PreconfRouter
/// @custom:security-contact security@taiko.xyz
contract PreconfRouter is EssentialContract, IPreconfRouter {
    IProposeBatchV2WithForcedInclusion public immutable proposeBatchEntrypoint;
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
        address _proposeBatchEntrypoint, // TaikoWrapper
        address _preconfWhitelist,
        address _fallbackPreconfer
    )
        nonZeroAddr(_proposeBatchEntrypoint)
        nonZeroAddr(_preconfWhitelist)
        EssentialContract(address(0))
    {
        proposeBatchEntrypoint = IProposeBatchV2WithForcedInclusion(_proposeBatchEntrypoint);
        preconfWhitelist = IPreconfWhitelist(_preconfWhitelist);
        fallbackPreconfer = _fallbackPreconfer;
    }

    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    function proposeBatch(
        bytes calldata _params,
        bytes calldata _txList
    )
        external
        returns (ITaikoInbox.BatchMetadata memory meta_)
    {
        return _proposeBatch(_params, _txList);
    }


    function _proposeBatch(
        bytes calldata _params,
        bytes calldata _txList
    )
        internal
        onlyFromPreconferOrFallback
        returns (ITaikoInbox.BatchMetadata memory meta_)
    {
        (bytes memory delayedBatchParamsBytes, bytes memory regularBatchParamsBytes) = abi.decode(_params, (bytes, bytes));
        ITaikoInbox.BatchParams memory delayedBatchParams = abi.decode(delayedBatchParamsBytes, (ITaikoInbox.BatchParams));
        ITaikoInbox.BatchParams memory regularBatchParams = abi.decode(regularBatchParamsBytes, (ITaikoInbox.BatchParams));

        // This calls the TaikoWrapper contract.
        meta_ = IProposeBatchV2WithForcedInclusion(proposeBatchEntrypoint).proposeBatch(delayedBatchParams, regularBatchParams, _txList);

        // Verify that the sender had set itself as the proposer
        require(meta_.proposer == msg.sender, ProposerIsNotPreconfer());
    }
}
