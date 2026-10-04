package processor

import (
	"context"
	"errors"
	"fmt"
	"math/big"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
)

const (
	// maxAnchorAge is how many blocks the L1 anchor an Etna proof is built at may trail the L1
	// head. Path-scheme geth without trie-node history serves eth_getProof only for about the
	// latest 128 blocks; a failed eth_getProof dead-letters the message, while waiting lets a
	// later L2 block's fresher anchor prove it.
	maxAnchorAge = 96

	// etnaSettleSeconds is how much older than the L2 head the L2 block an Etna proof is built
	// against must be. The L2 RPC may be several nodes behind one service, and a node that lags
	// the one that served the head by a few blocks would not yet have the block's EIP-4788 entry:
	// the claim's IsMessageReceived would fail and the message would be dead-lettered. Twelve
	// seconds costs nothing against the minutes the L1 anchor lags.
	etnaSettleSeconds = 12

	// maxSameTimestampLookback caps how far below the L2 head the search for a settled block
	// goes.
	maxSameTimestampLookback = 64

	// etnaExtraDataLength is the length of an Etna L2 header's extraData:
	// basefeeSharingPctg (1) | proposalId (6) | anchorBlockNumber (6).
	etnaExtraDataLength = 13
)

var (
	errNoSettledL2Block    = errors.New("no settled L2 block below the head")
	errMalformedEtnaHeader = errors.New("malformed Etna L2 header")
	errAnchorTooOld        = errors.New("L1 anchor is too old for eth_getProof")
	errOracleRootMismatch  = errors.New("getL1StateRoot does not match the L2 header root")
	errL1StateRootMismatch = errors.New("L1 block state root does not match the L2 header")
)

// etnaAnchor is the L1 anchor of an Etna L2 block, which an Etna signal proof is built against.
type etnaAnchor struct {
	// l2Timestamp is the L2 block's timestamp, the proof's blockId.
	l2Timestamp uint64
	// l1Block is the L1 anchor block, where eth_getProof runs.
	l1Block uint64
	// stateRoot is the L1 anchor block's state root, the proof's rootHash.
	stateRoot common.Hash
}

// etnaAnchorFor returns the anchor of the newest L2 block that EIP-4788 records for good, when
// that anchor can prove a message sent in L1 block blockNum. It returns nil and no error while the
// message just has to wait, and an error for a condition that points to an operational problem.
// The caller logs that error and keeps waiting; both mean the proof cannot be built yet.
func (p *Processor) etnaAnchorFor(
	ctx context.Context,
	srcEthClient ethClient,
	head *types.Header,
	etnaTimestamp uint64,
	blockNum uint64,
) (*etnaAnchor, error) {
	block, err := p.settledL2Block(ctx, head)
	if err != nil {
		return nil, err
	}

	// The first blocks after the fork: wait until a settled block is an Etna block.
	if block.Time < etnaTimestamp {
		return nil, nil
	}

	if len(block.Extra) != etnaExtraDataLength ||
		block.ParentBeaconRoot == nil ||
		*block.ParentBeaconRoot == (common.Hash{}) {
		return nil, fmt.Errorf("%w: block %v", errMalformedEtnaHeader, block.Number)
	}

	l1Block := anchorBlockNumber(block.Extra)
	if l1Block < blockNum {
		return nil, nil
	}

	l1Head, err := srcEthClient.BlockNumber(ctx)
	if err != nil {
		return nil, fmt.Errorf("L1 head: %w", err)
	}

	if l1Head > l1Block+maxAnchorAge {
		return nil, fmt.Errorf("%w: anchor %d, L1 head %d", errAnchorTooOld, l1Block, l1Head)
	}

	root := *block.ParentBeaconRoot

	// The claim reads the root through the same call, so this also catches an Anchor without
	// the Etna upgrade, a missing EIP-4788 contract, or an overwritten EIP-4788 entry.
	oracleRoot, err := p.destAnchor.GetL1StateRoot(&bind.CallOpts{Context: ctx}, block.Time)
	if err != nil {
		return nil, fmt.Errorf("getL1StateRoot(%d): %w", block.Time, err)
	}

	if common.Hash(oracleRoot) != root {
		return nil, fmt.Errorf("%w: timestamp %d", errOracleRootMismatch, block.Time)
	}

	l1Header, err := srcEthClient.HeaderByNumber(ctx, new(big.Int).SetUint64(l1Block))
	if err != nil {
		return nil, fmt.Errorf("L1 header %d: %w", l1Block, err)
	}

	// eth_getProof runs against L1's canonical block at this number, so a reorged anchor block
	// would yield a proof against another root.
	if l1Header.Root != root {
		return nil, fmt.Errorf("%w: L1 block %d", errL1StateRootMismatch, l1Block)
	}

	return &etnaAnchor{l2Timestamp: block.Time, l1Block: l1Block, stateRoot: root}, nil
}

// settledL2Block returns the newest L2 block below head whose timestamp is at least
// etnaSettleSeconds older than head's. EIP-4788 keys roots by timestamp and a later block with the
// same timestamp overwrites the entry, so only a block followed by a later timestamp has a final
// entry; the margin also gives L2 nodes that lag the one serving head time to record it.
func (p *Processor) settledL2Block(ctx context.Context, head *types.Header) (*types.Header, error) {
	number := head.Number.Uint64()

	for i := 0; i < maxSameTimestampLookback && number > 0; i++ {
		number--

		header, err := p.destEthClient.HeaderByNumber(ctx, new(big.Int).SetUint64(number))
		if err != nil {
			return nil, fmt.Errorf("L2 header %d: %w", number, err)
		}

		if header.Time+etnaSettleSeconds <= head.Time {
			return header, nil
		}
	}

	return nil, fmt.Errorf("%w: head %v", errNoSettledL2Block, head.Number)
}

// anchorBlockNumber decodes the big-endian uint48 L1 anchor block number in bytes 7..12 of an Etna
// L2 header's extraData. The caller checks the length.
func anchorBlockNumber(extra []byte) uint64 {
	var number uint64
	for _, b := range extra[7:etnaExtraDataLength] {
		number = number<<8 | uint64(b)
	}

	return number
}
