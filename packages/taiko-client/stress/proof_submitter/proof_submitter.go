package submitter

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/cenkalti/backoff/v4"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/metrics"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	proofProducer "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_producer"
)

var (
	_                    Submitter = (*ProofSubmitter)(nil)
	proofPollingInterval           = 10 * time.Second
	ProofTimeout                   = 3 * time.Hour
)

type Proof struct {
	*proofProducer.ProofWithHeader
	BeginAt time.Time
	EndAt   time.Time
	Timeout bool
}

// ProofSubmitter is responsible requesting proofs for the given L2
// blocks, and submitting the generated proofs to the TaikoL1 smart contract.
type ProofSubmitter struct {
	rpc              *rpc.Client
	proofProducer    proofProducer.ProofProducer
	resultCh         chan *Proof
	proverSetAddress common.Address
	taikoL2Address   common.Address
	graffiti         [32]byte
}

// NewProofSubmitter creates a new ProofSubmitter instance.
func NewProofSubmitter(
	rpcClient *rpc.Client,
	proofProducer proofProducer.ProofProducer,
	resultCh chan *Proof,
	proverSetAddress common.Address,
	taikoL2Address common.Address,
	graffiti string,
) (*ProofSubmitter, error) {

	return &ProofSubmitter{
		rpc:              rpcClient,
		proofProducer:    proofProducer,
		resultCh:         resultCh,
		proverSetAddress: proverSetAddress,
		taikoL2Address:   taikoL2Address,
		graffiti:         rpc.StringToBytes32(graffiti),
	}, nil
}

// RequestProof implements the Submitter interface.
func (s *ProofSubmitter) RequestProof(ctx context.Context, meta metadata.TaikoBlockMetaData) error {
	var (
		blockInfo bindings.TaikoDataBlockV2
	)

	header, err := s.rpc.WaitL2Header(ctx, meta.GetBlockID())
	if err != nil {
		return fmt.Errorf("failed to fetch l2 Header, blockID: %d, error: %w", meta.GetBlockID(), err)
	}

	if header.TxHash == types.EmptyTxsHash {
		return errors.New("no transaction in block")
	}

	parent, err := s.rpc.L2.BlockByHash(ctx, header.ParentHash)
	if err != nil {
		return fmt.Errorf("failed to get the L2 parent block by hash (%s): %w", header.ParentHash, err)
	}

	if meta.IsOntakeBlock() {
		blockInfo, err = s.rpc.GetL2BlockInfoV2(ctx, meta.GetBlockID())
	} else {
		blockInfo, err = s.rpc.GetL2BlockInfo(ctx, meta.GetBlockID())
	}
	if err != nil {
		return err
	}

	// Request proof.
	opts := &proofProducer.ProofRequestOptions{
		BlockID:            header.Number,
		ProverAddress:      s.proverSetAddress,
		ProposeBlockTxHash: meta.GetTxHash(),
		TaikoL2:            s.taikoL2Address,
		MetaHash:           blockInfo.MetaHash,
		BlockHash:          header.Hash(),
		ParentHash:         header.ParentHash,
		StateRoot:          header.Root,
		EventL1Hash:        meta.GetRawBlockHash(),
		Graffiti:           common.Bytes2Hex(s.graffiti[:]),
		GasUsed:            header.GasUsed,
		ParentGasUsed:      parent.GasUsed(),
	}

	startTime := time.Now()
	timeout := false

	// Send the generated proof.
	if err := backoff.Retry(
		func() error {
			if ctx.Err() != nil {
				log.Error("Failed to request proof, context is canceled", "blockID", opts.BlockID, "error", ctx.Err())
				return nil
			}

			result, err := s.proofProducer.RequestProof(
				ctx,
				opts,
				meta.GetBlockID(),
				meta,
				header,
				startTime,
			)
			if err != nil {
				// If request proof has timed out in retry, let's cancel the proof generating and skip
				if errors.Is(err, proofProducer.ErrProofInProgress) && time.Since(startTime) >= ProofTimeout {
					log.Error("Request proof has timed out, start to cancel", "blockID", opts.BlockID)
					if cancelErr := s.proofProducer.RequestCancel(ctx, opts); cancelErr != nil {
						log.Error("Failed to request cancellation of proof", "err", cancelErr)
					}
					timeout = true
				} else {
					// retry
					return fmt.Errorf("failed to request proof (id: %d): %w", meta.GetBlockID(), err)
				}
			}
			s.resultCh <- &Proof{
				ProofWithHeader: result,
				BeginAt:         startTime,
				EndAt:           time.Now(),
				Timeout:         timeout,
			}
			metrics.ProverQueuedProofCounter.Add(1)
			return nil
		},
		backoff.WithContext(backoff.NewConstantBackOff(proofPollingInterval), ctx),
	); err != nil {
		log.Error("Request proof error", "error", err)
		return err
	}

	return nil
}

// Producer returns the inner proof producer.
func (s *ProofSubmitter) Producer() proofProducer.ProofProducer {
	return s.proofProducer
}

// Tier returns the proof tier of the current proof submitter.
func (s *ProofSubmitter) Tier() uint16 {
	return s.proofProducer.Tier()
}
