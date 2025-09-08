package rpc

import (
	"context"
	"errors"
	"fmt"
	"math/big"
	"strings"
	"time"

	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/common/hexutil"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/ethereum/go-ethereum/ethclient/gethclient"
	"github.com/ethereum/go-ethereum/rpc"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/metrics"
)

var (
	ErrInvalidLenOfParams = errors.New("invalid length of parameters")
)

// gethClient is a wrapper for go-ethereum geth client.
type gethClient struct {
	*gethclient.Client
}

// ethClient is a wrapper for go-ethereum eth client.
type ethClient struct {
	*ethclient.Client
}

// EthClient is a wrapper for go-ethereum eth client with a timeout attached.
type EthClient struct {
	ChainID *big.Int

	*rpc.Client
	*gethClient
	*ethClient

	timeout time.Duration
	rpcURL  string
}

// NewEthClient creates a new EthClient instance.
func NewEthClient(ctx context.Context, url string, timeout time.Duration) (*EthClient, error) {
	var timeoutVal = defaultTimeout
	if timeout != 0 {
		timeoutVal = timeout
	}

	client, err := rpc.DialContext(ctx, url)
	if err != nil {
		return nil, err
	}

	ethClient := &ethClient{ethclient.NewClient(client)}
	// Get chainID.
	chainID, err := ethClient.ChainID(ctx)
	if err != nil {
		return nil, err
	}

	return &EthClient{
		ChainID:    chainID,
		Client:     client,
		gethClient: &gethClient{gethclient.New(client)},
		ethClient:  ethClient,
		timeout:    timeoutVal,
		rpcURL:     url,
	}, nil
}

func (c *EthClient) EthClient() *ethclient.Client {
	return c.ethClient.Client
}

// CallContext wraps the underlying RPC client's CallContext with metrics tracking.
func (c *EthClient) CallContext(ctx context.Context, result interface{}, method string, args ...interface{}) error {
	start := time.Now()
	
	err := c.Client.CallContext(ctx, result, method, args...)
	
	// Record metrics
	duration := time.Since(start).Seconds()
	status := "success"
	if err != nil {
		status = "error"
		// Extract error type for more detailed metrics
		errorType := "unknown"
		if err.Error() != "" {
			errorType = strings.Split(err.Error(), ":")[0]
		}
		metrics.RPCCallErrorsCounter.WithLabelValues(method, c.rpcURL, errorType).Inc()
	}
	
	metrics.RPCCallsCounter.WithLabelValues(method, c.rpcURL, status).Inc()
	metrics.RPCCallDurationHistogram.WithLabelValues(method, c.rpcURL).Observe(duration)
	
	return err
}

// BatchCallContext wraps the underlying RPC client's BatchCallContext with metrics tracking.
func (c *EthClient) BatchCallContext(ctx context.Context, b []rpc.BatchElem) error {
	start := time.Now()
	
	err := c.Client.BatchCallContext(ctx, b)
	
	// Record metrics for batch calls
	duration := time.Since(start).Seconds()
	status := "success"
	if err != nil {
		status = "error"
		errorType := "unknown"
		if err.Error() != "" {
			errorType = strings.Split(err.Error(), ":")[0]
		}
		metrics.RPCCallErrorsCounter.WithLabelValues("batch_call", c.rpcURL, errorType).Inc()
	}
	
	// Count individual batch elements
	for _, elem := range b {
		elemStatus := "success"
		if elem.Error != nil {
			elemStatus = "error"
			errorType := "unknown"
			if elem.Error.Error() != "" {
				errorType = strings.Split(elem.Error.Error(), ":")[0]
			}
			metrics.RPCCallErrorsCounter.WithLabelValues(elem.Method, c.rpcURL, errorType).Inc()
		}
		metrics.RPCCallsCounter.WithLabelValues(elem.Method, c.rpcURL, elemStatus).Inc()
	}
	
	metrics.RPCCallsCounter.WithLabelValues("batch_call", c.rpcURL, status).Inc()
	metrics.RPCCallDurationHistogram.WithLabelValues("batch_call", c.rpcURL).Observe(duration)
	
	return err
}

// BlockByHash returns the given full block.
//
// Note that loading full blocks requires two requests. Use HeaderByHash
// if you don't need all transactions or uncle headers.
func (c *EthClient) BlockByHash(ctx context.Context, hash common.Hash) (*types.Block, error) {
	start := time.Now()
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, c.timeout)
	defer cancel()

	result, err := c.ethClient.BlockByHash(ctxWithTimeout, hash)
	
	// Record metrics
	duration := time.Since(start).Seconds()
	status := "success"
	if err != nil {
		status = "error"
		errorType := "unknown"
		if err.Error() != "" {
			errorType = strings.Split(err.Error(), ":")[0]
		}
		metrics.RPCCallErrorsCounter.WithLabelValues("eth_getBlockByHash", c.rpcURL, errorType).Inc()
	}
	
	metrics.RPCCallsCounter.WithLabelValues("eth_getBlockByHash", c.rpcURL, status).Inc()
	metrics.RPCCallDurationHistogram.WithLabelValues("eth_getBlockByHash", c.rpcURL).Observe(duration)
	
	return result, err
}

// BatchBlocksByHashes requests multiple blocks by their hashes in a batch.
func (c *EthClient) BatchBlocksByHashes(ctx context.Context, hashes []common.Hash) ([]*types.Block, error) {
	if len(hashes) < 1 {
		return nil, ErrInvalidLenOfParams
	}
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, c.timeout)
	defer cancel()

	reqs := make([]rpc.BatchElem, len(hashes))
	results := make([]*types.Block, len(hashes))
	for i, hash := range hashes {
		reqs[i] = rpc.BatchElem{
			Method: "eth_getBlockByHash",
			Args:   []interface{}{hash, true},
			Result: &results[i],
		}
	}
	if err := c.BatchCallContext(ctxWithTimeout, reqs); err != nil {
		return nil, err
	}
	for i := range reqs {
		if reqs[i].Error != nil {
			return nil, reqs[i].Error
		}
	}

	return results, nil
}

// BlockByNumber returns a block from the current canonical chain. If number is nil, the
// latest known block is returned.
//
// Note that loading full blocks requires two requests. Use HeaderByNumber
// if you don't need all transactions or uncle headers.
func (c *EthClient) BlockByNumber(ctx context.Context, number *big.Int) (*types.Block, error) {
	start := time.Now()
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, c.timeout)
	defer cancel()

	result, err := c.ethClient.BlockByNumber(ctxWithTimeout, number)
	
	// Record metrics
	duration := time.Since(start).Seconds()
	status := "success"
	if err != nil {
		status = "error"
		errorType := "unknown"
		if err.Error() != "" {
			errorType = strings.Split(err.Error(), ":")[0]
		}
		metrics.RPCCallErrorsCounter.WithLabelValues("eth_getBlockByNumber", c.rpcURL, errorType).Inc()
	}
	
	metrics.RPCCallsCounter.WithLabelValues("eth_getBlockByNumber", c.rpcURL, status).Inc()
	metrics.RPCCallDurationHistogram.WithLabelValues("eth_getBlockByNumber", c.rpcURL).Observe(duration)
	
	return result, err
}

// BlockNumber returns the most recent block number
func (c *EthClient) BlockNumber(ctx context.Context) (uint64, error) {
	start := time.Now()
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, c.timeout)
	defer cancel()

	result, err := c.ethClient.BlockNumber(ctxWithTimeout)
	
	// Record metrics
	duration := time.Since(start).Seconds()
	status := "success"
	if err != nil {
		status = "error"
		errorType := "unknown"
		if err.Error() != "" {
			errorType = strings.Split(err.Error(), ":")[0]
		}
		metrics.RPCCallErrorsCounter.WithLabelValues("eth_blockNumber", c.rpcURL, errorType).Inc()
	}
	
	metrics.RPCCallsCounter.WithLabelValues("eth_blockNumber", c.rpcURL, status).Inc()
	metrics.RPCCallDurationHistogram.WithLabelValues("eth_blockNumber", c.rpcURL).Observe(duration)
	
	return result, err
}

// PeerCount returns the number of p2p peers as reported by the net_peerCount method.
func (c *EthClient) PeerCount(ctx context.Context) (uint64, error) {
	start := time.Now()
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, c.timeout)
	defer cancel()

	result, err := c.ethClient.PeerCount(ctxWithTimeout)
	
	// Record metrics
	duration := time.Since(start).Seconds()
	status := "success"
	if err != nil {
		status = "error"
		errorType := "unknown"
		if err.Error() != "" {
			errorType = strings.Split(err.Error(), ":")[0]
		}
		metrics.RPCCallErrorsCounter.WithLabelValues("net_peerCount", c.rpcURL, errorType).Inc()
	}
	
	metrics.RPCCallsCounter.WithLabelValues("net_peerCount", c.rpcURL, status).Inc()
	metrics.RPCCallDurationHistogram.WithLabelValues("net_peerCount", c.rpcURL).Observe(duration)
	
	return result, err
}

// HeaderByHash returns the block header with the given hash.
func (c *EthClient) HeaderByHash(ctx context.Context, hash common.Hash) (*types.Header, error) {
	start := time.Now()
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, c.timeout)
	defer cancel()

	result, err := c.ethClient.HeaderByHash(ctxWithTimeout, hash)
	
	// Record metrics
	duration := time.Since(start).Seconds()
	status := "success"
	if err != nil {
		status = "error"
		errorType := "unknown"
		if err.Error() != "" {
			errorType = strings.Split(err.Error(), ":")[0]
		}
		metrics.RPCCallErrorsCounter.WithLabelValues("eth_getBlockByHash", c.rpcURL, errorType).Inc()
	}
	
	metrics.RPCCallsCounter.WithLabelValues("eth_getBlockByHash", c.rpcURL, status).Inc()
	metrics.RPCCallDurationHistogram.WithLabelValues("eth_getBlockByHash", c.rpcURL).Observe(duration)
	
	return result, err
}

// HeaderByNumber returns a block header from the current canonical chain. If number is
// nil, the latest known header is returned.
func (c *EthClient) HeaderByNumber(ctx context.Context, number *big.Int) (*types.Header, error) {
	start := time.Now()
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, c.timeout)
	defer cancel()

	result, err := c.ethClient.HeaderByNumber(ctxWithTimeout, number)
	
	// Record metrics
	duration := time.Since(start).Seconds()
	status := "success"
	if err != nil {
		status = "error"
		errorType := "unknown"
		if err.Error() != "" {
			errorType = strings.Split(err.Error(), ":")[0]
		}
		metrics.RPCCallErrorsCounter.WithLabelValues("eth_getBlockByNumber", c.rpcURL, errorType).Inc()
	}
	
	metrics.RPCCallsCounter.WithLabelValues("eth_getBlockByNumber", c.rpcURL, status).Inc()
	metrics.RPCCallDurationHistogram.WithLabelValues("eth_getBlockByNumber", c.rpcURL).Observe(duration)
	
	return result, err
}

func (c *EthClient) BatchHeadersByNumbers(ctx context.Context, numbers []*big.Int) ([]*types.Header, error) {
	if len(numbers) < 1 {
		return nil, ErrInvalidLenOfParams
	}
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, c.timeout)
	defer cancel()

	reqs := make([]rpc.BatchElem, len(numbers))
	results := make([]*types.Header, len(numbers))
	for i, blockNum := range numbers {
		reqs[i] = rpc.BatchElem{
			Method: "eth_getBlockByNumber",
			Args:   []interface{}{toBlockNumArg(blockNum), false},
			Result: &results[i],
		}
	}
	if err := c.BatchCallContext(ctxWithTimeout, reqs); err != nil {
		return nil, err
	}
	for i := range reqs {
		if reqs[i].Error != nil {
			return nil, reqs[i].Error
		}
	}

	return results, nil
}

func toBlockNumArg(number *big.Int) string {
	if number == nil {
		return "latest"
	}
	if number.Sign() >= 0 {
		return hexutil.EncodeBig(number)
	}
	// It's negative.
	if number.IsInt64() {
		return rpc.BlockNumber(number.Int64()).String()
	}
	// It's negative and large, which is invalid.
	return fmt.Sprintf("<invalid %d>", number)
}

// TransactionByHash returns the transaction with the given hash.
func (c *EthClient) TransactionByHash(
	ctx context.Context,
	hash common.Hash,
) (tx *types.Transaction, isPending bool, err error) {
	start := time.Now()
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, c.timeout)
	defer cancel()

	tx, isPending, err = c.ethClient.TransactionByHash(ctxWithTimeout, hash)
	
	// Record metrics
	duration := time.Since(start).Seconds()
	status := "success"
	if err != nil {
		status = "error"
		errorType := "unknown"
		if err.Error() != "" {
			errorType = strings.Split(err.Error(), ":")[0]
		}
		metrics.RPCCallErrorsCounter.WithLabelValues("eth_getTransactionByHash", c.rpcURL, errorType).Inc()
	}
	
	metrics.RPCCallsCounter.WithLabelValues("eth_getTransactionByHash", c.rpcURL, status).Inc()
	metrics.RPCCallDurationHistogram.WithLabelValues("eth_getTransactionByHash", c.rpcURL).Observe(duration)
	
	return tx, isPending, err
}

// TransactionSender returns the sender address of the given transaction. The transaction
// must be known to the remote node and included in the blockchain at the given block and
// index. The sender is the one derived by the protocol at the time of inclusion.
//
// There is a fast-path for transactions retrieved by TransactionByHash and
// TransactionInBlock. Getting their sender address can be done without an RPC interaction.
func (c *EthClient) TransactionSender(
	ctx context.Context,
	tx *types.Transaction,
	block common.Hash,
	index uint,
) (common.Address, error) {
	start := time.Now()
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, c.timeout)
	defer cancel()

	result, err := c.ethClient.TransactionSender(ctxWithTimeout, tx, block, index)
	
	// Record metrics
	duration := time.Since(start).Seconds()
	status := "success"
	if err != nil {
		status = "error"
		errorType := "unknown"
		if err.Error() != "" {
			errorType = strings.Split(err.Error(), ":")[0]
		}
		metrics.RPCCallErrorsCounter.WithLabelValues("eth_accounts", c.rpcURL, errorType).Inc()
	}
	
	metrics.RPCCallsCounter.WithLabelValues("eth_accounts", c.rpcURL, status).Inc()
	metrics.RPCCallDurationHistogram.WithLabelValues("eth_accounts", c.rpcURL).Observe(duration)
	
	return result, err
}

// TransactionCount returns the total number of transactions in the given block.
func (c *EthClient) TransactionCount(ctx context.Context, blockHash common.Hash) (uint, error) {
	start := time.Now()
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, c.timeout)
	defer cancel()

	result, err := c.ethClient.TransactionCount(ctxWithTimeout, blockHash)
	
	// Record metrics
	duration := time.Since(start).Seconds()
	status := "success"
	if err != nil {
		status = "error"
		errorType := "unknown"
		if err.Error() != "" {
			errorType = strings.Split(err.Error(), ":")[0]
		}
		metrics.RPCCallErrorsCounter.WithLabelValues("eth_getBlockTransactionCountByHash", c.rpcURL, errorType).Inc()
	}
	
	metrics.RPCCallsCounter.WithLabelValues("eth_getBlockTransactionCountByHash", c.rpcURL, status).Inc()
	metrics.RPCCallDurationHistogram.WithLabelValues("eth_getBlockTransactionCountByHash", c.rpcURL).Observe(duration)
	
	return result, err
}

// TransactionInBlock returns a single transaction at index in the given block.
func (c *EthClient) TransactionInBlock(
	ctx context.Context,
	blockHash common.Hash,
	index uint,
) (*types.Transaction, error) {
	start := time.Now()
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, c.timeout)
	defer cancel()

	result, err := c.ethClient.TransactionInBlock(ctxWithTimeout, blockHash, index)
	
	// Record metrics
	duration := time.Since(start).Seconds()
	status := "success"
	if err != nil {
		status = "error"
		errorType := "unknown"
		if err.Error() != "" {
			errorType = strings.Split(err.Error(), ":")[0]
		}
		metrics.RPCCallErrorsCounter.WithLabelValues("eth_getTransactionByBlockHashAndIndex", c.rpcURL, errorType).Inc()
	}
	
	metrics.RPCCallsCounter.WithLabelValues("eth_getTransactionByBlockHashAndIndex", c.rpcURL, status).Inc()
	metrics.RPCCallDurationHistogram.WithLabelValues("eth_getTransactionByBlockHashAndIndex", c.rpcURL).Observe(duration)
	
	return result, err
}

// SyncProgress retrieves the current progress of the sync algorithm. If there's
// no sync currently running, it returns nil.
func (c *EthClient) SyncProgress(ctx context.Context) (*ethereum.SyncProgress, error) {
	start := time.Now()
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, c.timeout)
	defer cancel()

	result, err := c.ethClient.SyncProgress(ctxWithTimeout)
	
	// Record metrics
	duration := time.Since(start).Seconds()
	status := "success"
	if err != nil {
		status = "error"
		errorType := "unknown"
		if err.Error() != "" {
			errorType = strings.Split(err.Error(), ":")[0]
		}
		metrics.RPCCallErrorsCounter.WithLabelValues("eth_syncing", c.rpcURL, errorType).Inc()
	}
	
	metrics.RPCCallsCounter.WithLabelValues("eth_syncing", c.rpcURL, status).Inc()
	metrics.RPCCallDurationHistogram.WithLabelValues("eth_syncing", c.rpcURL).Observe(duration)
	
	return result, err
}

// NetworkID returns the network ID for this client.
func (c *EthClient) NetworkID(ctx context.Context) (*big.Int, error) {
	start := time.Now()
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, c.timeout)
	defer cancel()

	result, err := c.ethClient.NetworkID(ctxWithTimeout)
	
	// Record metrics
	duration := time.Since(start).Seconds()
	status := "success"
	if err != nil {
		status = "error"
		errorType := "unknown"
		if err.Error() != "" {
			errorType = strings.Split(err.Error(), ":")[0]
		}
		metrics.RPCCallErrorsCounter.WithLabelValues("net_version", c.rpcURL, errorType).Inc()
	}
	
	metrics.RPCCallsCounter.WithLabelValues("net_version", c.rpcURL, status).Inc()
	metrics.RPCCallDurationHistogram.WithLabelValues("net_version", c.rpcURL).Observe(duration)
	
	return result, err
}

// BalanceAt returns the wei balance of the given account.
// The block number can be nil, in which case the balance is taken from the latest known block.
func (c *EthClient) BalanceAt(
	ctx context.Context,
	account common.Address,
	blockNumber *big.Int,
) (*big.Int, error) {
	start := time.Now()
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, c.timeout)
	defer cancel()

	result, err := c.ethClient.BalanceAt(ctxWithTimeout, account, blockNumber)
	
	// Record metrics
	duration := time.Since(start).Seconds()
	status := "success"
	if err != nil {
		status = "error"
		errorType := "unknown"
		if err.Error() != "" {
			errorType = strings.Split(err.Error(), ":")[0]
		}
		metrics.RPCCallErrorsCounter.WithLabelValues("eth_getBalance", c.rpcURL, errorType).Inc()
	}
	
	metrics.RPCCallsCounter.WithLabelValues("eth_getBalance", c.rpcURL, status).Inc()
	metrics.RPCCallDurationHistogram.WithLabelValues("eth_getBalance", c.rpcURL).Observe(duration)
	
	return result, err
}

// StorageAt returns the value of key in the contract storage of the given account.
// The block number can be nil, in which case the value is taken from the latest known block.
func (c *EthClient) StorageAt(
	ctx context.Context,
	account common.Address,
	key common.Hash,
	blockNumber *big.Int,
) ([]byte, error) {
	start := time.Now()
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, c.timeout)
	defer cancel()

	result, err := c.ethClient.StorageAt(ctxWithTimeout, account, key, blockNumber)
	
	// Record metrics
	duration := time.Since(start).Seconds()
	status := "success"
	if err != nil {
		status = "error"
		errorType := "unknown"
		if err.Error() != "" {
			errorType = strings.Split(err.Error(), ":")[0]
		}
		metrics.RPCCallErrorsCounter.WithLabelValues("eth_getStorageAt", c.rpcURL, errorType).Inc()
	}
	
	metrics.RPCCallsCounter.WithLabelValues("eth_getStorageAt", c.rpcURL, status).Inc()
	metrics.RPCCallDurationHistogram.WithLabelValues("eth_getStorageAt", c.rpcURL).Observe(duration)
	
	return result, err
}

// CodeAt returns the contract code of the given account.
// The block number can be nil, in which case the code is taken from the latest known block.
func (c *EthClient) CodeAt(
	ctx context.Context,
	account common.Address,
	blockNumber *big.Int,
) ([]byte, error) {
	start := time.Now()
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, c.timeout)
	defer cancel()

	result, err := c.ethClient.CodeAt(ctxWithTimeout, account, blockNumber)
	
	// Record metrics
	duration := time.Since(start).Seconds()
	status := "success"
	if err != nil {
		status = "error"
		errorType := "unknown"
		if err.Error() != "" {
			errorType = strings.Split(err.Error(), ":")[0]
		}
		metrics.RPCCallErrorsCounter.WithLabelValues("eth_getCode", c.rpcURL, errorType).Inc()
	}
	
	metrics.RPCCallsCounter.WithLabelValues("eth_getCode", c.rpcURL, status).Inc()
	metrics.RPCCallDurationHistogram.WithLabelValues("eth_getCode", c.rpcURL).Observe(duration)
	
	return result, err
}

// NonceAt returns the account nonce of the given account.
// The block number can be nil, in which case the nonce is taken from the latest known block.
func (c *EthClient) NonceAt(
	ctx context.Context,
	account common.Address,
	blockNumber *big.Int,
) (uint64, error) {
	start := time.Now()
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, c.timeout)
	defer cancel()

	result, err := c.ethClient.NonceAt(ctxWithTimeout, account, blockNumber)
	
	// Record metrics
	duration := time.Since(start).Seconds()
	status := "success"
	if err != nil {
		status = "error"
		errorType := "unknown"
		if err.Error() != "" {
			errorType = strings.Split(err.Error(), ":")[0]
		}
		metrics.RPCCallErrorsCounter.WithLabelValues("eth_getTransactionCount", c.rpcURL, errorType).Inc()
	}
	
	metrics.RPCCallsCounter.WithLabelValues("eth_getTransactionCount", c.rpcURL, status).Inc()
	metrics.RPCCallDurationHistogram.WithLabelValues("eth_getTransactionCount", c.rpcURL).Observe(duration)
	
	return result, err
}

// PendingBalanceAt returns the wei balance of the given account in the pending state.
func (c *EthClient) PendingBalanceAt(ctx context.Context, account common.Address) (*big.Int, error) {
	start := time.Now()
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, c.timeout)
	defer cancel()

	result, err := c.ethClient.PendingBalanceAt(ctxWithTimeout, account)
	
	// Record metrics
	duration := time.Since(start).Seconds()
	status := "success"
	if err != nil {
		status = "error"
		errorType := "unknown"
		if err.Error() != "" {
			errorType = strings.Split(err.Error(), ":")[0]
		}
		metrics.RPCCallErrorsCounter.WithLabelValues("eth_getBalance", c.rpcURL, errorType).Inc()
	}
	
	metrics.RPCCallsCounter.WithLabelValues("eth_getBalance", c.rpcURL, status).Inc()
	metrics.RPCCallDurationHistogram.WithLabelValues("eth_getBalance", c.rpcURL).Observe(duration)
	
	return result, err
}

// PendingStorageAt returns the value of key in the contract storage of the given account in the pending state.
func (c *EthClient) PendingStorageAt(
	ctx context.Context,
	account common.Address,
	key common.Hash,
) ([]byte, error) {
	start := time.Now()
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, c.timeout)
	defer cancel()

	result, err := c.ethClient.PendingStorageAt(ctxWithTimeout, account, key)
	
	// Record metrics
	duration := time.Since(start).Seconds()
	status := "success"
	if err != nil {
		status = "error"
		errorType := "unknown"
		if err.Error() != "" {
			errorType = strings.Split(err.Error(), ":")[0]
		}
		metrics.RPCCallErrorsCounter.WithLabelValues("eth_getStorageAt", c.rpcURL, errorType).Inc()
	}
	
	metrics.RPCCallsCounter.WithLabelValues("eth_getStorageAt", c.rpcURL, status).Inc()
	metrics.RPCCallDurationHistogram.WithLabelValues("eth_getStorageAt", c.rpcURL).Observe(duration)
	
	return result, err
}

// PendingCodeAt returns the contract code of the given account in the pending state.
func (c *EthClient) PendingCodeAt(ctx context.Context, account common.Address) ([]byte, error) {
	start := time.Now()
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, c.timeout)
	defer cancel()

	result, err := c.ethClient.PendingCodeAt(ctxWithTimeout, account)
	
	// Record metrics
	duration := time.Since(start).Seconds()
	status := "success"
	if err != nil {
		status = "error"
		errorType := "unknown"
		if err.Error() != "" {
			errorType = strings.Split(err.Error(), ":")[0]
		}
		metrics.RPCCallErrorsCounter.WithLabelValues("eth_getCode", c.rpcURL, errorType).Inc()
	}
	
	metrics.RPCCallsCounter.WithLabelValues("eth_getCode", c.rpcURL, status).Inc()
	metrics.RPCCallDurationHistogram.WithLabelValues("eth_getCode", c.rpcURL).Observe(duration)
	
	return result, err
}

// PendingNonceAt returns the account nonce of the given account in the pending state.
// This is the nonce that should be used for the next transaction.
func (c *EthClient) PendingNonceAt(ctx context.Context, account common.Address) (uint64, error) {
	start := time.Now()
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, c.timeout)
	defer cancel()

	result, err := c.ethClient.PendingNonceAt(ctxWithTimeout, account)
	
	// Record metrics
	duration := time.Since(start).Seconds()
	status := "success"
	if err != nil {
		status = "error"
		errorType := "unknown"
		if err.Error() != "" {
			errorType = strings.Split(err.Error(), ":")[0]
		}
		metrics.RPCCallErrorsCounter.WithLabelValues("eth_getTransactionCount", c.rpcURL, errorType).Inc()
	}
	
	metrics.RPCCallsCounter.WithLabelValues("eth_getTransactionCount", c.rpcURL, status).Inc()
	metrics.RPCCallDurationHistogram.WithLabelValues("eth_getTransactionCount", c.rpcURL).Observe(duration)
	
	return result, err
}

// PendingTransactionCount returns the total number of transactions in the pending state.
func (c *EthClient) PendingTransactionCount(ctx context.Context) (uint, error) {
	start := time.Now()
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, c.timeout)
	defer cancel()

	result, err := c.ethClient.PendingTransactionCount(ctxWithTimeout)
	
	// Record metrics
	duration := time.Since(start).Seconds()
	status := "success"
	if err != nil {
		status = "error"
		errorType := "unknown"
		if err.Error() != "" {
			errorType = strings.Split(err.Error(), ":")[0]
		}
		metrics.RPCCallErrorsCounter.WithLabelValues("eth_getBlockTransactionCountByNumber", c.rpcURL, errorType).Inc()
	}
	
	metrics.RPCCallsCounter.WithLabelValues("eth_getBlockTransactionCountByNumber", c.rpcURL, status).Inc()
	metrics.RPCCallDurationHistogram.WithLabelValues("eth_getBlockTransactionCountByNumber", c.rpcURL).Observe(duration)
	
	return result, err
}

// CallContract executes a message call transaction, which is directly executed in the VM
// of the node, but never mined into the blockchain.
//
// blockNumber selects the block height at which the call runs. It can be nil, in which
// case the code is taken from the latest known block. Note that state from very old
// blocks might not be available.
func (c *EthClient) CallContract(
	ctx context.Context,
	msg ethereum.CallMsg,
	blockNumber *big.Int,
) ([]byte, error) {
	start := time.Now()
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, c.timeout)
	defer cancel()

	result, err := c.ethClient.CallContract(ctxWithTimeout, msg, blockNumber)
	
	// Record metrics
	duration := time.Since(start).Seconds()
	status := "success"
	if err != nil {
		status = "error"
		errorType := "unknown"
		if err.Error() != "" {
			errorType = strings.Split(err.Error(), ":")[0]
		}
		metrics.RPCCallErrorsCounter.WithLabelValues("eth_call", c.rpcURL, errorType).Inc()
	}
	
	metrics.RPCCallsCounter.WithLabelValues("eth_call", c.rpcURL, status).Inc()
	metrics.RPCCallDurationHistogram.WithLabelValues("eth_call", c.rpcURL).Observe(duration)
	
	return result, err
}

// CallContractAtHash is almost the same as CallContract except that it selects
// the block by block hash instead of block height.
func (c *EthClient) CallContractAtHash(
	ctx context.Context,
	msg ethereum.CallMsg,
	blockHash common.Hash,
) ([]byte, error) {
	start := time.Now()
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, c.timeout)
	defer cancel()

	result, err := c.ethClient.CallContractAtHash(ctxWithTimeout, msg, blockHash)
	
	// Record metrics
	duration := time.Since(start).Seconds()
	status := "success"
	if err != nil {
		status = "error"
		errorType := "unknown"
		if err.Error() != "" {
			errorType = strings.Split(err.Error(), ":")[0]
		}
		metrics.RPCCallErrorsCounter.WithLabelValues("eth_call", c.rpcURL, errorType).Inc()
	}
	
	metrics.RPCCallsCounter.WithLabelValues("eth_call", c.rpcURL, status).Inc()
	metrics.RPCCallDurationHistogram.WithLabelValues("eth_call", c.rpcURL).Observe(duration)
	
	return result, err
}

// PendingCallContract executes a message call transaction using the EVM.
// The state seen by the contract call is the pending state.
func (c *EthClient) PendingCallContract(ctx context.Context, msg ethereum.CallMsg) ([]byte, error) {
	start := time.Now()
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, c.timeout)
	defer cancel()

	result, err := c.ethClient.PendingCallContract(ctxWithTimeout, msg)
	
	// Record metrics
	duration := time.Since(start).Seconds()
	status := "success"
	if err != nil {
		status = "error"
		errorType := "unknown"
		if err.Error() != "" {
			errorType = strings.Split(err.Error(), ":")[0]
		}
		metrics.RPCCallErrorsCounter.WithLabelValues("eth_call", c.rpcURL, errorType).Inc()
	}
	
	metrics.RPCCallsCounter.WithLabelValues("eth_call", c.rpcURL, status).Inc()
	metrics.RPCCallDurationHistogram.WithLabelValues("eth_call", c.rpcURL).Observe(duration)
	
	return result, err
}

// SuggestGasPrice retrieves the currently suggested gas price to allow a timely
// execution of a transaction.
func (c *EthClient) SuggestGasPrice(ctx context.Context) (*big.Int, error) {
	start := time.Now()
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, c.timeout)
	defer cancel()

	result, err := c.ethClient.SuggestGasPrice(ctxWithTimeout)
	
	// Record metrics
	duration := time.Since(start).Seconds()
	status := "success"
	if err != nil {
		status = "error"
		errorType := "unknown"
		if err.Error() != "" {
			errorType = strings.Split(err.Error(), ":")[0]
		}
		metrics.RPCCallErrorsCounter.WithLabelValues("eth_gasPrice", c.rpcURL, errorType).Inc()
	}
	
	metrics.RPCCallsCounter.WithLabelValues("eth_gasPrice", c.rpcURL, status).Inc()
	metrics.RPCCallDurationHistogram.WithLabelValues("eth_gasPrice", c.rpcURL).Observe(duration)
	
	return result, err
}

// SuggestGasTipCap retrieves the currently suggested gas tip cap after 1559 to
// allow a timely execution of a transaction.
func (c *EthClient) SuggestGasTipCap(ctx context.Context) (*big.Int, error) {
	start := time.Now()
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, c.timeout)
	defer cancel()

	result, err := c.ethClient.SuggestGasTipCap(ctxWithTimeout)
	
	// Record metrics
	duration := time.Since(start).Seconds()
	status := "success"
	if err != nil {
		status = "error"
		errorType := "unknown"
		if err.Error() != "" {
			errorType = strings.Split(err.Error(), ":")[0]
		}
		metrics.RPCCallErrorsCounter.WithLabelValues("eth_maxPriorityFeePerGas", c.rpcURL, errorType).Inc()
	}
	
	metrics.RPCCallsCounter.WithLabelValues("eth_maxPriorityFeePerGas", c.rpcURL, status).Inc()
	metrics.RPCCallDurationHistogram.WithLabelValues("eth_maxPriorityFeePerGas", c.rpcURL).Observe(duration)
	
	return result, err
}

// FeeHistory retrieves the fee market history.
func (c *EthClient) FeeHistory(
	ctx context.Context,
	blockCount uint64,
	lastBlock *big.Int,
	rewardPercentiles []float64,
) (*ethereum.FeeHistory, error) {
	start := time.Now()
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, c.timeout)
	defer cancel()

	result, err := c.ethClient.FeeHistory(ctxWithTimeout, blockCount, lastBlock, rewardPercentiles)
	
	// Record metrics
	duration := time.Since(start).Seconds()
	status := "success"
	if err != nil {
		status = "error"
		errorType := "unknown"
		if err.Error() != "" {
			errorType = strings.Split(err.Error(), ":")[0]
		}
		metrics.RPCCallErrorsCounter.WithLabelValues("eth_feeHistory", c.rpcURL, errorType).Inc()
	}
	
	metrics.RPCCallsCounter.WithLabelValues("eth_feeHistory", c.rpcURL, status).Inc()
	metrics.RPCCallDurationHistogram.WithLabelValues("eth_feeHistory", c.rpcURL).Observe(duration)
	
	return result, err
}

// EstimateGas tries to estimate the gas needed to execute a specific transaction based on
// the current pending state of the backend blockchain. There is no guarantee that this is
// the true gas limit requirement as other transactions may be added or removed by miners,
// but it should provide a basis for setting a reasonable default.
func (c *EthClient) EstimateGas(ctx context.Context, msg ethereum.CallMsg) (uint64, error) {
	start := time.Now()
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, c.timeout)
	defer cancel()

	result, err := c.ethClient.EstimateGas(ctxWithTimeout, msg)
	
	// Record metrics
	duration := time.Since(start).Seconds()
	status := "success"
	if err != nil {
		status = "error"
		errorType := "unknown"
		if err.Error() != "" {
			errorType = strings.Split(err.Error(), ":")[0]
		}
		metrics.RPCCallErrorsCounter.WithLabelValues("eth_estimateGas", c.rpcURL, errorType).Inc()
	}
	
	metrics.RPCCallsCounter.WithLabelValues("eth_estimateGas", c.rpcURL, status).Inc()
	metrics.RPCCallDurationHistogram.WithLabelValues("eth_estimateGas", c.rpcURL).Observe(duration)
	
	return result, err
}

// SendTransaction injects a signed transaction into the pending pool for execution.
//
// If the transaction was a contract creation use the TransactionReceipt method to get the
// contract address after the transaction has been mined.
func (c *EthClient) SendTransaction(ctx context.Context, tx *types.Transaction) error {
	start := time.Now()
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, c.timeout)
	defer cancel()

	err := c.ethClient.SendTransaction(ctxWithTimeout, tx)
	
	// Record metrics
	duration := time.Since(start).Seconds()
	status := "success"
	if err != nil {
		status = "error"
		errorType := "unknown"
		if err.Error() != "" {
			errorType = strings.Split(err.Error(), ":")[0]
		}
		metrics.RPCCallErrorsCounter.WithLabelValues("eth_sendRawTransaction", c.rpcURL, errorType).Inc()
	}
	
	metrics.RPCCallsCounter.WithLabelValues("eth_sendRawTransaction", c.rpcURL, status).Inc()
	metrics.RPCCallDurationHistogram.WithLabelValues("eth_sendRawTransaction", c.rpcURL).Observe(duration)
	
	return err
}

// TransactionArgs represents the arguments to construct a new transaction
// or a message call.
type TransactionArgs struct {
	From                 *common.Address `json:"from"`
	To                   *common.Address `json:"to"`
	Gas                  *hexutil.Uint64 `json:"gas"`
	GasPrice             *hexutil.Big    `json:"gasPrice"`
	MaxFeePerGas         *hexutil.Big    `json:"maxFeePerGas"`
	MaxPriorityFeePerGas *hexutil.Big    `json:"maxPriorityFeePerGas"`
	Value                *hexutil.Big    `json:"value"`
	Nonce                *hexutil.Uint64 `json:"nonce"`

	// We accept "data" and "input" for backwards-compatibility reasons.
	// "input" is the newer name and should be preferred by clients.
	// Issue detail: https://github.com/ethereum/go-ethereum/issues/15628
	Data  *hexutil.Bytes `json:"data"`
	Input *hexutil.Bytes `json:"input"`

	// Introduced by AccessListTxType transaction.
	AccessList *types.AccessList `json:"accessList,omitempty"`
	ChainID    *hexutil.Big      `json:"chainId,omitempty"`

	// Introduced by EIP-4844.
	BlobFeeCap *hexutil.Big  `json:"maxFeePerBlobGas"`
	BlobHashes []common.Hash `json:"blobVersionedHashes,omitempty"`
}

// SignTransactionResult represents a RLP encoded signed transaction.
type SignTransactionResult struct {
	Raw hexutil.Bytes      `json:"raw"`
	Tx  *types.Transaction `json:"tx"`
}

// FillTransaction fills in the missing fields of a transaction and signs it.
func (c *EthClient) FillTransaction(ctx context.Context, args *TransactionArgs) (*types.Transaction, error) {
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, c.timeout)
	defer cancel()

	var result SignTransactionResult
	err := c.CallContext(ctxWithTimeout, &result, "eth_fillTransaction", *args)
	if err != nil {
		return nil, err
	}

	return result.Tx, nil
}
