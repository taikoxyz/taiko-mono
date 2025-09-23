// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "src/shared/libs/LibAddress.sol";
import "src/shared/libs/LibMath.sol";
import "src/shared/libs/LibNetwork.sol";
import "src/shared/signal/ISignalService.sol";
import "./ITaikoInbox.sol";
import "./LibBonds.sol";

/// @title LibProposing
/// @notice This library is used to propose batches
/// @dev This library's propose function is made public to reduce TaikoInbox's code size.
/// @custom:security-contact security@nethermind.io
library LibProposing {
    using LibMath for uint256;
    using SafeERC20 for IERC20;

    /// @notice Struct containing parameters for batch proposal
    struct LibProposeBatchParams {
        ITaikoInbox.Config config;
        ITaikoInbox.BatchParams params;
        address bondToken;
        ISignalService signalService;
        address inboxWrapper;
    }

    /// @notice Proposes batches and returns the batch info and metadata
    /// @param _state The TaikoInbox state
    /// @param _proposeBatchParams The proposal parameters struct
    /// @param _txList The transaction list
    /// @return info_ The batch info
    /// @return meta_ The batch metadata
    /// @return stats2_ The updated stats2
    function proposeBatches(
        ITaikoInbox.State storage _state,
        LibProposeBatchParams memory _proposeBatchParams,
        bytes calldata _txList
    )
        public
        returns (
            ITaikoInbox.BatchInfo memory info_,
            ITaikoInbox.BatchMetadata memory meta_,
            ITaikoInbox.Stats2 memory stats2_
        )
    {
        stats2_ = _state.stats2;
        require(
            stats2_.numBatches >= _proposeBatchParams.config.forkHeights.pacaya,
            ITaikoInbox.ForkNotActivated()
        );

        unchecked {
            require(
                stats2_.numBatches
                    <= stats2_.lastVerifiedBatchId + _proposeBatchParams.config.maxUnverifiedBatches,
                ITaikoInbox.TooManyBatches()
            );

            {
                if (_proposeBatchParams.inboxWrapper == address(0)) {
                    require(
                        _proposeBatchParams.params.proposer == address(0),
                        ITaikoInbox.CustomProposerNotAllowed()
                    );
                    _proposeBatchParams.params.proposer = msg.sender;

                    // blob hashes are only accepted if the caller is trusted.
                    require(
                        _proposeBatchParams.params.blobParams.blobHashes.length == 0,
                        ITaikoInbox.InvalidBlobParams()
                    );
                    require(
                        _proposeBatchParams.params.blobParams.createdIn == 0,
                        ITaikoInbox.InvalidBlobCreatedIn()
                    );
                } else {
                    require(
                        _proposeBatchParams.params.proposer != address(0),
                        ITaikoInbox.CustomProposerMissing()
                    );
                    require(
                        msg.sender == _proposeBatchParams.inboxWrapper,
                        ITaikoInbox.NotInboxWrapper()
                    );
                }

                // In the upcoming Shasta fork, we might need to enforce the coinbase address as the
                // preconfer address. This will allow us to implement preconfirmation features in L2
                // anchor transactions.
                if (_proposeBatchParams.params.coinbase == address(0)) {
                    _proposeBatchParams.params.coinbase = _proposeBatchParams.params.proposer;
                }

                if (_proposeBatchParams.params.revertIfNotFirstProposal) {
                    require(
                        _state.stats2.lastProposedIn != block.number, ITaikoInbox.NotFirstProposal()
                    );
                }
            }

            {
                bool calldataUsed = _txList.length != 0;

                if (calldataUsed) {
                    // calldata is used for data availability
                    require(
                        _proposeBatchParams.params.blobParams.firstBlobIndex == 0,
                        ITaikoInbox.InvalidBlobParams()
                    );
                    require(
                        _proposeBatchParams.params.blobParams.numBlobs == 0,
                        ITaikoInbox.InvalidBlobParams()
                    );
                    require(
                        _proposeBatchParams.params.blobParams.createdIn == 0,
                        ITaikoInbox.InvalidBlobCreatedIn()
                    );
                    require(
                        _proposeBatchParams.params.blobParams.blobHashes.length == 0,
                        ITaikoInbox.InvalidBlobParams()
                    );
                } else if (_proposeBatchParams.params.blobParams.blobHashes.length == 0) {
                    // this is a normal batch, blobs are created and used in the current batches.
                    // firstBlobIndex can be non-zero.
                    require(
                        _proposeBatchParams.params.blobParams.numBlobs != 0,
                        ITaikoInbox.BlobNotSpecified()
                    );
                    require(
                        _proposeBatchParams.params.blobParams.createdIn == 0,
                        ITaikoInbox.InvalidBlobCreatedIn()
                    );
                    _proposeBatchParams.params.blobParams.createdIn = uint64(block.number);
                } else {
                    // this is a forced-inclusion batch, blobs were created in early blocks and are
                    // used
                    // in the current batches
                    require(
                        _proposeBatchParams.params.blobParams.createdIn != 0,
                        ITaikoInbox.InvalidBlobCreatedIn()
                    );
                    require(
                        _proposeBatchParams.params.blobParams.numBlobs == 0,
                        ITaikoInbox.InvalidBlobParams()
                    );
                    require(
                        _proposeBatchParams.params.blobParams.firstBlobIndex == 0,
                        ITaikoInbox.InvalidBlobParams()
                    );
                }
            }

            // Keep track of last batch's information.
            ITaikoInbox.Batch storage lastBatch = _state.batches[(stats2_.numBatches - 1)
                % _proposeBatchParams.config.batchRingBufferSize];

            (uint64 anchorBlockId, uint64 lastBlockTimestamp) = _validateBatchParams(
                _proposeBatchParams.params,
                _proposeBatchParams.config.maxAnchorHeightOffset,
                _proposeBatchParams.config.maxSignalsToReceive,
                _proposeBatchParams.config.maxBlocksPerBatch,
                lastBatch,
                _proposeBatchParams.signalService
            );

            // This section constructs the metadata for the proposed batch, which is crucial for
            // nodes/clients to process the batch. The metadata itself is not stored on-chain;
            // instead, only its hash is kept.
            // The metadata must be supplied as calldata prior to proving the batch, enabling the
            // computation and verification of its integrity through the comparison of the metahash.
            //
            // Note that `difficulty` has been removed from the metadata. The client and prover must
            // use
            // the following approach to calculate a block's difficulty:
            //  `keccak256(abi.encode("TAIKO_DIFFICULTY", block.number))`
            info_ = ITaikoInbox.BatchInfo({
                txsHash: bytes32(0), // to be initialised later
                //
                // Data to build L2 blocks
                blocks: _proposeBatchParams.params.blocks,
                blobHashes: new bytes32[](0), // to be initialised later
                extraData: bytes32(uint256(_proposeBatchParams.config.baseFeeConfig.sharingPctg)),
                coinbase: _proposeBatchParams.params.coinbase,
                proposedIn: uint64(block.number),
                blobCreatedIn: _proposeBatchParams.params.blobParams.createdIn,
                blobByteOffset: _proposeBatchParams.params.blobParams.byteOffset,
                blobByteSize: _proposeBatchParams.params.blobParams.byteSize,
                gasLimit: _proposeBatchParams.config.blockMaxGasLimit,
                // Surge: custom L2 basefee set by the proposer
                baseFee: _proposeBatchParams.params.baseFee,
                lastBlockId: 0, // to be initialised later
                lastBlockTimestamp: lastBlockTimestamp,
                //
                // Data for the L2 anchor transaction, shared by all blocks in the batch
                anchorBlockId: anchorBlockId,
                anchorBlockHash: blockhash(anchorBlockId),
                baseFeeConfig: _proposeBatchParams.config.baseFeeConfig
            });

            require(info_.anchorBlockHash != 0, ITaikoInbox.ZeroAnchorBlockHash());

            info_.lastBlockId = stats2_.numBatches == _proposeBatchParams.config.forkHeights.pacaya
                ? stats2_.numBatches + uint64(_proposeBatchParams.params.blocks.length) - 1
                : lastBatch.lastBlockId + uint64(_proposeBatchParams.params.blocks.length);

            (info_.txsHash, info_.blobHashes) =
                _calculateTxsHash(keccak256(_txList), _proposeBatchParams.params.blobParams);

            meta_ = ITaikoInbox.BatchMetadata({
                infoHash: keccak256(abi.encode(info_)),
                proposer: _proposeBatchParams.params.proposer,
                batchId: stats2_.numBatches,
                proposedAt: uint64(block.timestamp)
            });

            ITaikoInbox.Batch storage batch =
                _state.batches[stats2_.numBatches % _proposeBatchParams.config.batchRingBufferSize];

            // SSTORE #1
            batch.metaHash = keccak256(abi.encode(meta_));

            // SSTORE #2 {{
            batch.batchId = stats2_.numBatches;
            batch.lastBlockTimestamp = lastBlockTimestamp;
            batch.anchorBlockId = anchorBlockId;
            batch.nextTransitionId = 1;
            batch.verifiedTransitionId = 0;
            batch.finalisingTransitionIndex = 0;
            // SSTORE }}

            LibBonds.debitBond(
                _state,
                _proposeBatchParams.params.proposer,
                _proposeBatchParams.config.livenessBondBase,
                _proposeBatchParams.bondToken
            );

            // SSTORE #3 {{
            batch.lastBlockId = info_.lastBlockId;
            batch.reserved3 = 0;
            batch.livenessBond = _proposeBatchParams.config.livenessBondBase;
            // SSTORE }}

            stats2_.numBatches += 1;
            require(
                _proposeBatchParams.config.forkHeights.shasta == 0
                    || stats2_.numBatches < _proposeBatchParams.config.forkHeights.shasta,
                ITaikoInbox.BeyondCurrentFork()
            );
            stats2_.lastProposedIn = uint56(block.number);

            emit ITaikoInbox.BatchProposed(info_, meta_, _txList);
        } // end-of-unchecked
    }

    function _calculateTxsHash(
        bytes32 _txListHash,
        ITaikoInbox.BlobParams memory _blobParams
    )
        internal
        view
        returns (bytes32 hash_, bytes32[] memory blobHashes_)
    {
        if (_blobParams.blobHashes.length != 0) {
            blobHashes_ = _blobParams.blobHashes;
        } else {
            uint256 numBlobs = _blobParams.numBlobs;
            blobHashes_ = new bytes32[](numBlobs);
            for (uint256 i; i < numBlobs; ++i) {
                unchecked {
                    blobHashes_[i] = blobhash(_blobParams.firstBlobIndex + i);
                }
            }
        }

        uint256 bloblHashesLength = blobHashes_.length;
        for (uint256 i; i < bloblHashesLength; ++i) {
            require(blobHashes_[i] != 0, ITaikoInbox.BlobNotFound());
        }
        hash_ = keccak256(abi.encode(_txListHash, blobHashes_));
    }

    // Bond-related functions have been moved to LibBonds.sol

    function _validateBatchParams(
        ITaikoInbox.BatchParams memory _params,
        uint64 _maxAnchorHeightOffset,
        uint8 _maxSignalsToReceive,
        uint16 _maxBlocksPerBatch,
        ITaikoInbox.Batch memory _lastBatch,
        ISignalService _signalService
    )
        internal
        view
        returns (uint64 anchorBlockId_, uint64 lastBlockTimestamp_)
    {
        uint256 blocksLength = _params.blocks.length;
        require(blocksLength != 0, ITaikoInbox.BlockNotFound());
        require(blocksLength <= _maxBlocksPerBatch, ITaikoInbox.TooManyBlocks());

        unchecked {
            if (_params.anchorBlockId == 0) {
                anchorBlockId_ = uint64(block.number - 1);
            } else {
                require(
                    _params.anchorBlockId + _maxAnchorHeightOffset >= block.number,
                    ITaikoInbox.AnchorBlockIdTooSmall()
                );
                require(_params.anchorBlockId < block.number, ITaikoInbox.AnchorBlockIdTooLarge());
                require(
                    _params.anchorBlockId >= _lastBatch.anchorBlockId,
                    ITaikoInbox.AnchorBlockIdSmallerThanParent()
                );
                anchorBlockId_ = _params.anchorBlockId;
            }

            lastBlockTimestamp_ = _params.lastBlockTimestamp == 0
                ? uint64(block.timestamp)
                : _params.lastBlockTimestamp;

            require(lastBlockTimestamp_ <= block.timestamp, ITaikoInbox.TimestampTooLarge());
            require(_params.blocks[0].timeShift == 0, ITaikoInbox.FirstBlockTimeShiftNotZero());

            uint64 totalShift;

            for (uint256 i; i < blocksLength; ++i) {
                totalShift += _params.blocks[i].timeShift;

                uint256 numSignals = _params.blocks[i].signalSlots.length;
                if (numSignals == 0) continue;

                require(numSignals <= _maxSignalsToReceive, ITaikoInbox.TooManySignals());

                for (uint256 j; j < numSignals; ++j) {
                    require(
                        _signalService.isSignalSent(_params.blocks[i].signalSlots[j]),
                        ITaikoInbox.SignalNotSent()
                    );
                }
            }

            require(lastBlockTimestamp_ >= totalShift, ITaikoInbox.TimestampTooSmall());

            uint64 firstBlockTimestamp = lastBlockTimestamp_ - totalShift;

            require(
                firstBlockTimestamp + _maxAnchorHeightOffset * LibNetwork.ETHEREUM_BLOCK_TIME
                    >= block.timestamp,
                ITaikoInbox.TimestampTooSmall()
            );

            require(
                firstBlockTimestamp >= _lastBatch.lastBlockTimestamp,
                ITaikoInbox.TimestampSmallerThanParent()
            );

            // make sure the batch builds on the expected latest chain state.
            require(
                _params.parentMetaHash == 0 || _params.parentMetaHash == _lastBatch.metaHash,
                ITaikoInbox.ParentMetaHashMismatch()
            );
        }
    }
}
