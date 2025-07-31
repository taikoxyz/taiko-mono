// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/libs/LibMath.sol";
import "./ISpecs.sol";
import "../IShastaInbox.sol";
import "src/layer1/preconf/libs/LibBlockHeader.sol";

abstract contract BuildBlocksSpec is ISpecs {
    using LibMath for uint256;

    uint256 constant L1_BLOCK_TIME = 12;
    uint256 constant MAX_BLOCK_TIMESTAMP_OFFSET = L1_BLOCK_TIME * 8;
    uint256 constant MIN_L2_BLOCK_TIME = 1;

    uint256 constant DEFAULT_GAS_ISSUANCE_PER_SECOND = 1_000_000;
    uint256 constant GAS_ISSUANCE_PER_SECOND_MAX_OFFSET = 101;
    uint256 constant GAS_ISSUANCE_PER_SECOND_MIN_OFFSET = 99;

    function decodeProposalDataFromBlobs(bytes memory blobData)
        external
        view
        returns (ProposalData memory proposalData)
    {
        try this.decodeBlobData(blobData) returns (ProposalData memory _proposalData) {
            proposalData = _proposalData;
        } catch {
            proposalData.blocks = new Block[](1);
        }
    }

    function compileBuildBlockInput(
        IShastaInbox.Proposal memory proposal, // from L1
        LibBlockHeader.BlockHeader memory referenceBlockHeader, // from L1
        ProposalData memory proposalData, // from L1 blobs
        ProtocolState memory protocolState, // from L2
        LibBlockHeader.BlockHeader memory parentBlockHeader, // from L2
        uint256 i // the i-th block in the list.
    )
        external
        returns (BuildBlockInput memory input)
    {
        require(i < proposalData.blocks.length, "Invalid block index");

        Block memory blk = proposalData.blocks[i];
        if (i == 0) {
            if (protocolState.gasIssuancePerSecond == 0) {
                protocolState.gasIssuancePerSecond = DEFAULT_GAS_ISSUANCE_PER_SECOND;
            }
        }

        //--------------------------------
        input.parentHash = _computeBlockHash(parentBlockHeader);
        input.number = parentBlockHeader.number + 1;

        //-------------------------------
        blk.timestamp = blk.timestamp.max(parentBlockHeader.timestamp + MIN_L2_BLOCK_TIME);
        blk.timestamp = blk.timestamp.min(referenceBlockHeader.timestamp + L1_BLOCK_TIME);
        blk.timestamp =
            blk.timestamp.min(referenceBlockHeader.timestamp + MAX_BLOCK_TIMESTAMP_OFFSET);
        input.timestamp = blk.timestamp;

        uint256 blockTime = input.timestamp - parentBlockHeader.timestamp;
        uint256 gasIssuance = blockTime * protocolState.gasIssuancePerSecond;
        input.gasLimit = gasIssuance * 2;

        //--------------------------------
        input.feeRecipient = proposalData.blocks[i].feeRecipient == address(0)
            ? proposal.proposer
            : proposalData.blocks[i].feeRecipient;

        //--------------------------------
        input.prevRandao = keccak256(abi.encode(input.number, referenceBlockHeader.prevRandao));

        // Execute all transactions here.

        if (i == proposalData.blocks.length - 1) {
            if (proposalData.gasIssuancePerSecond != 0) {
                // last block
                uint256 max =
                    protocolState.gasIssuancePerSecond * GAS_ISSUANCE_PER_SECOND_MAX_OFFSET;
                uint256 min =
                    protocolState.gasIssuancePerSecond * GAS_ISSUANCE_PER_SECOND_MIN_OFFSET;
                uint256 v = proposalData.gasIssuancePerSecond * 100;
                if (v >= min && v <= max) {
                    protocolState.gasIssuancePerSecond = proposalData.gasIssuancePerSecond;
                }
            }

            // save the protocol state to world state.
        }
    }

    function _computeBlockHash(LibBlockHeader.BlockHeader memory blockHeader)
        internal
        pure
        virtual
        returns (bytes32);

    function decodeBlobData(bytes memory blobData)
        internal
        pure
        virtual
        returns (ProposalData memory);

    function persistProtocolStateAndExecuteTransactionsToAdvanceBlock(
        ProtocolState memory protocolState,
        BuildBlockInput memory input,
        Transaction[] memory transactions
    )
        internal
        view
        virtual
        returns (LibBlockHeader.BlockHeader memory);
}
