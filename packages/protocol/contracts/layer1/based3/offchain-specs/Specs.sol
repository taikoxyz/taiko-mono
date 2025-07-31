// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/libs/LibMath.sol";
import "./ISpecs.sol";
import "../IShastaInbox.sol";
import "src/layer1/preconf/libs/LibBlockHeader.sol";
import "./Hooks.sol";

abstract contract BuildBlocksSpec is ISpecs {
    using LibMath for uint256;

    uint256 constant L1_BLOCK_TIME = 12;
    uint256 constant MAX_BLOCK_TIMESTAMP_OFFSET = L1_BLOCK_TIME * 8;
    uint256 constant MIN_L2_BLOCK_TIME = 1;
    uint256 constant DEFAULT_GAS_ISSUANCE_PER_SECOND = 1_000_000;
    bytes32 constant EMPTY_WITHDRAWALS_ROOT = bytes32(0);

    function createBlockBuildingInputs(
        IShastaInbox.Proposal memory proposal, // from L1
        LibBlockHeader.BlockHeader memory referenceBlockHeader, // from L1
        bytes memory blobData, // from L1
        ProtocolState memory protocolState, // from L2
        LibBlockHeader.BlockHeader memory parentBlockHeader // from L2
    )
        external
        view
        returns (BuildBlockInput[] memory inputs)
    {
        ProposalData memory proposalSpec = decodeAndValidateProposalData(blobData);

        for (uint256 i; i < proposalSpec.blocks.length; i++) {
            Block memory blk = proposalSpec.blocks[i];

            //--------------------------------
            inputs[i].parentHash = _computeBlockHash(parentBlockHeader);
            inputs[i].number = parentBlockHeader.number + 1;

            //-------------------------------
            blk.timestamp = blk.timestamp.max(parentBlockHeader.timestamp + MIN_L2_BLOCK_TIME);
            blk.timestamp = blk.timestamp.min(referenceBlockHeader.timestamp + L1_BLOCK_TIME);
            blk.timestamp =
                blk.timestamp.min(referenceBlockHeader.timestamp + MAX_BLOCK_TIMESTAMP_OFFSET);
            inputs[i].timestamp = blk.timestamp;

            //--------------------------------
            if (i == 0) {
                // the first block
                if (protocolState.gasIssuancePerSecond == 0) {
                    protocolState.gasIssuancePerSecond = DEFAULT_GAS_ISSUANCE_PER_SECOND;
                }
            }

            uint256 blockTime = inputs[i].timestamp - parentBlockHeader.timestamp;
            uint256 gasIssuance = blockTime * protocolState.gasIssuancePerSecond;
            inputs[i].gasLimit = gasIssuance * 2;

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
            inputs[i].feeRecipient = proposalSpec.blocks[i].feeRecipient == address(0)
                ? proposal.proposer
                : proposalSpec.blocks[i].feeRecipient;

            //--------------------------------
            inputs[i].prevRandao =
                keccak256(abi.encode(inputs[i].number, referenceBlockHeader.prevRandao));

            //--------------------------------
            inputs[i].extraData = bytes32(inputs[i].number);
            inputs[i].withdrawalsRoot = EMPTY_WITHDRAWALS_ROOT;
        }
    }

    function decodeBlobData(bytes memory blobData) external pure returns (ProposalData memory) {
        return abi.decode(blobData, (ProposalData));
    }

    // -------------------------------------------------------------------------
    // Proposal Leading Call
    // -------------------------------------------------------------------------

    function decodeAndValidateProposalData(bytes memory blobData)
        internal
        view
        returns (ProposalData memory proposalData)
    {
        try this.decodeBlobData(blobData) returns (ProposalData memory _proposalData) {
            proposalData = _proposalData;
        } catch {
            proposalData.blocks = new Block[](1);
        }
    }

    function _computeBlockHash(LibBlockHeader.BlockHeader memory blockHeader)
        internal
        pure
        virtual
        returns (bytes32);
}
