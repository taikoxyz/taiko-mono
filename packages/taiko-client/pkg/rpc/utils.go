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
	"golang.org/x/sync/errgroup"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	ontakeBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/ontake"
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
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, defaultTimeout)
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

// BlockProofStatus represents the proving status of the given L2 block.
type BlockProofStatus struct {
	IsSubmitted            bool
	Invalid                bool
	CurrentTransitionState *ontakeBindings.TaikoDataTransitionState
	ParentHeader           *types.Header
}

// GetBlockProofStatus checks whether the L2 block still needs a new proof or a new contest.
// Here are the possible status:
// 1. No proof on chain at all.
// 2. A valid proof has been submitted.
// 3. An invalid proof has been submitted, and there is no valid contest.
// 4. An invalid proof has been submitted, and there is a valid contest.
func GetBlockProofStatus(
	ctx context.Context,
	cli *Client,
	id *big.Int,
	proverAddress common.Address,
	proverSetAddress common.Address,
) (*BlockProofStatus, error) {
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, defaultTimeout)
	defer cancel()

	// Get the local L2 parent header.
	parent, err := cli.L2.HeaderByNumber(ctxWithTimeout, new(big.Int).Sub(id, common.Big1))
	if err != nil {
		return nil, err
	}

	// Get the transition state from TaikoL1 contract.
	transition, err := cli.OntakeClients.TaikoL1.GetTransition0(
		&bind.CallOpts{Context: ctxWithTimeout},
		id.Uint64(),
		parent.Hash(),
	)
	if err != nil {
		if !strings.Contains(encoding.TryParsingCustomError(err).Error(), "L1_TRANSITION_NOT_FOUND") {
			return nil, encoding.TryParsingCustomError(err)
		}

		// Status 1, no proof on chain at all.
		return &BlockProofStatus{IsSubmitted: false, ParentHeader: parent}, nil
	}

	header, err := cli.WaitL2Header(ctxWithTimeout, id)
	if err != nil {
		return nil, err
	}

	if header.Hash() != transition.BlockHash ||
		(transition.StateRoot != (common.Hash{}) && transition.StateRoot != header.Root) {
		log.Info(
			"Different block hash or state root detected, try submitting a contest",
			"localBlockHash", header.Hash(),
			"protocolTransitionBlockHash", common.BytesToHash(transition.BlockHash[:]),
			"localStateRoot", header.Root,
			"protocolTransitionStateRoot", common.BytesToHash(transition.StateRoot[:]),
		)
		return &BlockProofStatus{
			IsSubmitted:            true,
			Invalid:                true,
			CurrentTransitionState: &transition,
			ParentHeader:           parent,
		}, nil
	}

	if proverAddress == transition.Prover ||
		(proverSetAddress != ZeroAddress && transition.Prover == proverSetAddress) {
		log.Info(
			"📬 Block's proof has already been submitted by current prover",
			"blockID", id,
			"parent", parent.Hash().Hex(),
			"hash", common.Bytes2Hex(transition.BlockHash[:]),
			"stateRoot", common.Bytes2Hex(transition.StateRoot[:]),
			"timestamp", transition.Timestamp,
			"contester", transition.Contester,
		)
		return &BlockProofStatus{
			IsSubmitted:            true,
			Invalid:                transition.Contester != ZeroAddress,
			ParentHeader:           parent,
			CurrentTransitionState: &transition,
		}, nil
	}

	log.Info(
		"📬 Block's proof has already been submitted by another prover",
		"blockID", id,
		"prover", transition.Prover,
		"parent", parent.Hash().Hex(),
		"hash", common.Bytes2Hex(transition.BlockHash[:]),
		"stateRoot", common.Bytes2Hex(transition.StateRoot[:]),
		"timestamp", transition.Timestamp,
		"contester", transition.Contester,
	)

	return &BlockProofStatus{
		IsSubmitted:            true,
		Invalid:                transition.Contester != ZeroAddress,
		ParentHeader:           parent,
		CurrentTransitionState: &transition,
	}, nil
}

// GetBatchesProofStatus checks whether the L2 blocks batch still needs a new proof.
// Here are the possible status:
// 1. No proof on chain at all.
// 2. An invalid proof has been submitted.
// 3. A valid proof has been submitted.
func GetBatchProofStatus(
	ctx context.Context,
	cli *Client,
	batchID *big.Int,
) (*BlockProofStatus, error) {
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, defaultTimeout)
	defer cancel()

	var (
		parentID *big.Int
		batch    *pacayaBindings.ITaikoInboxBatch
		err      error
	)
	if batchID.Uint64() == cli.PacayaClients.ForkHeight {
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

	// Get the transition state from TaikoInbox contract.
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
		return &BlockProofStatus{IsSubmitted: false, ParentHeader: parent}, nil
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
			"protocolTransitionBlockHash", common.BytesToHash(transition.BlockHash[:]),
			"localStateRoot", lastHeaderInBatch.Root,
			"protocolTransitionStateRoot", common.BytesToHash(transition.StateRoot[:]),
		)
		// Status 2, an invalid proof has been submitted.
		return &BlockProofStatus{IsSubmitted: true, Invalid: true, ParentHeader: parent}, nil
	}

	// Status 3, a valid proof has been submitted.
	return &BlockProofStatus{IsSubmitted: true, ParentHeader: parent}, nil
}

// BatchGetBlocksProofStatus checks whether the batch of L2 blocks still need new proofs or new contests.
// Here are the possible status:
// 1. No proof on chain at all.
// 2. A valid proof has been submitted.
// 3. An invalid proof has been submitted, and there is no valid contest.
// 4. An invalid proof has been submitted, and there is a valid contest.
func BatchGetBlocksProofStatus(
	ctx context.Context,
	cli *Client,
	ids []*big.Int,
	proverAddress common.Address,
	proverSetAddress common.Address,
) ([]*BlockProofStatus, error) {
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, defaultTimeout)
	defer cancel()
	var (
		parentHashes   = make([][32]byte, len(ids))
		parentIDs      = make([]*big.Int, len(ids))
		blockIDs       = make([]*big.Int, len(ids))
		uint64BlockIDs = make([]uint64, len(ids))
		result         = make([]*BlockProofStatus, len(ids))
		highestBlockID = big.NewInt(0)
	)
	for i, id := range ids {
		parentIDs[i] = new(big.Int).Sub(id, common.Big1)
		blockIDs[i] = id
		uint64BlockIDs[i] = id.Uint64()
		if id.Cmp(highestBlockID) > 0 {
			highestBlockID = id
		}
	}
	// Get the local L2 parent headers.
	parents, err := cli.L2.BatchHeadersByNumbers(ctxWithTimeout, parentIDs)
	if err != nil {
		return nil, err
	}
	if len(parents) != len(ids) {
		return nil, ErrInvalidLength
	}
	for i := range ids {
		parentHashes[i] = parents[i].Hash()
	}
	// Get the transition state from TaikoL1 contract.
	transitions, err := cli.OntakeClients.TaikoL1.GetTransitions(
		&bind.CallOpts{Context: ctxWithTimeout},
		uint64BlockIDs,
		parentHashes,
	)
	if err != nil {
		return nil, err
	}
	_, err = cli.WaitL2Header(ctxWithTimeout, highestBlockID)
	if err != nil {
		return nil, err
	}
	blockHeaders, err := cli.L2.BatchHeadersByNumbers(ctxWithTimeout, blockIDs)
	if err != nil {
		return nil, err
	}
	if len(transitions) != len(ids) || len(blockHeaders) != len(ids) {
		return nil, ErrInvalidLength
	}
	g, _ := errgroup.WithContext(ctxWithTimeout)
	for i, transition := range transitions {
		// No proof on chain
		if transition.BlockHash == (common.Hash{}) {
			result[i] = &BlockProofStatus{IsSubmitted: false, ParentHeader: parents[i]}
			continue
		}
		g.Go(func() error {
			if blockHeaders[i].Hash() != transition.BlockHash ||
				(transition.StateRoot != (common.Hash{}) && transition.StateRoot != blockHeaders[i].Root) {
				log.Info(
					"Different block hash or state root detected, try submitting a contest",
					"localBlockHash", blockHeaders[i].Hash(),
					"protocolTransitionBlockHash", common.BytesToHash(transition.BlockHash[:]),
					"localStateRoot", blockHeaders[i].Root,
					"protocolTransitionStateRoot", common.BytesToHash(transition.StateRoot[:]),
				)
				result[i] = &BlockProofStatus{
					IsSubmitted:            true,
					Invalid:                true,
					CurrentTransitionState: &transitions[i],
					ParentHeader:           parents[i],
				}
				return nil
			}

			if proverAddress == transition.Prover ||
				(proverSetAddress != ZeroAddress && transition.Prover == proverSetAddress) {
				log.Info(
					"📬 Block's proof has already been submitted by current prover",
					"blockID", ids[i],
					"parent", parents[i].Hash().Hex(),
					"hash", common.Bytes2Hex(transition.BlockHash[:]),
					"stateRoot", common.Bytes2Hex(transition.StateRoot[:]),
					"timestamp", transition.Timestamp,
					"contester", transition.Contester,
				)
				result[i] = &BlockProofStatus{
					IsSubmitted:            true,
					Invalid:                transition.Contester != ZeroAddress,
					ParentHeader:           parents[i],
					CurrentTransitionState: &transitions[i],
				}
				return nil
			}
			log.Info(
				"📬 Block's proof has already been submitted by another prover",
				"blockID", ids[i],
				"prover", transition.Prover,
				"parent", parents[i].Hash().Hex(),
				"hash", common.Bytes2Hex(transition.BlockHash[:]),
				"stateRoot", common.Bytes2Hex(transition.StateRoot[:]),
				"timestamp", transition.Timestamp,
				"contester", transition.Contester,
			)

			result[i] = &BlockProofStatus{
				IsSubmitted:            true,
				Invalid:                transition.Contester != ZeroAddress,
				ParentHeader:           parents[i],
				CurrentTransitionState: &transitions[i],
			}
			return nil
		})
	}
	return result, g.Wait()
}

// SetHead makes a `debug_setHead` RPC call to set the chain's head, should only be used
// for testing purpose.
func SetHead(ctx context.Context, client *EthClient, headNum *big.Int) error {
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, defaultTimeout)
	defer cancel()

	return client.SetHead(ctxWithTimeout, headNum)
}

// StringToBytes32 converts the given string to [32]byte.
func StringToBytes32(str string) [32]byte {
	var b [32]byte
	copy(b[:], []byte(str))

	return b
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
