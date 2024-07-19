package rpc

import (
	"context"
	"errors"
	"math/big"

	"github.com/ethereum/go-ethereum/beacon/engine"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/miner"
	"github.com/ethereum/go-ethereum/node"
	"github.com/ethereum/go-ethereum/rpc"
)

// EngineClient represents a RPC client connecting to an Ethereum Engine API
// endpoint.
// ref: https://github.com/ethereum/execution-apis/blob/main/src/engine/shanghai.md
type EngineClient struct {
	*rpc.Client
}

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
	}, nil
}

// ForkchoiceUpdate updates the forkchoice on the execution client.
func (c *EngineClient) ForkchoiceUpdate(
	ctx context.Context,
	fc *engine.ForkchoiceStateV1,
	attributes *engine.PayloadAttributes,
) (*engine.ForkChoiceResponse, error) {
	timeoutCtx, cancel := context.WithTimeout(ctx, defaultTimeout)
	defer cancel()

	var result *engine.ForkChoiceResponse
	if err := c.Client.CallContext(timeoutCtx, &result, "engine_forkchoiceUpdatedV2", fc, attributes); err != nil {
		return nil, err
	}

	return result, nil
}

// NewPayload executes a built block on the execution engine.
func (c *EngineClient) NewPayload(
	ctx context.Context,
	payload *engine.ExecutableData,
) (*engine.PayloadStatusV1, error) {
	timeoutCtx, cancel := context.WithTimeout(ctx, defaultTimeout)
	defer cancel()

	var result *engine.PayloadStatusV1
	if err := c.Client.CallContext(timeoutCtx, &result, "engine_newPayloadV2", payload); err != nil {
		return nil, err
	}

	return result, nil
}

// GetPayload gets the execution payload associated with the payload ID.
func (c *EngineClient) GetPayload(
	ctx context.Context,
	payloadID *engine.PayloadID,
) (*engine.ExecutableData, error) {
	timeoutCtx, cancel := context.WithTimeout(ctx, defaultTimeout)
	defer cancel()

	var result *engine.ExecutionPayloadEnvelope
	if err := c.Client.CallContext(timeoutCtx, &result, "engine_getPayloadV2", payloadID); err != nil {
		return nil, err
	}

	return result.ExecutionPayload, nil
}

// ExchangeTransitionConfiguration exchanges transition configs with the L2 execution engine.
func (c *EngineClient) ExchangeTransitionConfiguration(
	ctx context.Context,
	cfg *engine.TransitionConfigurationV1,
) (*engine.TransitionConfigurationV1, error) {
	timeoutCtx, cancel := context.WithTimeout(ctx, defaultTimeout)
	defer cancel()

	var result *engine.TransitionConfigurationV1
	if err := c.Client.CallContext(timeoutCtx, &result, "engine_exchangeTransitionConfigurationV1", cfg); err != nil {
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
	timeoutCtx, cancel := context.WithTimeout(ctx, defaultTimeout)
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
