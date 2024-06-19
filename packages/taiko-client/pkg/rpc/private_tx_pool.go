package rpc

import (
	"context"
	"fmt"
	"net/url"

	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/ethereum/go-ethereum/rpc"
	"github.com/go-resty/resty/v2"
)

const (
	BlockPriceURL = "/gasprices/blockprices"
)

type BlocknativePrivateTxPool struct {
	apiEndpoint string
	apiKey      string
	rpcClient   *ethclient.Client
}

type ErrorResp struct {
	Error uint16
	Msg   string
}
type EstimatedPrice struct {
	MaxPriorityFeePerGas float64 `json:"maxPriorityFeePerGas"`
}

type BlockPrice struct {
	EstimatedPrices []*EstimatedPrice `json:"estimatedPrices"`
}

type BlockPriceResp struct {
	*ErrorResp
	BlockPrices []*BlockPrice `json:"blockPrices"`
}

func NewPrivateTxPool(
	ctx context.Context,
	apiKey string,
	apiEndpoint string,
	rpcURL string,
) (*BlocknativePrivateTxPool, error) {
	client, err := rpc.DialContext(ctx, rpcURL)
	if err != nil {
		return nil, err
	}
	return &BlocknativePrivateTxPool{
		apiKey:      apiKey,
		apiEndpoint: apiEndpoint,
		rpcClient:   ethclient.NewClient(client),
	}, nil
}

// GetPriorityFee gets a suggested gas priority fee to future block
func (p *BlocknativePrivateTxPool) GetPriorityFee(
	ctx context.Context,
) (*BlockPriceResp, error) {
	requestURL, err := url.JoinPath(p.apiEndpoint, BlockPriceURL)
	if err != nil {
		return nil, err
	}
	resp, err := resty.New().R().
		SetResult(BlockPriceResp{}).
		SetContext(ctx).
		SetHeader("Content-Type", "application/json").
		SetHeader("Accept", "application/json").
		SetHeader("Authorization", p.apiKey).
		Get(requestURL)
	if err != nil {
		return nil, err
	}
	response := resp.Result().(*BlockPriceResp)
	if !resp.IsSuccess() {
		return nil, fmt.Errorf(
			"unable to connect apiEndpoint, error code: %v, msg: %s",
			response.Error,
			response.Msg,
		)
	}
	return response, nil
}

// SendTransaction injects a signed transaction into the private pool for execution.
func (p *BlocknativePrivateTxPool) SendTransaction(ctx context.Context, tx *types.Transaction) error {
	return p.rpcClient.SendTransaction(ctx, tx)
}
