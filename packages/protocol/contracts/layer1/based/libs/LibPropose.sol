// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ITaikoInbox as I } from "../ITaikoInbox.sol";
import "src/shared/signal/ISignalService.sol";
import "src/shared/libs/LibNetwork.sol";
import "./LibProve.sol";
import "./LibProverAuth.sol";

/// @title LibPropose
/// @custom:security-contact security@taiko.xyz
library LibPropose {
    using SafeERC20 for IERC20;

    struct Input {
        I.Config config;
        address bondToken;
        address inboxWrapper;
        address signalService;
    }

    struct Output {
        uint64 lastAnchorBlockId;
        LibProverAuth.ProverAuth auth;
        I.BatchParams params;
        I.Batch lastBatch;
        I.Stats2 stats2;
        I.BatchInfo info;
        I.BatchMetadata meta;
    }

    function proposeBatch(
        I.State storage $,
        Input memory _input,
        bytes calldata _params,
        bytes calldata _txList,
        bytes calldata /*_additionalData*/
    )
        internal
        returns (Output memory output_)
    {
        output_.stats2 = $.stats2;

        unchecked {
            require(
                output_.stats2.numBatches
                    <= output_.stats2.lastVerifiedBatchId + _input.config.maxUnverifiedBatches,
                I.TooManyBatches()
            );

            output_.params = abi.decode(_params, (I.BatchParams));

            {
                if (_input.inboxWrapper == address(0)) {
                    if (output_.params.proposer == address(0)) {
                        output_.params.proposer = msg.sender;
                    } else {
                        require(output_.params.proposer == msg.sender, I.CustomProposerNotAllowed());
                    }

                    // blob hashes are only accepted if the caller is trusted.
                    require(output_.params.blobParams.blobHashes.length == 0, I.InvalidBlobParams());
                    require(output_.params.blobParams.createdIn == 0, I.InvalidBlobCreatedIn());
                    require(output_.params.isForcedInclusion == false, I.InvalidForcedInclusion());
                } else {
                    require(output_.params.proposer != address(0), I.CustomProposerMissing());
                    require(msg.sender == _input.inboxWrapper, I.NotInboxWrapper());
                }

                // In the upcoming Shasta fork, we might need to enforce the coinbase address as the
                // preconfer address. This will allow us to implement preconfirmation features in L2
                // anchor transactions.
                if (output_.params.coinbase == address(0)) {
                    output_.params.coinbase = output_.params.proposer;
                }

                if (output_.params.revertIfNotFirstProposal) {
                    require(output_.stats2.lastProposedIn != block.number, I.NotFirstProposal());
                }
            }

            if (_txList.length != 0) {
                // calldata is used for data availability
                require(output_.params.blobParams.firstBlobIndex == 0, I.InvalidBlobParams());
                require(output_.params.blobParams.numBlobs == 0, I.InvalidBlobParams());
                require(output_.params.blobParams.createdIn == 0, I.InvalidBlobCreatedIn());
                require(output_.params.blobParams.blobHashes.length == 0, I.InvalidBlobParams());
            } else if (output_.params.blobParams.blobHashes.length == 0) {
                // this is a normal batch, blobs are created and used in the current batches.
                // firstBlobIndex can be non-zero.
                require(output_.params.blobParams.numBlobs != 0, I.BlobNotSpecified());
                require(output_.params.blobParams.createdIn == 0, I.InvalidBlobCreatedIn());
                output_.params.blobParams.createdIn = uint64(block.number);
            } else {
                // this is a forced-inclusion batch, blobs were created in early blocks and are used
                // in the current batches
                require(output_.params.blobParams.createdIn != 0, I.InvalidBlobCreatedIn());
                require(output_.params.blobParams.numBlobs == 0, I.InvalidBlobParams());
                require(output_.params.blobParams.firstBlobIndex == 0, I.InvalidBlobParams());
            }

            // Keep track of last batch's information.
            output_.lastBatch =
                $.batches[(output_.stats2.numBatches - 1) % _input.config.batchRingBufferSize];

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
            {
                uint256 nBlocks = output_.params.blocks.length;

                output_.info = I.BatchInfo({
                    txsHash: bytes32(0), // to be initialised later
                    //
                    // Data to build L2 blocks
                    blocks: output_.params.blocks,
                    blobHashes: new bytes32[](0), // to be initialised later
                    // The client must ensure that the lower 128 bits of the extraData field in the
                    // header of each block in this batch match the specified value.
                    // The upper 128 bits of the extraData field are validated using off-chain
                    // protocol logic.
                    extraData: bytes32(
                        uint256(_encodeExtraDataLower128Bits(_input.config, output_.params))
                    ),
                    coinbase: output_.params.coinbase,
                    proposedIn: uint64(block.number),
                    blobCreatedIn: output_.params.blobParams.createdIn,
                    blobByteOffset: output_.params.blobParams.byteOffset,
                    blobByteSize: output_.params.blobParams.byteSize,
                    gasLimit: _input.config.blockMaxGasLimit,
                    lastBlockId: output_.lastBatch.lastBlockId + uint64(nBlocks),
                    lastBlockTimestamp: _validateBatchParams(
                        output_.params, _input.config, _input.signalService, output_.lastBatch
                    ),
                    // Data for the L2 anchor transaction, shared by all blocks in the batch
                    anchorBlockIds: new uint64[](nBlocks), // to be initialised later
                    anchorBlockHashes: new bytes32[](nBlocks), // to be initialised
                        // later
                    baseFeeConfig: _input.config.baseFeeConfig
                });

                for (uint256 i; i < nBlocks; ++i) {
                    uint64 anchorBlockId = output_.params.blocks[i].anchorBlockId;
                    if (anchorBlockId != 0) {
                        if (output_.lastAnchorBlockId == 0) {
                            // This is the first non zero anchor block id in the batch.
                            require(
                                anchorBlockId + _input.config.maxAnchorHeightOffset >= block.number,
                                I.AnchorIdTooLarge()
                            );

                            require(
                                anchorBlockId > output_.lastBatch.anchorBlockId,
                                I.AnchorIdSmallerOrEqualThanLastBatch()
                            );
                        } else {
                            // anchor block id must be strictly increasing
                            require(
                                anchorBlockId > output_.lastAnchorBlockId,
                                I.AnchorIdSmallerThanParent()
                            );
                        }
                        output_.lastAnchorBlockId = anchorBlockId;

                        output_.info.anchorBlockIds[i] = output_.lastAnchorBlockId;
                        output_.info.anchorBlockHashes[i] = blockhash(anchorBlockId);
                        require(output_.info.anchorBlockHashes[i] != 0, I.ZeroAnchorBlockHash());
                    }
                }

                // Ensure that if msg.sender is not the inboxWrapper, at least one block must have a
                // non-zero anchor block id. Otherwise, delegate this validation to the inboxWrapper
                // contract.
                require(
                    msg.sender == _input.inboxWrapper || output_.lastAnchorBlockId != 0,
                    I.NoAnchorBlockIdWithinThisBatch()
                );

                bytes32 txListHash = keccak256(_txList);
                (output_.info.txsHash, output_.info.blobHashes) =
                    _calculateTxsHash(txListHash, output_.params.blobParams);

                output_.meta = I.BatchMetadata({
                    infoHash: keccak256(abi.encode(output_.info)),
                    proposer: output_.params.proposer,
                    prover: output_.params.proposer,
                    batchId: output_.stats2.numBatches,
                    proposedAt: uint64(block.timestamp),
                    firstBlockId: output_.lastBatch.lastBlockId + 1
                });

                LibProve._checkBatchInForkRange(
                    _input.config, output_.meta.firstBlockId, output_.info.lastBlockId
                );
                if (output_.params.proverAuth.length == 0) {
                    // proposer is the prover
                    LibBonds.debitBond(
                        $, _input.bondToken, output_.meta.prover, _input.config.livenessBond
                    );
                } else {
                    {
                        bytes memory proverAuth = output_.params.proverAuth;
                        // Circular dependency so zero it out. (BatchParams has proverAuth but
                        // proverAuth has also batchParamsHash)
                        output_.params.proverAuth = "";

                        // Outsource the prover authentication to the LibProverAuth library to
                        // reduce
                        // this contract's code size.
                        output_.auth = LibProverAuth.validateProverAuth(
                            _input.config.chainId,
                            output_.stats2.numBatches,
                            keccak256(abi.encode(output_.params)),
                            txListHash,
                            proverAuth
                        );
                    }

                    output_.meta.prover = output_.auth.prover;

                    if (output_.auth.feeToken == _input.bondToken) {
                        // proposer pay the prover fee with bond tokens
                        LibBonds.debitBond(
                            $, _input.bondToken, output_.meta.proposer, output_.auth.fee
                        );

                        // if bondDelta is negative (proverFee < livenessBond), deduct the diff
                        // if not then add the diff to the bond balance
                        int256 bondDelta =
                            int96(output_.auth.fee) - int96(_input.config.livenessBond);

                        if (bondDelta < 0) {
                            LibBonds.debitBond(
                                $, _input.bondToken, output_.meta.prover, uint256(-bondDelta)
                            );
                        } else {
                            LibBonds.creditBond($, output_.meta.prover, uint256(bondDelta));
                        }
                    } else {
                        LibBonds.debitBond(
                            $, _input.bondToken, output_.meta.prover, _input.config.livenessBond
                        );

                        if (output_.meta.proposer != output_.meta.prover) {
                            IERC20(output_.auth.feeToken).safeTransferFrom(
                                output_.meta.proposer, output_.meta.prover, output_.auth.fee
                            );
                        }
                    }
                }
            }

            LibBonds.debitBond(
                $, _input.bondToken, output_.meta.proposer, _input.config.provabilityBond
            );

            {
                I.Batch storage batch =
                    $.batches[output_.stats2.numBatches % _input.config.batchRingBufferSize];

                // SSTORE #1
                batch.metaHash = keccak256(abi.encode(output_.meta));

                // SSTORE #2 {{
                batch.batchId = output_.stats2.numBatches;
                batch.lastBlockTimestamp = output_.info.lastBlockTimestamp;
                batch.anchorBlockId = output_.lastAnchorBlockId;
                batch.nextTransitionId = 1;
                batch.verifiedTransitionId = 0;
                batch.reserved4 = 0;
                // SSTORE }}

                // SSTORE #3 {{
                batch.lastBlockId = output_.info.lastBlockId;
                batch.provabilityBond = _input.config.provabilityBond;
                batch.livenessBond = _input.config.livenessBond;
                // SSTORE }}
            }

            output_.stats2.numBatches += 1;
            output_.stats2.lastProposedIn = uint56(block.number);

            emit I.BatchProposed(output_.info, output_.meta, _txList);
        } // end-of-unchecked
    }

    function _validateBatchParams(
        I.BatchParams memory _params,
        I.Config memory _config,
        address _signalService,
        I.Batch memory _lastBatch
    )
        private
        view
        returns (uint64 lastBlockTimestamp_)
    {
        uint256 nBlocks = _params.blocks.length;
        require(nBlocks != 0, I.BlockNotFound());
        require(nBlocks <= _config.maxBlocksPerBatch, I.TooManyBlocks());

        unchecked {
            lastBlockTimestamp_ = _params.lastBlockTimestamp == 0
                ? uint64(block.timestamp)
                : _params.lastBlockTimestamp;

            require(lastBlockTimestamp_ <= block.timestamp, I.TimestampTooLarge());
            require(_params.blocks[0].timeShift == 0, I.FirstBlockTimeShiftNotZero());

            uint64 totalShift;

            for (uint256 i; i < nBlocks; ++i) {
                I.BlockParams memory blockParams = _params.blocks[i];
                totalShift += blockParams.timeShift;

                uint256 numSignals = blockParams.signalSlots.length;
                if (numSignals == 0) continue;

                require(numSignals <= _config.maxSignalsToReceive, I.TooManySignals());

                for (uint256 j; j < numSignals; ++j) {
                    require(
                        ISignalService(_signalService).isSignalSent(blockParams.signalSlots[j]),
                        I.SignalNotSent()
                    );
                }
            }

            require(lastBlockTimestamp_ >= totalShift, I.TimestampTooSmall());

            uint64 firstBlockTimestamp = lastBlockTimestamp_ - totalShift;

            require(
                firstBlockTimestamp + _config.maxAnchorHeightOffset * LibNetwork.ETHEREUM_BLOCK_TIME
                    >= block.timestamp,
                I.TimestampTooSmall()
            );

            require(
                firstBlockTimestamp >= _lastBatch.lastBlockTimestamp, I.TimestampSmallerThanParent()
            );

            // make sure the batch builds on the expected latest chain state.
            require(
                _params.parentMetaHash == 0 || _params.parentMetaHash == _lastBatch.metaHash,
                I.ParentMetaHashMismatch()
            );
        }
    }

    function _calculateTxsHash(
        bytes32 _txListHash,
        I.BlobParams memory _blobParams
    )
        internal
        view
        returns (bytes32 hash_, bytes32[] memory blobHashes_)
    {
        if (_blobParams.blobHashes.length != 0) {
            blobHashes_ = _blobParams.blobHashes;
        } else {
            blobHashes_ = new bytes32[](_blobParams.numBlobs);
            for (uint256 i; i < _blobParams.numBlobs; ++i) {
                unchecked {
                    blobHashes_[i] = blobhash(_blobParams.firstBlobIndex + i);
                }
            }
        }

        for (uint256 i; i < blobHashes_.length; ++i) {
            require(blobHashes_[i] != 0, I.BlobNotFound());
        }
        hash_ = keccak256(abi.encode(_txListHash, blobHashes_));
    }

    /// @dev The function _encodeExtraDataLower128Bits encodes certain information into a uint128
    /// - bits 0-7: used to store _config.baseFeeConfig.sharingPctg.
    /// - bit 8: used to store _batchParams.isForcedInclusion.
    function _encodeExtraDataLower128Bits(
        I.Config memory _config,
        I.BatchParams memory _batchParams
    )
        private
        pure
        returns (uint128 encoded_)
    {
        encoded_ |= _config.baseFeeConfig.sharingPctg; // bits 0-7
        encoded_ |= _batchParams.isForcedInclusion ? 1 << 8 : 0; // bit 8
    }
}
