package rpc

import (
	"context"
	"errors"
	"math/big"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/log"
	"github.com/ethereum/go-ethereum/params"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	pacayaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/pacaya"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/utils"
)

var (
	ZeroAddress         common.Address
	BlockMaxTxListBytes uint64 = (params.BlobTxBytesPerFieldElement - 1) * params.BlobTxFieldElementsPerBlob
	// DefaultInterruptSignals is a set of default interrupt signals.
	DefaultInterruptSignals = []os.Signal{
		os.Interrupt,
		os.Kill,
		syscall.SIGTERM,
		syscall.SIGQUIT,
	}
	ErrInvalidLength = errors.New("invalid length")
	ErrSlotBMarshal  = errors.New("abi: cannot marshal in to go type: length insufficient 160 require 192")
)

// CheckProverBalance checks if the prover has the necessary allowance and
// balance for a prover to pay the liveness bond.
func CheckProverBalance(
	ctx context.Context,
	rpc *Client,
	prover common.Address,
	address common.Address,
	bond *big.Int,
) (bool, error) {
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, DefaultRpcTimeout)
	defer cancel()

	// Check allowance on taiko token contract
	allowance, err := rpc.PacayaClients.TaikoToken.Allowance(&bind.CallOpts{Context: ctxWithTimeout}, prover, address)
	if err != nil {
		return false, err
	}

	log.Info(
		"Prover allowance for the contract",
		"allowance", utils.WeiToEther(allowance),
		"address", prover.Hex(),
		"bond", utils.WeiToEther(bond),
	)

	// Check prover's taiko token bondBalance
	bondBalance, err := rpc.PacayaClients.TaikoInbox.BondBalanceOf(&bind.CallOpts{Context: ctxWithTimeout}, prover)
	if err != nil {
		return false, err
	}

	// Check prover's taiko token tokenBalance
	tokenBalance, err := rpc.PacayaClients.TaikoToken.BalanceOf(&bind.CallOpts{Context: ctxWithTimeout}, prover)
	if err != nil {
		return false, err
	}

	log.Info(
		"Prover's wallet taiko token balance",
		"bondBalance", utils.WeiToEther(bondBalance),
		"tokenBalance", utils.WeiToEther(tokenBalance),
		"address", prover.Hex(),
		"bond", utils.WeiToEther(bond),
	)

	if bond.Cmp(allowance) > 0 && bond.Cmp(bondBalance) > 0 {
		log.Info(
			"Assigned prover does not have required on-chain token allowance",
			"allowance", utils.WeiToEther(allowance),
			"bondBalance", utils.WeiToEther(bondBalance),
			"bond", utils.WeiToEther(bond),
		)
		return false, nil
	}

	if bond.Cmp(bondBalance) > 0 && bond.Cmp(tokenBalance) > 0 {
		log.Info(
			"Assigned prover does not have required on-chain token balance",
			"bondBalance", utils.WeiToEther(bondBalance),
			"tokenBalance", utils.WeiToEther(tokenBalance),
			"bond", utils.WeiToEther(bond),
		)
		return false, nil
	}

	return true, nil
}

// BatchProofStatus represents the proving status of the given L2 blocks batch.
type BatchProofStatus struct {
	IsSubmitted  bool
	Invalid      bool
	ParentHeader *types.Header
}

// GetBatchProofStatus checks whether the L2 blocks batch still needs a new proof.
// Here are the possible status:
// 1. No proof on chain at all.
// 2. An invalid proof has been submitted.
// 3. A valid proof has been submitted.
func GetBatchProofStatus(
	ctx context.Context,
	cli *Client,
	batchID *big.Int,
) (*BatchProofStatus, error) {
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, DefaultRpcTimeout)
	defer cancel()

	var (
		parentID *big.Int
		batch    *pacayaBindings.ITaikoInboxBatch
		err      error
	)
	if batchID.Uint64() == cli.PacayaClients.ForkHeights.Pacaya {
		parentID = new(big.Int).Sub(batchID, common.Big1)
	} else {
		lastBatch, err := cli.GetBatchByID(ctx, new(big.Int).Sub(batchID, common.Big1))
		if err != nil {
			return nil, err
		}
		parentID = new(big.Int).SetUint64(lastBatch.LastBlockId)
	}

	if batch, err = cli.GetBatchByID(ctx, batchID); err != nil {
		return nil, err
	}

	// Get the local L2 parent header.
	parent, err := cli.L2.HeaderByNumber(ctxWithTimeout, parentID)
	if err != nil {
		return nil, err
	}

	// Get the transition state from Pacaya TaikoInbox contract.
	transition, err := cli.PacayaClients.TaikoInbox.GetTransitionByParentHash(
		&bind.CallOpts{Context: ctxWithTimeout},
		batchID.Uint64(),
		parent.Hash(),
	)
	if err != nil {
		if !strings.Contains(encoding.TryParsingCustomError(err).Error(), "TransitionNotFound") {
			return nil, encoding.TryParsingCustomError(err)
		}

		// Status 1, no proof on chain at all.
		return &BatchProofStatus{IsSubmitted: false, ParentHeader: parent}, nil
	}

	lastHeaderInBatch, err := cli.L2.HeaderByNumber(ctxWithTimeout, new(big.Int).SetUint64(batch.LastBlockId))
	if err != nil {
		return nil, err
	}
	if transition.BlockHash != lastHeaderInBatch.Hash() ||
		(transition.StateRoot != (common.Hash{}) && transition.StateRoot != lastHeaderInBatch.Root) {
		log.Warn(
			"Different block hash or state root detected, try submitting another proof",
			"batchID", batchID,
			"parent", parent.Hash().Hex(),
			"localBlockHash", lastHeaderInBatch.Hash(),
			"protocolTransitionBlockHash", common.Hash(transition.BlockHash),
			"localStateRoot", lastHeaderInBatch.Root,
			"protocolTransitionStateRoot", common.Hash(transition.StateRoot),
		)
		// Status 2, an invalid proof has been submitted.
		return &BatchProofStatus{IsSubmitted: true, Invalid: true, ParentHeader: parent}, nil
	}

	// Status 3, a valid proof has been submitted.
	return &BatchProofStatus{IsSubmitted: true, ParentHeader: parent}, nil
}

// SetHead makes a `debug_setHead` RPC call to set the chain's head, should only be used
// for testing purpose.
func SetHead(ctx context.Context, client *EthClient, headNum *big.Int) error {
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, DefaultRpcTimeout)
	defer cancel()

	return client.SetHead(ctxWithTimeout, headNum)
}

// StringToBytes32 converts the given string to [32]byte.
func StringToBytes32(str string) [32]byte {
	var b [32]byte
	copy(b[:], []byte(str))

	return b
}

// LastPacayaBlockID returns the last Pacaya block ID by querying the Pacaya Inbox.
// It reads stats2.NumBatches and then getBatch(NumBatches-1).LastBlockId.
// If there are no batches yet, it returns 0.
func (c *Client) LastPacayaBlockID(ctx context.Context) (*big.Int, error) {
	if c == nil || c.PacayaClients == nil || c.PacayaClients.TaikoInbox == nil {
		return nil, errors.New("rpc or pacaya inbox client not initialized")
	}
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, DefaultRpcTimeout)
	defer cancel()

	stats2, err := c.PacayaClients.TaikoInbox.GetStats2(&bind.CallOpts{Context: ctxWithTimeout})
	if err != nil {
		return nil, err
	}
	if stats2.NumBatches == 0 {
		return common.Big0, nil
	}
	lastBatchID := stats2.NumBatches - 1
	batch, err := c.PacayaClients.TaikoInbox.GetBatch(&bind.CallOpts{Context: ctxWithTimeout}, lastBatchID)
	if err != nil {
		return nil, err
	}
	return new(big.Int).SetUint64(batch.LastBlockId), nil
}

// CtxWithTimeoutOrDefault sets a context timeout if the deadline has not passed or is not set,
// and otherwise returns the context as passed in. cancel func is always set to an empty function
// so is safe to defer the cancel.
func CtxWithTimeoutOrDefault(ctx context.Context, defaultTimeout time.Duration) (context.Context, context.CancelFunc) {
	if utils.IsNil(ctx) {
		return context.WithTimeout(context.Background(), defaultTimeout)
	}
	if _, ok := ctx.Deadline(); !ok {
		return context.WithTimeout(ctx, defaultTimeout)
	}

	return ctx, func() {}
}

// BlockOnInterruptsContext blocks until a SIGTERM is received.
// Passing in signals will override the default signals.
// The function will stop blocking if the context is closed.
func BlockOnInterruptsContext(ctx context.Context, signals ...os.Signal) {
	if len(signals) == 0 {
		signals = DefaultInterruptSignals
	}
	interruptChannel := make(chan os.Signal, 1)
	signal.Notify(interruptChannel, signals...)
	select {
	case <-interruptChannel:
	case <-ctx.Done():
		signal.Stop(interruptChannel)
	}
}
