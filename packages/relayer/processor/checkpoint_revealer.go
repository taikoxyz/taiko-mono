package processor

import (
	"context"
	"fmt"
	"log/slog"
	"math/big"
	"sync"
	"time"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/rlp"

	"github.com/taikoxyz/taiko-mono/packages/relayer"
	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/v4/anchor"
)

const (
	// checkpointRevealRetryAfter is how long a successful reveal is given to reach the index before
	// the revealer may send another one for the blocks it covers. The indexer normally stores it
	// well within a minute; one that never arrives was most likely reorged out.
	checkpointRevealRetryAfter = 2 * time.Minute

	// maxSettledBlockLookback bounds how far back from the destination head the revealer looks for
	// a block whose timestamp is lower than the head's.
	maxSettledBlockLookback = 64
)

// headerReader is the part of an ethClient the revealer reads headers through.
type headerReader interface {
	HeaderByHash(ctx context.Context, hash common.Hash) (*types.Header, error)
	HeaderByNumber(ctx context.Context, number *big.Int) (*types.Header, error)
}

// txSender sends a transaction and waits for its receipt. The processor's tx manager is one.
type txSender interface {
	Send(ctx context.Context, candidate txmgr.TxCandidate) (*types.Receipt, error)
}

// checkpointStoreReader reads the checkpoint store an Anchor writes to. Only an Anchor has one,
// which is how startup tells it apart from the L1 Inbox.
type checkpointStoreReader interface {
	CheckpointStore(opts *bind.CallOpts) (common.Address, error)
}

// l1CheckpointRevealer is what the header-sync wait needs from a checkpointRevealer.
type l1CheckpointRevealer interface {
	reveal(ctx context.Context, minL1Block uint64) error
}

// checkpointRevealer saves L1 checkpoints on the destination chain once the Etna fork leaves no
// anchor transaction to do it. From Etna on, each L2 block's parentBeaconBlockRoot is the hash of
// the L1 block it anchors to, EIP-4788 records that hash under the block's timestamp, and
// Anchor.revealCheckpoint turns a recorded hash and the matching L1 header into a checkpoint.
//
// The revealer only sends the transaction. The checkpoint reaches the processor the way an
// anchored one always has: the indexer stores the CheckpointSaved event it emits, and the
// header-sync wait finds it there.
type checkpointRevealer struct {
	anchor    common.Address
	anchorABI *abi.ABI
	// srcClient resolves anchored L1 block hashes to headers; destClient reads the L2 headers that
	// carry them.
	srcClient  headerReader
	destClient headerReader
	sender     txSender
	// interval is the shortest time between two attempts, however many messages are waiting.
	interval   time.Duration
	retryAfter time.Duration
	now        func() time.Time

	mu          sync.Mutex
	attemptedAt time.Time
	// revealed is the L1 block number of the last checkpoint this revealer saved, at revealedAt.
	revealed   uint64
	revealedAt time.Time
}

// newCheckpointRevealer returns a revealer that sends reveals to the Anchor at anchorAddress. It
// first reads the Anchor's checkpoint store. The L1 Inbox, which an L2 to L1 processor has as its
// destTaikoAddress, has none, so a processor given the wrong address refuses to start instead of
// failing every reveal after the fork.
func newCheckpointRevealer(
	ctx context.Context,
	anchorAddress common.Address,
	anchorCaller checkpointStoreReader,
	srcClient headerReader,
	destClient headerReader,
	sender txSender,
	interval time.Duration,
) (*checkpointRevealer, error) {
	checkpointStore, err := anchorCaller.CheckpointStore(&bind.CallOpts{Context: ctx})
	if err != nil {
		return nil, fmt.Errorf(
			"enableCheckpointReveal: destTaikoAddress %s is not an Anchor: %w", anchorAddress.Hex(), err,
		)
	}

	if checkpointStore == (common.Address{}) {
		return nil, fmt.Errorf(
			"enableCheckpointReveal: destTaikoAddress %s has no checkpoint store", anchorAddress.Hex(),
		)
	}

	anchorABI, err := anchor.AnchorMetaData.GetAbi()
	if err != nil {
		return nil, err
	}

	slog.Info("Checkpoint reveal enabled",
		"anchor", anchorAddress.Hex(),
		"checkpointStore", checkpointStore.Hex(),
	)

	return &checkpointRevealer{
		anchor:     anchorAddress,
		anchorABI:  anchorABI,
		srcClient:  srcClient,
		destClient: destClient,
		sender:     sender,
		interval:   interval,
		retryAfter: checkpointRevealRetryAfter,
		now:        time.Now,
	}, nil
}

// reveal makes sure a checkpoint for an L1 block at or above minL1Block is on its way to the
// destination chain, sending a revealCheckpoint transaction when one is needed and possible.
//
// It returns nil whenever there is nothing to do yet: another call is attempting a reveal, an
// earlier reveal covering minL1Block has not had time to reach the index, the last attempt was
// less than an interval ago, the destination is not past Etna, or L2 has not anchored minL1Block
// yet. It never blocks on another call, so a message whose checkpoint is already indexed is never
// held up behind a reveal.
func (r *checkpointRevealer) reveal(ctx context.Context, minL1Block uint64) error {
	if !r.mu.TryLock() {
		return nil
	}

	defer r.mu.Unlock()

	now := r.now()

	if r.revealed >= minL1Block && now.Sub(r.revealedAt) < r.retryAfter {
		return nil
	}

	if now.Sub(r.attemptedAt) < r.interval {
		return nil
	}

	r.attemptedAt = now

	l2Header, err := r.settledHeader(ctx)
	if err != nil {
		return err
	}

	// Zero before Etna, where the anchor transaction still saves every checkpoint.
	root := l2Header.ParentBeaconRoot
	if root == nil || *root == (common.Hash{}) {
		slog.Debug("No anchored L1 block hash to reveal", "l2BlockNumber", l2Header.Number.Uint64())

		return nil
	}

	l1Header, err := r.srcClient.HeaderByHash(ctx, *root)
	if err != nil {
		return fmt.Errorf("fetching anchored L1 header %s: %w", root.Hex(), err)
	}

	if l1Header.Number.Uint64() < minL1Block {
		slog.Debug("L2 has not anchored the L1 block yet",
			"anchoredL1Block", l1Header.Number.Uint64(),
			"blockIDWaitingFor", minL1Block,
		)

		return nil
	}

	// The Anchor accepts only the exact bytes that hash to the recorded root. go-ethereum encodes
	// the header fields it knows, so a field added by a later L1 fork is caught here, before any gas
	// is spent, until the dependency is bumped.
	headerRlp, err := rlp.EncodeToBytes(l1Header)
	if err != nil {
		return fmt.Errorf("encoding L1 header %s: %w", root.Hex(), err)
	}

	if crypto.Keccak256Hash(headerRlp) != *root {
		return fmt.Errorf(
			"cannot reproduce the encoding of L1 header %s (block %d)", root.Hex(), l1Header.Number.Uint64(),
		)
	}

	data, err := r.anchorABI.Pack("revealCheckpoint", l2Header.Time, headerRlp)
	if err != nil {
		return fmt.Errorf("packing revealCheckpoint: %w", err)
	}

	// No gas limit: the tx manager estimates it, so a reveal that would revert fails here without
	// spending anything.
	receipt, err := r.sender.Send(ctx, txmgr.TxCandidate{TxData: data, To: &r.anchor})
	if err != nil {
		return fmt.Errorf("sending revealCheckpoint: %w", err)
	}

	if receipt.Status != types.ReceiptStatusSuccessful {
		return fmt.Errorf("revealCheckpoint %s: %w", receipt.TxHash.Hex(), errTxReverted)
	}

	r.revealed = l1Header.Number.Uint64()
	r.revealedAt = r.now()

	relayer.CheckpointRevealsSent.Inc()

	slog.Info("Revealed an L1 checkpoint",
		"l1BlockNumber", r.revealed,
		"l1BlockHash", root.Hex(),
		"l2Timestamp", l2Header.Time,
		"txHash", receipt.TxHash.Hex(),
		"gasUsed", receipt.GasUsed,
	)

	return nil
}

// settledHeader returns the newest destination block whose timestamp is lower than the head's.
// EIP-4788 keeps one root per timestamp, in slot timestamp % 8191, and a later block with the same
// timestamp overwrites it. Once a block with a larger timestamp exists, the slot of a smaller one
// cannot change for 8191 seconds, so a reveal naming it still finds the same root when it lands.
func (r *checkpointRevealer) settledHeader(ctx context.Context) (*types.Header, error) {
	head, err := r.destClient.HeaderByNumber(ctx, nil)
	if err != nil {
		return nil, fmt.Errorf("fetching the destination head: %w", err)
	}

	headNumber := head.Number.Uint64()

	for back := uint64(1); back <= maxSettledBlockLookback && back <= headNumber; back++ {
		header, err := r.destClient.HeaderByNumber(ctx, new(big.Int).SetUint64(headNumber-back))
		if err != nil {
			return nil, fmt.Errorf("fetching destination block %d: %w", headNumber-back, err)
		}

		if header.Time < head.Time {
			return header, nil
		}
	}

	return nil, fmt.Errorf(
		"no destination block within %d of head %d has a lower timestamp", maxSettledBlockLookback, headNumber,
	)
}
