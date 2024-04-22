// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../common/IAddressResolver.sol";
import "../../common/LibStrings.sol";
import "../../libs/LibAddress.sol";
import "../../libs/LibNetwork.sol";
import "../hooks/IHook.sol";
import "../tiers/ITierProvider.sol";

/// @title LibProposing
/// @notice A library for handling block proposals in the Taiko protocol.
/// @custom:security-contact security@taiko.xyz
library LibProposing {
    using LibAddress for address;

    // = keccak256(abi.encode(new TaikoData.EthDeposit[](0)))
    bytes32 private constant _EMPTY_ETH_DEPOSIT_HASH =
        0x569e75fc77c1a856f6daaf9e69d8a9566ca34aa47f9133711ce065a571af0cfd;

    // Warning: Any events defined here must also be defined in TaikoEvents.sol.
    /// @notice Emitted when a block is proposed.
    /// @param blockId The ID of the proposed block.
    /// @param assignedProver The address of the assigned prover.
    /// @param livenessBond The liveness bond of the proposed block.
    /// @param meta The metadata of the proposed block.
    /// @param depositsProcessed The EthDeposit array about processed deposits in this proposed
    /// block.
    event BlockProposed(
        uint256 indexed blockId,
        address indexed assignedProver,
        uint96 livenessBond,
        TaikoData.BlockMetadata meta,
        TaikoData.EthDeposit[] depositsProcessed
    );

    // Warning: Any errors defined here must also be defined in TaikoErrors.sol.
    error L1_BLOB_NOT_AVAILABLE();
    error L1_BLOB_NOT_FOUND();
    error L1_INVALID_HOOK();
    error L1_INVALID_PROVER();
    error L1_INVALID_SIG();
    error L1_LIVENESS_BOND_NOT_RECEIVED();
    error L1_TOO_MANY_BLOCKS();
    error L1_UNAUTHORIZED();
    error L1_UNEXPECTED_PARENT();

    /// @dev Proposes a Taiko L2 block.
    /// @param _state Current TaikoData.State.
    /// @param _config Actual TaikoData.Config.
    /// @param _resolver Address resolver interface.
    /// @param _data Encoded data bytes containing the block params.
    /// @param _txList Transaction list bytes (if not blob).
    /// @return meta_ The constructed block's metadata.
    function proposeBlock(
        TaikoData.State storage _state,
        TaikoData.Config memory _config,
        IAddressResolver _resolver,
        bytes calldata _data,
        bytes calldata _txList,
        bool _checkEOAForCalldataDA
    )
        internal
        returns (TaikoData.BlockMetadata memory meta_, TaikoData.EthDeposit[] memory deposits_)
    {
        TaikoData.BlockParams memory params = abi.decode(_data, (TaikoData.BlockParams));

        // We need a prover that will submit proofs after the block has been submitted
        if (params.assignedProver == address(0)) {
            revert L1_INVALID_PROVER();
        }

        if (params.coinbase == address(0)) {
            params.coinbase = msg.sender;
        }

        // Taiko, as a Based Rollup, enables permissionless block proposals.
        // However, if the "proposer" address is set to a non-zero value, we
        // ensure that only that specific address has the authority to propose
        // blocks.
        TaikoData.SlotB memory b = _state.slotB;
        if (!_isProposerPermitted(b, _resolver)) revert L1_UNAUTHORIZED();

        // It's essential to ensure that the ring buffer for proposed blocks
        // still has space for at least one more block.
        if (b.numBlocks >= b.lastVerifiedBlockId + _config.blockMaxProposals + 1) {
            revert L1_TOO_MANY_BLOCKS();
        }

        bytes32 parentMetaHash =
            _state.blocks[(b.numBlocks - 1) % _config.blockRingBufferSize].metaHash;
        // assert(parentMetaHash != 0);

        // Check if parent block has the right meta hash. This is to allow the proposer to make sure
        // the block builds on the expected latest chain state.
        if (params.parentMetaHash != 0 && parentMetaHash != params.parentMetaHash) {
            revert L1_UNEXPECTED_PARENT();
        }

        // Initialize metadata to compute a metaHash, which forms a part of
        // the block data to be stored on-chain for future integrity checks.
        // If we choose to persist all data fields in the metadata, it will
        // require additional storage slots.
        unchecked {
            meta_ = TaikoData.BlockMetadata({
                l1Hash: blockhash(block.number - 1),
                difficulty: 0, // to be initialized below
                blobHash: 0, // to be initialized below
                extraData: params.extraData,
                depositsHash: _EMPTY_ETH_DEPOSIT_HASH,
                coinbase: params.coinbase,
                id: b.numBlocks,
                gasLimit: _config.blockMaxGasLimit,
                timestamp: uint64(block.timestamp),
                l1Height: uint64(block.number - 1),
                minTier: 0, // to be initialized below
                blobUsed: _txList.length == 0,
                parentMetaHash: parentMetaHash,
                sender: msg.sender
            });
        }

        // Update certain meta fields
        if (meta_.blobUsed) {
            if (!LibNetwork.isDencunSupported(block.chainid)) revert L1_BLOB_NOT_AVAILABLE();

            // Always use the first blob in this transaction. If the
            // proposeBlock functions are called more than once in the same
            // L1 transaction, these multiple L2 blocks will share the same
            // blob.
            meta_.blobHash = blobhash(0);
            if (meta_.blobHash == 0) revert L1_BLOB_NOT_FOUND();
        } else {
            meta_.blobHash = keccak256(_txList);

            // This function must be called as the outmost transaction (not an internal one) for
            // the node to extract the calldata easily.
            // We cannot rely on `msg.sender != tx.origin` for EOA check, as it will break after EIP
            // 7645: Alias ORIGIN to SENDER
            if (
                _checkEOAForCalldataDA
                    && ECDSA.recover(meta_.blobHash, params.signature) != msg.sender
            ) {
                revert L1_INVALID_SIG();
            }
        }

        // Following the Merge, the L1 mixHash incorporates the
        // prevrandao value from the beacon chain. Given the possibility
        // of multiple Taiko blocks being proposed within a single
        // Ethereum block, we choose to introduce a salt to this random
        // number as the L2 mixHash.
        meta_.difficulty = keccak256(abi.encodePacked(block.prevrandao, b.numBlocks, block.number));

        // Use the difficulty as a random number
        meta_.minTier = ITierProvider(_resolver.resolve(LibStrings.B_TIER_PROVIDER, false))
            .getMinTier(uint256(meta_.difficulty));

        // Create the block that will be stored onchain
        TaikoData.Block memory blk = TaikoData.Block({
            metaHash: keccak256(abi.encode(meta_)),
            // Safeguard the liveness bond to ensure its preservation,
            // particularly in scenarios where it might be altered after the
            // block's proposal but before it has been proven or verified.
            livenessBond: _config.livenessBond,
            blockId: b.numBlocks,
            proposedAt: meta_.timestamp,
            proposedIn: uint64(block.number),
            // For a new block, the next transition ID is always 1, not 0.
            nextTransitionId: 1,
            // For unverified block, its verifiedTransitionId is always 0.
            verifiedTransitionId: 0,
            assignedProver: params.assignedProver
        });

        // Store the block in the ring buffer
        _state.blocks[b.numBlocks % _config.blockRingBufferSize] = blk;

        // Increment the counter (cursor) by 1.
        unchecked {
            ++_state.slotB.numBlocks;
        }

        {
            IERC20 tko = IERC20(_resolver.resolve(LibStrings.B_TAIKO_TOKEN, false));
            uint256 tkoBalance = tko.balanceOf(address(this));

            // Run all hooks.
            // Note that address(this).balance has been updated with msg.value,
            // prior to any code in this function has been executed.
            address prevHook;
            for (uint256 i; i < params.hookCalls.length; ++i) {
                if (uint160(prevHook) >= uint160(params.hookCalls[i].hook)) {
                    revert L1_INVALID_HOOK();
                }

                // When a hook is called, all ether in this contract will be sent to the hook.
                // If the ether sent to the hook is not used entirely, the hook shall send the Ether
                // back to this contract for the next hook to use.
                // Proposers shall choose to use extra hooks wisely.
                IHook(params.hookCalls[i].hook).onBlockProposed{ value: address(this).balance }(
                    blk, meta_, params.hookCalls[i].data
                );

                prevHook = params.hookCalls[i].hook;
            }
            // Refund Ether
            if (address(this).balance != 0) {
                msg.sender.sendEtherAndVerify(address(this).balance);
            }

            // Check that after hooks, the Taiko Token balance of this contract
            // have increased by the same amount as _config.livenessBond (to prevent)
            // multiple draining payments by a malicious proposer nesting the same
            // hook.
            if (tko.balanceOf(address(this)) != tkoBalance + _config.livenessBond) {
                revert L1_LIVENESS_BOND_NOT_RECEIVED();
            }
        }

        deposits_ = new TaikoData.EthDeposit[](0);
        emit BlockProposed({
            blockId: blk.blockId,
            assignedProver: blk.assignedProver,
            livenessBond: _config.livenessBond,
            meta: meta_,
            depositsProcessed: deposits_
        });
    }

    function _isProposerPermitted(
        TaikoData.SlotB memory _slotB,
        IAddressResolver _resolver
    )
        private
        view
        returns (bool)
    {
        if (_slotB.numBlocks == 1) {
            // Only proposer_one can propose the first block after genesis
            address proposerOne = _resolver.resolve(LibStrings.B_PROPOSER_ONE, true);
            if (proposerOne != address(0)) {
                return msg.sender == proposerOne;
            }
        }

        address proposer = _resolver.resolve(LibStrings.B_PROPOSER, true);
        return proposer == address(0) || msg.sender == proposer;
    }
}
