package rpc

import (
	"context"
	"errors"
	"math/big"

	"github.com/ethereum/go-ethereum/beacon/engine"
	"github.com/ethereum/go-ethereum/common"
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
	metrics *RPCMetrics
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
		Client:  authClient,
		metrics: NewRPCMetrics("engine"),
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
	methodName := GetRPCMethodName(c.metrics.GetClientType(), "ForkchoiceUpdate")
	err := c.metrics.TrackRequest(timeoutCtx, methodName, func() error {
		return c.Client.CallContext(timeoutCtx, &result, methodName, fc, attributes)
	})
	if err != nil {
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
	methodName := GetRPCMethodName(c.metrics.GetClientType(), "NewPayload")
	err := c.metrics.TrackRequest(timeoutCtx, methodName, func() error {
		return c.Client.CallContext(timeoutCtx, &result, methodName, payload)
	})
	if err != nil {
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
	methodName := GetRPCMethodName(c.metrics.GetClientType(), "GetPayload")
	err := c.metrics.TrackRequest(timeoutCtx, methodName, func() error {
		return c.Client.CallContext(timeoutCtx, &result, methodName, payloadID)
	})
	if err != nil {
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
	methodName := GetRPCMethodName(c.metrics.GetClientType(), "ExchangeTransitionConfiguration")
	err := c.metrics.TrackRequest(timeoutCtx, methodName, func() error {
		return c.Client.CallContext(timeoutCtx, &result, methodName, cfg)
	})
	if err != nil {
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

	methodName := GetRPCMethodName(c.metrics.GetClientType(), "TxPoolContentWithMinTip")
	err := c.metrics.TrackRequest(timeoutCtx, methodName, func() error {
		return c.CallContext(
			timeoutCtx,
			&result,
			methodName,
			beneficiary,
			baseFee,
			blockMaxGasLimit,
			maxBytesPerTxList,
			locals,
			maxTransactionsLists,
			minTip,
		)
	})
	if err != nil {
		return nil, err
	}
	return result, nil
}

// UpdateL1Origin sets the L2 block's corresponding L1 origin.
func (c *EngineClient) UpdateL1Origin(ctx context.Context, l1Origin *rawdb.L1Origin) (*rawdb.L1Origin, error) {
	var res *rawdb.L1Origin

	methodName := GetRPCMethodName(c.metrics.GetClientType(), "UpdateL1Origin")
	err := c.metrics.TrackRequest(ctx, methodName, func() error {
		return c.CallContext(ctx, &res, methodName, l1Origin)
	})
	if err != nil {
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

	methodName := GetRPCMethodName(c.metrics.GetClientType(), "SetL1OriginSignature")
	err := c.metrics.TrackRequest(ctx, methodName, func() error {
		return c.CallContext(ctx, &res, methodName, blockID, signature)
	})
	if err != nil {
		return nil, err
	}

	return res, nil
}

// SetHeadL1Origin sets the latest L2 block's corresponding L1 origin.
func (c *EngineClient) SetHeadL1Origin(ctx context.Context, blockID *big.Int) (*big.Int, error) {
	var res *big.Int

	methodName := GetRPCMethodName(c.metrics.GetClientType(), "SetHeadL1Origin")
	err := c.metrics.TrackRequest(ctx, methodName, func() error {
		return c.CallContext(ctx, &res, methodName, blockID)
	})
	if err != nil {
		return nil, err
	}

	return res, nil
}
