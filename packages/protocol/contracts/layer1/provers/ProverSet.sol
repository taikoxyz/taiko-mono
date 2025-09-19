// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./ProverSetBase.sol";
import "../based/IProposeBatch.sol";

contract ProverSet is ProverSetBase, IProposeBatch {
    using Address for address;

    IProposeBatch public immutable iProposeBatch;


    constructor(
        address _inbox,
        address _bondToken,
        address _iProposeBatch
    )
        nonZeroAddr(_iProposeBatch)
        ProverSetBase(_inbox, _bondToken)
    {
        iProposeBatch = IProposeBatch(_iProposeBatch);
    }

    // ================ Pacaya calls ================

    /// @notice Propose a batch of Taiko blocks.
    function v4ProposeBatch(
        bytes calldata _params,
        bytes calldata _txList,
        bytes calldata _additionalData
    )
        external
        onlyProver
        returns (ITaikoInbox.BatchInfo memory, ITaikoInbox.BatchMetadata memory)
    {
        return iProposeBatch.v4ProposeBatch(_params, _txList, _additionalData);
    }

    /// @notice Proves multiple Taiko batches.
    function proveBatches(bytes calldata _params, bytes calldata _proof) external onlyProver {
        ITaikoInbox(inbox).v4ProveBatches(_params, _proof);
    }

    // ================ Ontake calls ================

    /// @notice Proposes a batch blocks only when it is the first batch blocks proposal in the
    /// current L1 block.
    function proposeBlocksV2Conditionally(
        bytes[] calldata _params,
        bytes[] calldata _txList
    )
        external
        onlyProver
    {
        // Ensure this block is the first block proposed in the current L1 block.
        uint64 blockNumber = abi.decode(
            inbox.functionStaticCall(abi.encodeWithSignature("lastProposedIn()")), (uint64)
        );
        require(blockNumber != block.number, NOT_FIRST_PROPOSAL());
        inbox.functionCall(
            abi.encodeWithSignature("proposeBlocksV2(bytes[],bytes[])", _params, _txList)
        );
    }

    /// @notice Propose a Taiko block.
    function proposeBlockV2(bytes calldata _params, bytes calldata _txList) external onlyProver {
        inbox.functionCall(abi.encodeWithSignature("proposeBlockV2(bytes,bytes)", _params, _txList));
    }

    /// @notice Propose multiple Taiko blocks.
    function proposeBlocksV2(
        bytes[] calldata _paramsArr,
        bytes[] calldata _txListArr
    )
        external
        onlyProver
    {
        inbox.functionCall(
            abi.encodeWithSignature("proposeBlocksV2(bytes[],bytes[])", _paramsArr, _txListArr)
        );
    }

    /// @notice Proves or contests a Taiko block.
    function proveBlock(uint64 _blockId, bytes calldata _input) external onlyProver {
        inbox.functionCall(abi.encodeWithSignature("proveBlock(uint64,bytes)", _blockId, _input));
    }

    /// @notice Batch proves or contests Taiko blocks.
    function proveBlocks(
        uint64[] calldata _blockId,
        bytes[] calldata _input,
        bytes calldata _batchProof
    )
        external
        onlyProver
    {
        inbox.functionCall(
            abi.encodeWithSignature(
                "proveBlocks(uint64[],bytes[],bytes)", _blockId, _input, _batchProof
            )
        );
    }
}
