// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/libs/LibMath.sol";
import "./IOffchainData.sol";
import "../IShastaInbox.sol";
import "src/layer1/preconf/libs/LibBlockHeader.sol";

abstract contract BuildBlocksSpec is IOffchainData {
    using LibMath for uint256;

    uint256 constant L1_BLOCK_TIME = 12;
    uint256 constant MAX_BLOCK_TIMESTAMP_OFFSET = L1_BLOCK_TIME * 8;
    uint256 constant MIN_L2_BLOCK_TIME = 1;
    uint32 constant DEFAULT_GAS_ISSUANCE_PER_SECOND = 1_000_000;

    function buildBlocks(
        IShastaInbox.Proposal memory proposal, // from L1
        LibBlockHeader.BlockHeader memory referenceBlockHeader, // from L1
        LibBlockHeader.BlockHeader memory parentBlockHeader, // from L2
        L2ProtocolState memory protocolState, // from L2
        bytes memory blobData // from L1
    )
        external
        view
    {
        ProposalSpec memory proposalSpec = _decodeBlobData(blobData);

        for (uint256 i = 0; i < proposalSpec.blocks.length; i++) {
            BlockParams memory blockParams = proposalSpec.blocks[i];

            BuildBlockInputs memory inputs;

            //--------------------------------
            inputs.parentHash = _computeBlockHash(parentBlockHeader);
            inputs.number = parentBlockHeader.number + 1;

            //-------------------------------
            blockParams.timestamp =
                blockParams.timestamp.max(parentBlockHeader.timestamp + MIN_L2_BLOCK_TIME);
            blockParams.timestamp =
                blockParams.timestamp.min(referenceBlockHeader.timestamp + L1_BLOCK_TIME);
            blockParams.timestamp =
                blockParams.timestamp.min(referenceBlockHeader.timestamp + MAX_BLOCK_TIMESTAMP_OFFSET);
            inputs.timestamp = blockParams.timestamp;

            //--------------------------------
            if (i == 0) {
                // the first block
                if (protocolState.gasIssuancePerSecond == 0) {
                    protocolState.gasIssuancePerSecond = DEFAULT_GAS_ISSUANCE_PER_SECOND;
                }
            }

            uint256 blockTime = inputs.timestamp - parentBlockHeader.timestamp;
            uint256 gasIssuance = blockTime * protocolState.gasIssuancePerSecond;
            inputs.gasLimit = gasIssuance * 2;

            // The following are offered by builder by running the L2 transactions.
            // header.stateRoot;
            // header.txRoot;
            // header.receiptRoot;

            if (i == proposalSpec.blocks.length - 1) {
                // last block
                uint256 max = protocolState.gasIssuancePerSecond * 101;
                uint256 min = protocolState.gasIssuancePerSecond * 99;
                uint256 v = proposalSpec.gasIssuancePerSecond * 100;
                if (v >= min && v <= max) {
                    protocolState.gasIssuancePerSecond = proposalSpec.gasIssuancePerSecond;
                }
            }

            //--------------------------------
            inputs.feeRecipient = proposalSpec.blocks[i].feeRecipient == address(0)
                ? proposal.proposer
                : proposalSpec.blocks[i].feeRecipient;

            //--------------------------------
            inputs.prevRandao = keccak256(abi.encode(inputs.number, referenceBlockHeader.prevRandao));

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

    function _computeBlockHash(LibBlockHeader.BlockHeader memory blockHeader)
        internal
        pure
        virtual
        returns (bytes32);
}
