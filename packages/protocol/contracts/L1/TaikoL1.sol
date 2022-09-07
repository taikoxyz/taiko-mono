// SPDX-License-Identifier: MIT
//
// ╭━━━━╮╱╱╭╮╱╱╱╱╱╭╮╱╱╱╱╱╭╮
// ┃╭╮╭╮┃╱╱┃┃╱╱╱╱╱┃┃╱╱╱╱╱┃┃
// ╰╯┃┃┣┻━┳┫┃╭┳━━╮┃┃╱╱╭━━┫╰━┳━━╮
// ╱╱┃┃┃╭╮┣┫╰╯┫╭╮┃┃┃╱╭┫╭╮┃╭╮┃━━┫
// ╱╱┃┃┃╭╮┃┃╭╮┫╰╯┃┃╰━╯┃╭╮┃╰╯┣━━┃
// ╱╱╰╯╰╯╰┻┻╯╰┻━━╯╰━━━┻╯╰┻━━┻━━╯
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";

import "../common/ConfigManager.sol";
import "../common/EssentialContract.sol";
import "./LibData.sol";
import "./v1/LibFinalize.sol";
import "./v1/LibPropose.sol";
import "./v1/LibProve.sol";


contract TaikoL1 is EssentialContract {
    using LibData for LibData.State;
    using LibFinalize for LibData.State;
    using LibPropose for LibData.State;
    using LibProve for LibData.State;
    using LibTxDecoder for bytes;
    using SafeCastUpgradeable for uint256;

    LibData.State public state;
    uint256[44] private __gap;

    function init(address _addressManager, bytes32 _genesisBlockHash)
        external
        initializer
    {
        EssentialContract._init(_addressManager);
        state.init(_genesisBlockHash);
    }

    /// @notice Write a _commit hash_ so a few blocks later a L2 block can be proposed
    ///         such that `calculateCommitHash(context.beneficiary, context.txListHash)`
    ///         equals to this commit hash.
    /// @param commitHash A commit hash calculated as: `calculateCommitHash(beneficiary, txListHash)`.
    function commitBlock(bytes32 commitHash) external {
        state.commitBlock(commitHash);
    }

    /// @notice Propose a Taiko L2 block.
    /// @param inputs A list of data input:
    ///
    ///     - inputs[0] is abi-encoded BlockContext that the actual L2 block header
    ///       must satisfy.
    ///       Note the following fields in the provided context object must
    ///       be zeros -- their actual values will be provisioned by Ethereum.
    ///        - id
    ///        - anchorHeight
    ///        - context.anchorHash
    ///        - mixHash
    ///        - proposedAt
    ///
    ///     - inputs[1] is a list of transactions in this block, encoded with RLP.
    ///       Note in the corresponding L2 block, an _anchor transaction_ will be
    ///       the first transaction in the block, i.e., if there are n transactions
    ///       in `txList`, then then will be up to n+1 transactions in the L2 block.
    function proposeBlock(bytes[] calldata inputs)
        external
        payable
        nonReentrant
    {
        state.proposeBlock(inputs);
        state.finalizeBlocks();
    }

    /// @notice Prove a block is valid with a zero-knowledge proof, a transaction
    ///         merkel proof, and a receipt merkel proof.
    /// @param blockId The id of the block to prove. This is also used to select
    ///        the right implementation version.
    /// @param inputs A list of data input:
    ///
    ///     - inputs[0] is an abi-encoded object with various information regarding
    ///       the block to be proven and the actual proofs.
    ///
    ///     - inputs[1] is the actual anchor transaction in this L2 block. Note that
    ///       the anchor tranaction is always the first transaction in the block.
    ///
    ///     - inputs[2] is the receipt of the anchor transaction.
    function proveBlock(uint256 blockId, bytes[] calldata inputs)
        external
        nonReentrant
    {
        state.proveBlock(AddressResolver(this), blockId, inputs);
        state.finalizeBlocks();
    }

    /// @notice Prove a block is invalid with a zero-knowledge proof and
    ///         a receipt merkel proof
    /// @param blockId The id of the block to prove. This is also used to select
    ///        the right implementation version.
    /// @param inputs A list of data input:
    ///
    ///     - inputs[0] An Evidence object with various information regarding
    ///       the block to be proven and the actual proofs.
    ///
    ///     - inputs[1] The target block to be proven invalid.
    ///
    ///     - inputs[2] The receipt for the `invalidBlock` transaction
    ///       on L2. Note that the `invalidBlock` transaction is supposed to
    ///       be the only transaction in the L2 block.
    function proveBlockInvalid(uint256 blockId, bytes[] calldata inputs)
        external
        nonReentrant
    {
        state.proveBlockInvalid(AddressResolver(this), blockId, inputs);
        state.finalizeBlocks();
    }

    function isCommitValid(bytes32 hash) public view returns (bool) {
        return state.isCommitValid(hash);
    }
}
