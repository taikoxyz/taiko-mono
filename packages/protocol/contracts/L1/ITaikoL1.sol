// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./TaikoData.sol";

/// @title ITaikoL1
/// @custom:security-contact security@taiko.xyz
interface ITaikoL1 {
    /// @notice Proposes a Taiko L2 block.
    /// @param params Block parameters, currently an encoded BlockParams object.
    /// @param txList txList data if calldata is used for DA.
    /// @return meta The metadata of the proposed L2 block.
    /// @return depositsProcessed The Ether deposits processed.
    function proposeBlock(
        bytes calldata params,
        bytes calldata txList
    )
        external
        payable
        returns (
            TaikoData.BlockMetadata memory meta,
            TaikoData.EthDeposit[] memory depositsProcessed
        );

    /// @notice Proves or contests a block transition.
    /// @param blockId The index of the block to prove. This is also used to
    /// select the right implementation version.
    /// @param input An abi-encoded (BlockMetadata, Transition, TierProof)
    /// tuple.
    function proveBlock(uint64 blockId, bytes calldata input) external;

    /// @notice Verifies up to a certain number of blocks.
    /// @param maxBlocksToVerify Max number of blocks to verify.
    function verifyBlocks(uint64 maxBlocksToVerify) external;

    /// @notice Gets the configuration of the TaikoL1 contract.
    /// @return Config struct containing configuration parameters.
    function getConfig() external view returns (TaikoData.Config memory);
}
