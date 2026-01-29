package rpc

import (
	"context"
	"errors"
	"math/big"
	"time"

	"github.com/ethereum/go-ethereum/beacon/engine"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/common/hexutil"
	"github.com/ethereum/go-ethereum/core/rawdb"
	"github.com/ethereum/go-ethereum/miner"
	"github.com/ethereum/go-ethereum/node"
	"github.com/ethereum/go-ethereum/rpc"
)

// EngineClient represents a RPC client connecting to an Ethereum Engine API
// endpoint.
// ref: https://github.com/ethereum/execution-apis/blob/main/src/engine/shanghai.md
type EngineClient struct {
	*rpc.Client
	rpcURL string
}

// CallContext wraps the underlying RPC client's CallContext with metrics tracking.
func (c *EngineClient) CallContext(ctx context.Context, result interface{}, method string, args ...interface{}) error {
	start := time.Now()
	err := c.Client.CallContext(ctx, result, method, args...)
	recordRPCMetrics(method, c.rpcURL, start, err)
	return err
}

// NewJWTEngineClient creates a new EngineClient with JWT authentication.
func NewJWTEngineClient(url, jwtSecret string) (*EngineClient, error) {
	var jwt = StringToBytes32(jwtSecret)
	if jwt == (common.Hash{}) || url == "" {
		return nil, errors.New("url is empty or jwt secret is illegal")
	}
	authClient, err := rpc.DialOptions(context.Background(), url, rpc.WithHTTPAuth(node.NewJWTAuth(jwt)))
	if err != nil {
		return nil, err
	}

	return &EngineClient{
		Client: authClient,
		rpcURL: url,
	}, nil
}

// ForkchoiceUpdate updates the forkchoice on the execution client.
func (c *EngineClient) ForkchoiceUpdate(
	ctx context.Context,
	fc *engine.ForkchoiceStateV1,
	attributes *engine.PayloadAttributes,
) (*engine.ForkChoiceResponse, error) {
	timeoutCtx, cancel := context.WithTimeout(ctx, DefaultRpcTimeout)
	defer cancel()

	var result *engine.ForkChoiceResponse
	if err := c.CallContext(timeoutCtx, &result, "engine_forkchoiceUpdatedV2", fc, attributes); err != nil {
		return nil, err
	}

	return result, nil
}

// NewPayload executes a built block on the execution engine.
func (c *EngineClient) NewPayload(
	ctx context.Context,
	payload *engine.ExecutableData,
) (*engine.PayloadStatusV1, error) {
	timeoutCtx, cancel := context.WithTimeout(ctx, DefaultRpcTimeout)
	defer cancel()

	var result *engine.PayloadStatusV1
	if err := c.CallContext(timeoutCtx, &result, "engine_newPayloadV2", payload); err != nil {
		return nil, err
	}

	return result, nil
}

// GetPayload gets the execution payload associated with the payload ID.
func (c *EngineClient) GetPayload(
	ctx context.Context,
	payloadID *engine.PayloadID,
) (*engine.ExecutableData, error) {
	timeoutCtx, cancel := context.WithTimeout(ctx, DefaultRpcTimeout)
	defer cancel()

	var result *engine.ExecutionPayloadEnvelope
	if err := c.CallContext(timeoutCtx, &result, "engine_getPayloadV2", payloadID); err != nil {
		return nil, err
	}

	return result.ExecutionPayload, nil
}

// ExchangeTransitionConfiguration exchanges transition configs with the L2 execution engine.
func (c *EngineClient) ExchangeTransitionConfiguration(
	ctx context.Context,
	cfg *engine.TransitionConfigurationV1,
) (*engine.TransitionConfigurationV1, error) {
	timeoutCtx, cancel := context.WithTimeout(ctx, DefaultRpcTimeout)
	defer cancel()

	var result *engine.TransitionConfigurationV1
	if err := c.CallContext(timeoutCtx, &result, "engine_exchangeTransitionConfigurationV1", cfg); err != nil {
		return nil, err
	}

	return result, nil
}

// TxPoolContentWithMinTip fetches the transaction pool content from the L2 execution engine.
func (c *EngineClient) TxPoolContentWithMinTip(
	ctx context.Context,
	beneficiary common.Address,
	baseFee *big.Int,
	blockMaxGasLimit uint64,
	maxBytesPerTxList uint64,
	locals []string,
	maxTransactionsLists uint64,
	minTip uint64,
) ([]*miner.PreBuiltTxList, error) {
	timeoutCtx, cancel := context.WithTimeout(ctx, DefaultRpcTimeout)
	defer cancel()
	var result []*miner.PreBuiltTxList

	if err := c.CallContext(
		timeoutCtx,
		&result,
		"taikoAuth_txPoolContentWithMinTip",
		beneficiary,
		baseFee,
		blockMaxGasLimit,
		maxBytesPerTxList,
		locals,
		maxTransactionsLists,
		minTip,
	); err != nil {
		return nil, err
	}
	return result, nil
}

// UpdateL1Origin sets the L2 block's corresponding L1 origin.
func (c *EngineClient) UpdateL1Origin(ctx context.Context, l1Origin *rawdb.L1Origin) (*rawdb.L1Origin, error) {
	var res *rawdb.L1Origin

	if err := c.CallContext(ctx, &res, "taikoAuth_updateL1Origin", l1Origin); err != nil {
		return nil, err
	}

	return res, nil
}

// SetL1OriginSignature sets the L2 block's corresponding L1 origin signature of the envelope
func (c *EngineClient) SetL1OriginSignature(
	ctx context.Context,
	blockID *big.Int,
	signature [65]byte,
) (*rawdb.L1Origin, error) {
	var res *rawdb.L1Origin

	if err := c.CallContext(ctx, &res, "taikoAuth_setL1OriginSignature", blockID, signature); err != nil {
		return nil, err
	}

	return res, nil
}

// SetHeadL1Origin sets the latest L2 block's corresponding L1 origin.
func (c *EngineClient) SetHeadL1Origin(ctx context.Context, blockID *big.Int) (*big.Int, error) {
	var res hexutil.Big

	if err := c.CallContext(ctx, &res, "taikoAuth_setHeadL1Origin", blockID); err != nil {
		return nil, err
	}

	return (*big.Int)(&res), nil
}

// SetBatchToLastBlock sets the batch to block mapping in the execution engine.
func (c *EngineClient) SetBatchToLastBlock(ctx context.Context, batchID *big.Int, blockID *big.Int) (*big.Int, error) {
	var res hexutil.Big

	if err := c.CallContext(ctx, &res, "taikoAuth_setBatchToLastBlock", batchID, blockID); err != nil {
		return nil, err
	}

	return (*big.Int)(&res), nil
}

// LastL1OriginByBatchID returns the L1 origin of the last block for the given batch.
func (c *EngineClient) LastL1OriginByBatchID(ctx context.Context, batchID *big.Int) (*rawdb.L1Origin, error) {
	var res *rawdb.L1Origin

	if err := c.CallContext(ctx, &res, "taikoAuth_lastL1OriginByBatchID", hexutil.EncodeBig(batchID)); err != nil {
		return nil, err
	}

	return res, nil
}

// LastBlockIDByBatchID returns the ID of the last block for the given batch.
func (c *EngineClient) LastBlockIDByBatchID(ctx context.Context, batchID *big.Int) (*hexutil.Big, error) {
	var res *hexutil.Big

	if err := c.CallContext(ctx, &res, "taikoAuth_lastBlockIDByBatchID", hexutil.EncodeBig(batchID)); err != nil {
		return nil, err
	}

	return res, nil
}
