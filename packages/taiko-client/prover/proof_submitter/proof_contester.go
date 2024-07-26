package submitter

import (
	"context"
	"math/big"
	"strings"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	proofProducer "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_producer"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_submitter/transaction"
)

var _ Contester = (*ProofContester)(nil)

// ProofContester is responsible for contesting wrong L2 transitions.
type ProofContester struct {
	rpc       *rpc.Client
	txBuilder *transaction.ProveBlockTxBuilder
	sender    *transaction.Sender
	graffiti  [32]byte
}

// NewProofContester creates a new ProofContester instance.
func NewProofContester(
	rpcClient *rpc.Client,
	gasLimit uint64,
	txmgr *txmgr.SimpleTxManager,
	proverSetAddress common.Address,
	graffiti string,
	builder *transaction.ProveBlockTxBuilder,
) *ProofContester {
	return &ProofContester{
		rpc:       rpcClient,
		txBuilder: builder,
		sender:    transaction.NewSender(rpcClient, txmgr, proverSetAddress, gasLimit),
		graffiti:  rpc.StringToBytes32(graffiti),
	}
}

// SubmitContest submits a TaikoL1.proveBlock transaction to contest a L2 block transition.
func (c *ProofContester) SubmitContest(
	ctx context.Context,
	blockID *big.Int,
	proposedIn *big.Int,
	parentHash common.Hash,
	meta metadata.TaikoBlockMetaData,
	tier uint16,
) error {
	// Ensure the transition has not been contested yet.
	transition, err := c.rpc.TaikoL1.GetTransition0(
		&bind.CallOpts{Context: ctx},
		blockID.Uint64(),
		parentHash,
	)
	if err != nil {
		if !strings.Contains(encoding.TryParsingCustomError(err).Error(), "L1_") {
			log.Warn(
				"Failed to get transition",
				"blockID", blockID,
				"parentHash", parentHash,
				"error", encoding.TryParsingCustomError(err),
			)
			return nil
		}
		return err
	}
	// If the transition has already been contested, return early.
	if transition.Contester != (common.Address{}) {
		log.Info(
			"Transition has already been contested",
			"blockID", blockID,
			"parentHash", parentHash,
			"contester", transition.Contester,
		)
		return nil
	}

	// Send the contest transaction.
	header, err := c.rpc.L2.HeaderByNumber(ctx, blockID)
	if err != nil {
		return err
	}

	l1HeaderProposedIn, err := c.rpc.L1.HeaderByNumber(ctx, proposedIn)
	if err != nil {
		return err
	}

	return c.sender.Send(
		ctx,
		&proofProducer.ProofWithHeader{
			BlockID: blockID,
			Meta:    meta,
			Header:  header,
			Proof:   []byte{},
			Opts: &proofProducer.ProofRequestOptions{
				EventL1Hash: l1HeaderProposedIn.Hash(),
				StateRoot:   header.Root,
			},
			Tier: tier,
		},
		c.txBuilder.Build(
			blockID,
			meta,
			&bindings.TaikoDataTransition{
				ParentHash: header.ParentHash,
				BlockHash:  header.Hash(),
				StateRoot:  header.Root,
				Graffiti:   c.graffiti,
			},
			&bindings.TaikoDataTierProof{
				Tier: transition.Tier,
				Data: []byte{},
			},
			tier,
		),
	)
}
