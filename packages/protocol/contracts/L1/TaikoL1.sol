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
import "../libs/LibAnchorSignature.sol";
import "./LibData.sol";
import "./v1/V1Events.sol";
import "./v1/V1Finalizing.sol";
import "./v1/V1Proposing.sol";
import "./v1/V1Proving.sol";

/// @author dantaik <dan@taiko.xyz>
contract TaikoL1 is EssentialContract, V1Events {
    using LibData for LibData.State;
    using LibTxDecoder for bytes;
    using SafeCastUpgradeable for uint256;

    LibData.State public state;
    uint256[45] private __gap;

    function init(address _addressManager, bytes32 _genesisBlockHash)
        external
        initializer
    {
        EssentialContract._init(_addressManager);
        V1Finalizing.init(state, _genesisBlockHash);
    }

    /// @notice Write a _commit hash_ so a few blocks later a L2 block can be proposed
    ///         such that `calculateCommitHash(context.beneficiary, context.txListHash)`
    ///         equals to this commit hash.
    /// @param commitHash A commit hash calculated as: `calculateCommitHash(beneficiary, txListHash)`.
    function commitBlock(bytes32 commitHash) external {
        V1Proposing.commitBlock(state, commitHash);
    }

    /// @notice Propose a Taiko L2 block.
    /// @param inputs A list of data input:
    ///
    ///     - inputs[0] is abi-encoded BlockContext that the actual L2 block header
    ///       must satisfy.
    ///       Note the following fields in the provided context object must
    ///       be zeros -- their actual values will be provisioned by Ethereum.
    ///        - id
    ///        - latestL1Height
    ///        - latestL1Hash
    ///        - mixHash
    ///        - proposedAt
    ///
    ///     - inputs[1] is a list of transactions in this block, encoded with RLP.
    ///       Note in the corresponding L2 block, an _anchor transaction_ will be
    ///       the first transaction in the block, i.e., if there are n transactions
    ///       in `txList`, then then will be up to n+1 transactions in the L2 block.
    function proposeBlock(bytes[] calldata inputs) external nonReentrant {
        V1Proposing.proposeBlock(state, inputs);
        V1Finalizing.finalizeBlocks(
            state,
            LibConstants.TAIKO_MAX_FINALIZATIONS_PER_TX
        );
    }

    /// @notice Prove a block is valid with a zero-knowledge proof, a transaction
    ///         merkel proof, and a receipt merkel proof.
    /// @param blockIndex The index of the block to prove. This is also used to select
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
    function proveBlock(uint256 blockIndex, bytes[] calldata inputs)
        external
        nonReentrant
    {
        V1Proving.proveBlock(state, AddressResolver(this), blockIndex, inputs);
        V1Finalizing.finalizeBlocks(
            state,
            LibConstants.TAIKO_MAX_FINALIZATIONS_PER_TX
        );
    }

    /// @notice Prove a block is invalid with a zero-knowledge proof and
    ///         a receipt merkel proof
    /// @param blockIndex The index of the block to prove. This is also used to select
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
    function proveBlockInvalid(uint256 blockIndex, bytes[] calldata inputs)
        external
        nonReentrant
    {
        V1Proving.proveBlockInvalid(
            state,
            AddressResolver(this),
            blockIndex,
            inputs
        );
        V1Finalizing.finalizeBlocks(
            state,
            LibConstants.TAIKO_MAX_FINALIZATIONS_PER_TX
        );
    }

    /// @notice Finalize up to N blocks.
    /// @param maxBlocks Max number of blocks to finalize.
    function finalizeBlocks(uint256 maxBlocks) external nonReentrant {
        require(maxBlocks > 0, "L1:maxBlocks");
        V1Finalizing.finalizeBlocks(state, maxBlocks);
    }

    function isCommitValid(bytes32 hash) public view returns (bool) {
        return V1Proposing.isCommitValid(state, hash);
    }

    function getPendingBlock(uint256 id)
        public
        view
        returns (LibData.PendingBlock memory)
    {
        return state.getPendingBlock(id);
    }

    function getL2BlockHash(uint256 id) public view returns (bytes32) {
        return state.getL2BlockHash(id);
    }

    function getStateVariables()
        public
        view
        returns (
            uint64, /*genesisHeight*/
            uint64, /*lastFinalizedHeight*/
            uint64, /*lastFinalizedId*/
            uint64 /*nextPendingId*/
        )
    {
        return state.getStateVariables();
    }

    function signWithGoldFinger(bytes32 hash, uint8 k)
        public
        view
        returns (
            uint8 v,
            uint256 r,
            uint256 s
        )
    {
        return LibAnchorSignature.signTransaction(hash, k);
    }
}
