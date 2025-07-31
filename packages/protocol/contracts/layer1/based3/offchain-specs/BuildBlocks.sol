// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/libs/LibMath.sol";
import "./IOffchainData.sol";
import "../IShastaInbox.sol";

abstract contract BuildBlocksSpec is IOffchainData {
    using LibMath for uint256;

    uint256 constant L1_BLOCK_TIME = 12;
    uint256 constant MAX_BLOCK_TIMESTAMP_OFFSET = L1_BLOCK_TIME * 8;
    uint256 constant MIN_L2_BLOCK_TIME = 1;
    uint32 constant DEFAULT_GAS_ISSUANCE_PER_SECOND = 1_000_000;

    function buildBlocks(
        IShastaInbox.Proposal memory proposal,
        L1LatestBlockData memory l1LatestBlockData,
        L2ParentBlockData memory l2ParentBlockData,
        L2ProtocolState memory l2ProtocolState,
        bytes memory blobData
    )
        external
        view
    {
        ProposalSpec memory proposalSpec = _decodeBlobData(blobData);

        for (uint256 i = 0; i < proposalSpec.blocks.length; i++) {
            BlockParams memory blockParams = proposalSpec.blocks[i];

            BuildBlockInputs memory inputs;

            //--------------------------------
            inputs.parentHash = l2ParentBlockData.blockHash;
            inputs.number = l2ParentBlockData.number + 1;

            //-------------------------------
            blockParams.timestamp =
                blockParams.timestamp.max(l2ParentBlockData.timestamp + MIN_L2_BLOCK_TIME);
            blockParams.timestamp =
                blockParams.timestamp.min(l1LatestBlockData.timestamp + L1_BLOCK_TIME);
            blockParams.timestamp =
                blockParams.timestamp.min(l1LatestBlockData.timestamp + MAX_BLOCK_TIMESTAMP_OFFSET);
            inputs.timestamp = blockParams.timestamp;

            //--------------------------------
            if (i == 0) {
                // the first block
                if (l2ProtocolState.gasIssuancePerSecond == 0) {
                    l2ProtocolState.gasIssuancePerSecond = DEFAULT_GAS_ISSUANCE_PER_SECOND;
                }
            }

            uint256 blockTime = inputs.timestamp - l2ParentBlockData.timestamp;
            uint256 gasIssuance = blockTime * l2ProtocolState.gasIssuancePerSecond;
            inputs.gasLimit = gasIssuance * 2;

            // The following are offered by builder by running the L2 transactions.
            // header.stateRoot;
            // header.txRoot;
            // header.receiptRoot;

            if (i == proposalSpec.blocks.length - 1) {
                // last block
                uint256 max = l2ProtocolState.gasIssuancePerSecond * 101;
                uint256 min = l2ProtocolState.gasIssuancePerSecond * 99;
                uint256 v = proposalSpec.gasIssuancePerSecond * 100;
                if (v >= min && v <= max) {
                    l2ProtocolState.gasIssuancePerSecond = proposalSpec.gasIssuancePerSecond;
                }
            }

            //--------------------------------
            inputs.feeRecipient = proposalSpec.blocks[i].feeRecipient == address(0)
                ? proposal.proposer
                : proposalSpec.blocks[i].feeRecipient;

            //--------------------------------
            inputs.prevRando = keccak256(abi.encode(inputs.number, l1LatestBlockData.prevRando));

            //--------------------------------
            inputs.extraData = bytes32(inputs.number);
            inputs.withdrawalsRoot = bytes32(0);
        }
    }

    function decodeBlobData(bytes memory blobData) external pure returns (ProposalSpec memory) {
        return abi.decode(blobData, (ProposalSpec));
    }

    // -------------------------------------------------------------------------
    // Proposal Leading Call
    // -------------------------------------------------------------------------

    function _decodeBlobData(bytes memory blobData)
        internal
        view
        returns (ProposalSpec memory proposalSpec)
    {
        try this.decodeBlobData(blobData) returns (ProposalSpec memory spec) {
            proposalSpec = spec;
        } catch { }

        if (proposalSpec.blocks.length == 0) {
            proposalSpec.blocks = new BlockParams[](1);
        }
    }
}
