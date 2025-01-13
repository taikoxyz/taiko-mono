// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./ProverSetBase.sol";

contract ProverSet is ProverSetBase {
    error NotFirstProposal();
    // ================ Pacaya calls ================

    /// @notice Propose a batch of Taiko blocks.
    function proposeBatch(bytes calldata _params, bytes calldata _txList) external onlyProver {
        Address.functionCall(
            inbox(), abi.encodeWithSignature("proposeBatch(bytes,bytes)", _params, _txList)
        );
    }

    /// @notice Proves multiple Taiko batches.
    function proveBatches(bytes calldata _params, bytes calldata _proof) external onlyProver {
        Address.functionCall(
            inbox(), abi.encodeWithSignature("proveBatches(bytes,bytes)", _params, _proof)
        );
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
        address inbox = inbox();
        // Ensure this block is the first block proposed in the current L1 block.
        uint64 blockNumber = abi.decode(
            Address.functionStaticCall(inbox, abi.encodeWithSignature("lastProposedIn()")), (uint64)
        );
        require(blockNumber != block.number, NotFirstProposal());
        Address.functionCall(
            inbox, abi.encodeWithSignature("proposeBlocksV2(bytes[],bytes[])", _params, _txList)
        );
    }

    /// @notice Propose a Taiko block.
    function proposeBlockV2(bytes calldata _params, bytes calldata _txList) external onlyProver {
        Address.functionCall(
            inbox(), abi.encodeWithSignature("proposeBlockV2(bytes,bytes)", _params, _txList)
        );
    }

    /// @notice Propose multiple Taiko blocks.
    function proposeBlocksV2(
        bytes[] calldata _paramsArr,
        bytes[] calldata _txListArr
    )
        external
        onlyProver
    {
        Address.functionCall(
            inbox(),
            abi.encodeWithSignature("proposeBlocksV2(bytes[],bytes[])", _paramsArr, _txListArr)
        );
    }

    /// @notice Proves or contests a Taiko block.
    function proveBlock(uint64 _blockId, bytes calldata _input) external onlyProver {
        Address.functionCall(
            inbox(), abi.encodeWithSignature("proveBlock(uint64,bytes)", _blockId, _input)
        );
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
        Address.functionCall(
            inbox(),
            abi.encodeWithSignature(
                "proveBlocks(uint64[],bytes[],bytes)", _blockId, _input, _batchProof
            )
        );
    }
}
