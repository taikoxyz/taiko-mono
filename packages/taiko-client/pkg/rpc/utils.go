package rpc

import (
	"context"
	"fmt"
	"math/big"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/txpool"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/log"
	"github.com/ethereum/go-ethereum/params"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/utils"
)

var (
	ZeroAddress                common.Address
	waitReceiptPollingInterval = 3 * time.Second
	defaultWaitReceiptTimeout  = 1 * time.Minute
	BlobBytes                  = params.BlobTxBytesPerFieldElement * params.BlobTxFieldElementsPerBlob
)

// GetProtocolStateVariables gets the protocol states from TaikoL1 contract.
func GetProtocolStateVariables(
	taikoL1Client *bindings.TaikoL1Client,
	opts *bind.CallOpts,
) (*struct {
	A bindings.TaikoDataSlotA
	B bindings.TaikoDataSlotB
}, error) {
	stateVars, err := taikoL1Client.GetStateVariables(opts)
	if err != nil {
		return nil, err
	}
	return &stateVars, nil
}

// CheckProverBalance checks if the prover has the necessary allowance and
// balance for a prover to pay the liveness bond.
func CheckProverBalance(
	ctx context.Context,
	rpc *Client,
	prover common.Address,
	address common.Address,
	bond *big.Int,
) (bool, error) {
	ctxWithTimeout, cancel := ctxWithTimeoutOrDefault(ctx, defaultTimeout)
	defer cancel()

	// Check allowance on taiko token contract
	allowance, err := rpc.TaikoToken.Allowance(&bind.CallOpts{Context: ctxWithTimeout}, prover, address)
	if err != nil {
		return false, err
	}

	log.Info(
		"Prover allowance for TaikoL1 contract",
		"allowance", allowance.String(),
		"address", prover.Hex(),
		"bond", bond.String(),
	)

	// Check prover's taiko token balance
	balance, err := rpc.TaikoToken.BalanceOf(&bind.CallOpts{Context: ctxWithTimeout}, prover)
	if err != nil {
		return false, err
	}

	log.Info(
		"Prover's wallet taiko token balance",
		"balance", balance.String(),
		"address", prover.Hex(),
		"bond", bond.String(),
	)

	if bond.Cmp(allowance) > 0 || bond.Cmp(balance) > 0 {
		log.Info(
			"Assigned prover does not have required on-chain token balance or allowance",
			"providedProver", prover.Hex(),
			"taikoTokenBalance", balance,
			"allowance", allowance.String(),
			"bond", bond,
		)
		return false, nil
	}

	return true, nil
}

// WaitReceipt keeps waiting until the given transaction has an execution
// receipt to know whether it was reverted or not.
func WaitReceipt(
	ctx context.Context,
	client *EthClient,
	tx *types.Transaction,
) (*types.Receipt, error) {
	ticker := time.NewTicker(waitReceiptPollingInterval)
	ctxWithTimeout, cancel := ctxWithTimeoutOrDefault(ctx, defaultWaitReceiptTimeout)

	defer func() {
		cancel()
		ticker.Stop()
	}()

	// If we are running tests, we don't need to wait for `waitL1OriginPollingInterval` seconds
	// at first, just start fetching the receipt immediately.
	if os.Getenv("RUN_TESTS") == "" {
		<-time.After(waitL1OriginPollingInterval)
	}

	for ; true; <-ticker.C {
		if ctxWithTimeout.Err() != nil {
			return nil, ctxWithTimeout.Err()
		}

		receipt, err := client.TransactionReceipt(ctxWithTimeout, tx.Hash())
		if err != nil {
			log.Debug("Failed to fetch transaction receipt", "hash", tx.Hash(), "error", err)
			continue
		}

		if receipt.Status != types.ReceiptStatusSuccessful {
			return nil, fmt.Errorf("transaction reverted, hash: %s", tx.Hash())
		}

		return receipt, nil
	}

	return nil, fmt.Errorf("failed to find the receipt for transaction %s", tx.Hash())
}

// BlockProofStatus represents the proving status of the given L2 block.
type BlockProofStatus struct {
	IsSubmitted            bool
	Invalid                bool
	CurrentTransitionState *bindings.TaikoDataTransitionState
	ParentHeader           *types.Header
}

// GetBlockProofStatus checks whether the L2 block still needs a new proof or a new contest.
func GetBlockProofStatus(
	ctx context.Context,
	cli *Client,
	id *big.Int,
	proverAddress common.Address,
) (*BlockProofStatus, error) {
	ctxWithTimeout, cancel := ctxWithTimeoutOrDefault(ctx, defaultTimeout)
	defer cancel()

	var parent *types.Header
	if id.Cmp(common.Big1) == 0 {
		header, err := cli.L2.HeaderByNumber(ctxWithTimeout, common.Big0)
		if err != nil {
			return nil, err
		}

		parent = header
	} else {
		parentL1Origin, err := cli.WaitL1Origin(ctxWithTimeout, new(big.Int).Sub(id, common.Big1))
		if err != nil {
			return nil, err
		}

		if parent, err = cli.L2.HeaderByHash(ctxWithTimeout, parentL1Origin.L2BlockHash); err != nil {
			return nil, err
		}
	}

	transition, err := cli.TaikoL1.GetTransition(
		&bind.CallOpts{Context: ctxWithTimeout},
		id.Uint64(),
		parent.Hash(),
	)
	if err != nil {
		if !strings.Contains(encoding.TryParsingCustomError(err).Error(), "L1_TRANSITION_NOT_FOUND") {
			return nil, encoding.TryParsingCustomError(err)
		}

		return &BlockProofStatus{IsSubmitted: false, ParentHeader: parent}, nil
	}

	l1Origin, err := cli.WaitL1Origin(ctxWithTimeout, id)
	if err != nil {
		return nil, err
	}

	header, err := cli.L2.HeaderByHash(ctxWithTimeout, l1Origin.L2BlockHash)
	if err != nil {
		return nil, err
	}

	if l1Origin.L2BlockHash != transition.BlockHash || transition.StateRoot != header.Root {
		log.Info(
			"Different block hash or state root detected, try submitting a contest",
			"localBlockHash", common.BytesToHash(l1Origin.L2BlockHash[:]),
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

	if proverAddress == transition.Prover {
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

type AccountPoolContent map[string]map[string]map[string]*types.Transaction
type AccountPoolContentFrom map[string]map[string]*types.Transaction

// Content GetPendingTxs fetches the pending transactions from tx pool.
func Content(ctx context.Context, client *EthClient) (AccountPoolContent, error) {
	ctxWithTimeout, cancel := ctxWithTimeoutOrDefault(ctx, defaultTimeout)
	defer cancel()

	var result AccountPoolContent
	return result, client.CallContext(ctxWithTimeout, &result, "txpool_content")
}

// ContentFrom fetches a given account's transactions list from a node's transactions pool.
func ContentFrom(
	ctx context.Context,
	rawRPC *EthClient,
	address common.Address,
) (AccountPoolContentFrom, error) {
	ctxWithTimeout, cancel := ctxWithTimeoutOrDefault(ctx, defaultTimeout)
	defer cancel()

	var result AccountPoolContentFrom
	return result, rawRPC.CallContext(
		ctxWithTimeout,
		&result,
		"txpool_contentFrom",
		address,
	)
}

// IncreaseGasTipCap tries to increase the given transaction's gasTipCap.
func IncreaseGasTipCap(
	ctx context.Context,
	cli *Client,
	opts *bind.TransactOpts,
	address common.Address,
	txReplacementTipMultiplier *big.Int,
	maxGasTipCap *big.Int,
) (*bind.TransactOpts, error) {
	ctxWithTimeout, cancel := ctxWithTimeoutOrDefault(ctx, defaultTimeout)
	defer cancel()

	log.Info("Try replacing a transaction with same nonce", "sender", address, "nonce", opts.Nonce)

	originalTx, err := GetPendingTxByNonce(ctxWithTimeout, cli.L1, address, opts.Nonce.Uint64())
	if err != nil || originalTx == nil {
		log.Warn(
			"Original transaction not found",
			"sender", address,
			"nonce", opts.Nonce,
			"error", err,
		)

		opts.GasTipCap = new(big.Int).Mul(opts.GasTipCap, txReplacementTipMultiplier)
	} else {
		log.Info(
			"Original transaction to replace",
			"sender", address,
			"nonce", opts.Nonce,
			"gasTipCap", originalTx.GasTipCap(),
			"gasFeeCap", originalTx.GasFeeCap(),
		)

		opts.GasTipCap = new(big.Int).Mul(originalTx.GasTipCap(), txReplacementTipMultiplier)
	}

	if maxGasTipCap != nil && opts.GasTipCap.Cmp(maxGasTipCap) > 0 {
		log.Info(
			"New gasTipCap exceeds limit, keep waiting",
			"multiplier", txReplacementTipMultiplier,
			"newGasTipCap", opts.GasTipCap,
			"maxTipCap", maxGasTipCap,
		)
		return nil, txpool.ErrReplaceUnderpriced
	}

	return opts, nil
}

// GetPendingTxByNonce tries to retrieve a pending transaction with a given nonce in a node's mempool.
func GetPendingTxByNonce(
	ctx context.Context,
	cli *EthClient,
	address common.Address,
	nonce uint64,
) (*types.Transaction, error) {
	ctxWithTimeout, cancel := ctxWithTimeoutOrDefault(ctx, defaultTimeout)
	defer cancel()

	content, err := ContentFrom(ctxWithTimeout, cli, address)
	if err != nil {
		return nil, err
	}

	for _, txMap := range content {
		for txNonce, tx := range txMap {
			if txNonce == strconv.Itoa(int(nonce)) {
				return tx, nil
			}
		}
	}

	return nil, nil
}

// SetHead makes a `debug_setHead` RPC call to set the chain's head, should only be used
// for testing purpose.
func SetHead(ctx context.Context, client *EthClient, headNum *big.Int) error {
	ctxWithTimeout, cancel := ctxWithTimeoutOrDefault(ctx, defaultTimeout)
	defer cancel()

	return client.SetHead(ctxWithTimeout, headNum)
}

// StringToBytes32 converts the given string to [32]byte.
func StringToBytes32(str string) [32]byte {
	var b [32]byte
	copy(b[:], []byte(str))

	return b
}

// IsArchiveNode checks if the given node is an archive node.
func IsArchiveNode(ctx context.Context, client *EthClient, l2GenesisHeight uint64) (bool, error) {
	ctxWithTimeout, cancel := ctxWithTimeoutOrDefault(ctx, defaultTimeout)
	defer cancel()

	if _, err := client.BalanceAt(ctxWithTimeout, ZeroAddress, new(big.Int).SetUint64(l2GenesisHeight)); err != nil {
		if strings.Contains(err.Error(), "missing trie node") {
			return false, nil
		}

		return false, err
	}

	return true, nil
}

// ctxWithTimeoutOrDefault sets a context timeout if the deadline has not passed or is not set,
// and otherwise returns the context as passed in. cancel func is always set to an empty function
// so is safe to defer the cancel.
func ctxWithTimeoutOrDefault(ctx context.Context, defaultTimeout time.Duration) (context.Context, context.CancelFunc) {
	if utils.IsNil(ctx) {
		return context.WithTimeout(context.Background(), defaultTimeout)
	}
	if _, ok := ctx.Deadline(); !ok {
		return context.WithTimeout(ctx, defaultTimeout)
	}

	return ctx, func() {}
}
