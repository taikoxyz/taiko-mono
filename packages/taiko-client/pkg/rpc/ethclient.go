package rpc

import (
	"context"
	"errors"
	"fmt"
	"math/big"
	"time"

	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/common/hexutil"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/ethereum/go-ethereum/ethclient/gethclient"
	"github.com/ethereum/go-ethereum/rpc"
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
	metrics *RPCMetrics
}

// NewEthClient creates a new EthClient instance.
func NewEthClient(ctx context.Context, url string, timeout time.Duration) (*EthClient, error) {
	return NewEthClientWithType(ctx, url, timeout, "eth")
}

// NewEthClientWithType creates a new EthClient instance with a specific client type for metrics.
func NewEthClientWithType(ctx context.Context, url string, timeout time.Duration, clientType string) (*EthClient, error) {
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
		metrics:    NewRPCMetrics(clientType),
	}, nil
}

func (c *EthClient) EthClient() *ethclient.Client {
	return c.ethClient.Client
}

// BlockByHash returns the given full block.
//
// Note that loading full blocks requires two requests. Use HeaderByHash
// if you don't need all transactions or uncle headers.
func (c *EthClient) BlockByHash(ctx context.Context, hash common.Hash) (*types.Block, error) {
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, c.timeout)
	defer cancel()

	var result *types.Block
	err := c.metrics.TrackRequest(ctxWithTimeout, "eth_getBlockByHash", func() error {
		var innerErr error
		result, innerErr = c.ethClient.BlockByHash(ctxWithTimeout, hash)
		return innerErr
	})
	return result, err
}

// BatchBlocksByHashes requests multiple blocks by their hashes in a batch.
func (c *EthClient) BatchBlocksByHashes(ctx context.Context, hashes []common.Hash) ([]*types.Block, error) {
	if len(hashes) < 1 {
		return nil, ErrInvalidLenOfParams
	}
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, c.timeout)
	defer cancel()

	var results []*types.Block
	err := c.metrics.TrackRequest(ctxWithTimeout, "batch_getBlockByHash", func() error {
		reqs := make([]rpc.BatchElem, len(hashes))
		results = make([]*types.Block, len(hashes))
		for i, hash := range hashes {
			reqs[i] = rpc.BatchElem{
				Method: "eth_getBlockByHash",
				Args:   []interface{}{hash, true},
				Result: &results[i],
			}
		}
		if err := c.BatchCallContext(ctxWithTimeout, reqs); err != nil {
			return err
		}
		for i := range reqs {
			if reqs[i].Error != nil {
				return reqs[i].Error
			}
		}
		return nil
	})
	return results, err
}

// BlockByNumber returns a block from the current canonical chain. If number is nil, the
// latest known block is returned.
//
// Note that loading full blocks requires two requests. Use HeaderByNumber
// if you don't need all transactions or uncle headers.
func (c *EthClient) BlockByNumber(ctx context.Context, number *big.Int) (*types.Block, error) {
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, c.timeout)
	defer cancel()

	var result *types.Block
	err := c.metrics.TrackRequest(ctxWithTimeout, "eth_getBlockByNumber", func() error {
		var innerErr error
		result, innerErr = c.ethClient.BlockByNumber(ctxWithTimeout, number)
		return innerErr
	})
	return result, err
}

// BlockNumber returns the most recent block number
func (c *EthClient) BlockNumber(ctx context.Context) (uint64, error) {
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, c.timeout)
	defer cancel()

	var result uint64
	err := c.metrics.TrackRequest(ctxWithTimeout, "eth_blockNumber", func() error {
		var innerErr error
		result, innerErr = c.ethClient.BlockNumber(ctxWithTimeout)
		return innerErr
	})
	return result, err
}

// PeerCount returns the number of p2p peers as reported by the net_peerCount method.
func (c *EthClient) PeerCount(ctx context.Context) (uint64, error) {
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, c.timeout)
	defer cancel()

	var result uint64
	err := c.metrics.TrackRequest(ctxWithTimeout, "net_peerCount", func() error {
		var innerErr error
		result, innerErr = c.ethClient.PeerCount(ctxWithTimeout)
		return innerErr
	})
	return result, err
}

// HeaderByHash returns the block header with the given hash.
func (c *EthClient) HeaderByHash(ctx context.Context, hash common.Hash) (*types.Header, error) {
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, c.timeout)
	defer cancel()

	var result *types.Header
	err := c.metrics.TrackRequest(ctxWithTimeout, "eth_getBlockByHash", func() error {
		var innerErr error
		result, innerErr = c.ethClient.HeaderByHash(ctxWithTimeout, hash)
		return innerErr
	})
	return result, err
}

// HeaderByNumber returns a block header from the current canonical chain. If number is
// nil, the latest known header is returned.
func (c *EthClient) HeaderByNumber(ctx context.Context, number *big.Int) (*types.Header, error) {
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, c.timeout)
	defer cancel()

	var result *types.Header
	err := c.metrics.TrackRequest(ctxWithTimeout, "eth_getBlockByNumber", func() error {
		var innerErr error
		result, innerErr = c.ethClient.HeaderByNumber(ctxWithTimeout, number)
		return innerErr
	})
	return result, err
}

func (c *EthClient) BatchHeadersByNumbers(ctx context.Context, numbers []*big.Int) ([]*types.Header, error) {
	if len(numbers) < 1 {
		return nil, ErrInvalidLenOfParams
	}
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, c.timeout)
	defer cancel()

	var results []*types.Header
	err := c.metrics.TrackRequest(ctxWithTimeout, "batch_getBlockByNumber", func() error {
		reqs := make([]rpc.BatchElem, len(numbers))
		results = make([]*types.Header, len(numbers))
		for i, blockNum := range numbers {
			reqs[i] = rpc.BatchElem{
				Method: "eth_getBlockByNumber",
				Args:   []interface{}{toBlockNumArg(blockNum), false},
				Result: &results[i],
			}
		}
		if err := c.BatchCallContext(ctxWithTimeout, reqs); err != nil {
			return err
		}
		for i := range reqs {
			if reqs[i].Error != nil {
				return reqs[i].Error
			}
		}
		return nil
	})
	return results, err
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
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, c.timeout)
	defer cancel()

	err = c.metrics.TrackRequest(ctxWithTimeout, "eth_getTransactionByHash", func() error {
		tx, isPending, err = c.ethClient.TransactionByHash(ctxWithTimeout, hash)
		return err
	})
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
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, c.timeout)
	defer cancel()

	var result common.Address
	err := c.metrics.TrackRequest(ctxWithTimeout, "eth_getTransactionSender", func() error {
		var innerErr error
		result, innerErr = c.ethClient.TransactionSender(ctxWithTimeout, tx, block, index)
		return innerErr
	})
	return result, err
}

// TransactionCount returns the total number of transactions in the given block.
func (c *EthClient) TransactionCount(ctx context.Context, blockHash common.Hash) (uint, error) {
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, c.timeout)
	defer cancel()

	var result uint
	err := c.metrics.TrackRequest(ctxWithTimeout, "eth_getBlockTransactionCount", func() error {
		var innerErr error
		result, innerErr = c.ethClient.TransactionCount(ctxWithTimeout, blockHash)
		return innerErr
	})
	return result, err
}

// TransactionInBlock returns a single transaction at index in the given block.
func (c *EthClient) TransactionInBlock(
	ctx context.Context,
	blockHash common.Hash,
	index uint,
) (*types.Transaction, error) {
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, c.timeout)
	defer cancel()

	var result *types.Transaction
	err := c.metrics.TrackRequest(ctxWithTimeout, "eth_getTransactionByBlockHashAndIndex", func() error {
		var innerErr error
		result, innerErr = c.ethClient.TransactionInBlock(ctxWithTimeout, blockHash, index)
		return innerErr
	})
	return result, err
}

// SyncProgress retrieves the current progress of the sync algorithm. If there's
// no sync currently running, it returns nil.
func (c *EthClient) SyncProgress(ctx context.Context) (*ethereum.SyncProgress, error) {
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, c.timeout)
	defer cancel()

	var result *ethereum.SyncProgress
	err := c.metrics.TrackRequest(ctxWithTimeout, "eth_syncing", func() error {
		var innerErr error
		result, innerErr = c.ethClient.SyncProgress(ctxWithTimeout)
		return innerErr
	})
	return result, err
}

// NetworkID returns the network ID for this client.
func (c *EthClient) NetworkID(ctx context.Context) (*big.Int, error) {
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, c.timeout)
	defer cancel()

	var result *big.Int
	err := c.metrics.TrackRequest(ctxWithTimeout, "net_version", func() error {
		var innerErr error
		result, innerErr = c.ethClient.NetworkID(ctxWithTimeout)
		return innerErr
	})
	return result, err
}

// BalanceAt returns the wei balance of the given account.
// The block number can be nil, in which case the balance is taken from the latest known block.
func (c *EthClient) BalanceAt(
	ctx context.Context,
	account common.Address,
	blockNumber *big.Int,
) (*big.Int, error) {
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, c.timeout)
	defer cancel()

	var result *big.Int
	err := c.metrics.TrackRequest(ctxWithTimeout, "eth_getBalance", func() error {
		var innerErr error
		result, innerErr = c.ethClient.BalanceAt(ctxWithTimeout, account, blockNumber)
		return innerErr
	})
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
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, c.timeout)
	defer cancel()

	var result []byte
	err := c.metrics.TrackRequest(ctxWithTimeout, "eth_getStorageAt", func() error {
		var innerErr error
		result, innerErr = c.ethClient.StorageAt(ctxWithTimeout, account, key, blockNumber)
		return innerErr
	})
	return result, err
}

// CodeAt returns the contract code of the given account.
// The block number can be nil, in which case the code is taken from the latest known block.
func (c *EthClient) CodeAt(
	ctx context.Context,
	account common.Address,
	blockNumber *big.Int,
) ([]byte, error) {
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, c.timeout)
	defer cancel()

	var result []byte
	err := c.metrics.TrackRequest(ctxWithTimeout, "eth_getCode", func() error {
		var innerErr error
		result, innerErr = c.ethClient.CodeAt(ctxWithTimeout, account, blockNumber)
		return innerErr
	})
	return result, err
}

// NonceAt returns the account nonce of the given account.
// The block number can be nil, in which case the nonce is taken from the latest known block.
func (c *EthClient) NonceAt(
	ctx context.Context,
	account common.Address,
	blockNumber *big.Int,
) (uint64, error) {
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, c.timeout)
	defer cancel()

	var result uint64
	err := c.metrics.TrackRequest(ctxWithTimeout, "eth_getTransactionCount", func() error {
		var innerErr error
		result, innerErr = c.ethClient.NonceAt(ctxWithTimeout, account, blockNumber)
		return innerErr
	})
	return result, err
}

// PendingBalanceAt returns the wei balance of the given account in the pending state.
func (c *EthClient) PendingBalanceAt(ctx context.Context, account common.Address) (*big.Int, error) {
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, c.timeout)
	defer cancel()

	var result *big.Int
	err := c.metrics.TrackRequest(ctxWithTimeout, "eth_getBalance", func() error {
		var innerErr error
		result, innerErr = c.ethClient.PendingBalanceAt(ctxWithTimeout, account)
		return innerErr
	})
	return result, err
}

// PendingStorageAt returns the value of key in the contract storage of the given account in the pending state.
func (c *EthClient) PendingStorageAt(
	ctx context.Context,
	account common.Address,
	key common.Hash,
) ([]byte, error) {
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, c.timeout)
	defer cancel()

	var result []byte
	err := c.metrics.TrackRequest(ctxWithTimeout, "eth_getStorageAt", func() error {
		var innerErr error
		result, innerErr = c.ethClient.PendingStorageAt(ctxWithTimeout, account, key)
		return innerErr
	})
	return result, err
}

// PendingCodeAt returns the contract code of the given account in the pending state.
func (c *EthClient) PendingCodeAt(ctx context.Context, account common.Address) ([]byte, error) {
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, c.timeout)
	defer cancel()

	var result []byte
	err := c.metrics.TrackRequest(ctxWithTimeout, "eth_getCode", func() error {
		var innerErr error
		result, innerErr = c.ethClient.PendingCodeAt(ctxWithTimeout, account)
		return innerErr
	})
	return result, err
}

// PendingNonceAt returns the account nonce of the given account in the pending state.
// This is the nonce that should be used for the next transaction.
func (c *EthClient) PendingNonceAt(ctx context.Context, account common.Address) (uint64, error) {
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, c.timeout)
	defer cancel()

	var result uint64
	err := c.metrics.TrackRequest(ctxWithTimeout, "eth_getTransactionCount", func() error {
		var innerErr error
		result, innerErr = c.ethClient.PendingNonceAt(ctxWithTimeout, account)
		return innerErr
	})
	return result, err
}

// PendingTransactionCount returns the total number of transactions in the pending state.
func (c *EthClient) PendingTransactionCount(ctx context.Context) (uint, error) {
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, c.timeout)
	defer cancel()

	var result uint
	err := c.metrics.TrackRequest(ctxWithTimeout, "eth_getTransactionCount", func() error {
		var innerErr error
		result, innerErr = c.ethClient.PendingTransactionCount(ctxWithTimeout)
		return innerErr
	})
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
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, c.timeout)
	defer cancel()

	var result []byte
	err := c.metrics.TrackRequest(ctxWithTimeout, "eth_call", func() error {
		var innerErr error
		result, innerErr = c.ethClient.CallContract(ctxWithTimeout, msg, blockNumber)
		return innerErr
	})
	return result, err
}

// CallContractAtHash is almost the same as CallContract except that it selects
// the block by block hash instead of block height.
func (c *EthClient) CallContractAtHash(
	ctx context.Context,
	msg ethereum.CallMsg,
	blockHash common.Hash,
) ([]byte, error) {
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, c.timeout)
	defer cancel()

	var result []byte
	err := c.metrics.TrackRequest(ctxWithTimeout, "eth_call", func() error {
		var innerErr error
		result, innerErr = c.ethClient.CallContractAtHash(ctxWithTimeout, msg, blockHash)
		return innerErr
	})
	return result, err
}

// PendingCallContract executes a message call transaction using the EVM.
// The state seen by the contract call is the pending state.
func (c *EthClient) PendingCallContract(ctx context.Context, msg ethereum.CallMsg) ([]byte, error) {
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, c.timeout)
	defer cancel()

	var result []byte
	err := c.metrics.TrackRequest(ctxWithTimeout, "eth_call", func() error {
		var innerErr error
		result, innerErr = c.ethClient.PendingCallContract(ctxWithTimeout, msg)
		return innerErr
	})
	return result, err
}

// SuggestGasPrice retrieves the currently suggested gas price to allow a timely
// execution of a transaction.
func (c *EthClient) SuggestGasPrice(ctx context.Context) (*big.Int, error) {
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, c.timeout)
	defer cancel()

	var result *big.Int
	err := c.metrics.TrackRequest(ctxWithTimeout, "eth_gasPrice", func() error {
		var innerErr error
		result, innerErr = c.ethClient.SuggestGasPrice(ctxWithTimeout)
		return innerErr
	})
	return result, err
}

// SuggestGasTipCap retrieves the currently suggested gas tip cap after 1559 to
// allow a timely execution of a transaction.
func (c *EthClient) SuggestGasTipCap(ctx context.Context) (*big.Int, error) {
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, c.timeout)
	defer cancel()

	var result *big.Int
	err := c.metrics.TrackRequest(ctxWithTimeout, "eth_maxPriorityFeePerGas", func() error {
		var innerErr error
		result, innerErr = c.ethClient.SuggestGasTipCap(ctxWithTimeout)
		return innerErr
	})
	return result, err
}

// FeeHistory retrieves the fee market history.
func (c *EthClient) FeeHistory(
	ctx context.Context,
	blockCount uint64,
	lastBlock *big.Int,
	rewardPercentiles []float64,
) (*ethereum.FeeHistory, error) {
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, c.timeout)
	defer cancel()

	var result *ethereum.FeeHistory
	err := c.metrics.TrackRequest(ctxWithTimeout, "eth_feeHistory", func() error {
		var innerErr error
		result, innerErr = c.ethClient.FeeHistory(ctxWithTimeout, blockCount, lastBlock, rewardPercentiles)
		return innerErr
	})
	return result, err
}

// EstimateGas tries to estimate the gas needed to execute a specific transaction based on
// the current pending state of the backend blockchain. There is no guarantee that this is
// the true gas limit requirement as other transactions may be added or removed by miners,
// but it should provide a basis for setting a reasonable default.
func (c *EthClient) EstimateGas(ctx context.Context, msg ethereum.CallMsg) (uint64, error) {
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, c.timeout)
	defer cancel()

	var result uint64
	err := c.metrics.TrackRequest(ctxWithTimeout, "eth_estimateGas", func() error {
		var innerErr error
		result, innerErr = c.ethClient.EstimateGas(ctxWithTimeout, msg)
		return innerErr
	})
	return result, err
}

// SendTransaction injects a signed transaction into the pending pool for execution.
//
// If the transaction was a contract creation use the TransactionReceipt method to get the
// contract address after the transaction has been mined.
func (c *EthClient) SendTransaction(ctx context.Context, tx *types.Transaction) error {
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, c.timeout)
	defer cancel()

	return c.metrics.TrackRequest(ctxWithTimeout, "eth_sendTransaction", func() error {
		return c.ethClient.SendTransaction(ctxWithTimeout, tx)
	})
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

	var result *types.Transaction
	err := c.metrics.TrackRequest(ctxWithTimeout, "eth_fillTransaction", func() error {
		var signResult SignTransactionResult
		err := c.CallContext(ctxWithTimeout, &signResult, "eth_fillTransaction", *args)
		if err != nil {
			return err
		}
		result = signResult.Tx
		return nil
	})
	return result, err
}
