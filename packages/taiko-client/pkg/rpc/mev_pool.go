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

type MevPool struct {
	apiEndpoint string
	apiKey      string
	rpcClient   *ethclient.Client
}

type ErrorResp struct {
	error uint16
	msg   string
}
type EstimatedPrice struct {
	maxPriorityFeePerGas int64
}

type BlockPrice struct {
	estimatedPrices []*EstimatedPrice
}

type BlockPriceResp struct {
	*ErrorResp
	blockPrices []*BlockPrice
}

func NewMevPool(
	ctx context.Context,
	apiKey string,
	apiEndpoint string,
	rpcURL string,
) (*MevPool, error) {
	client, err := rpc.DialContext(ctx, rpcURL)
	if err != nil {
		return nil, err
	}
	return &MevPool{
		apiKey:      apiKey,
		apiEndpoint: apiEndpoint,
		rpcClient:   ethclient.NewClient(client),
	}, nil
}

func (p *MevPool) GetPriorityFee(
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
		Get(requestURL)
	if err != nil {
		return nil, err
	}
	response := resp.Result().(*BlockPriceResp)
	if !resp.IsSuccess() {
		return nil, fmt.Errorf(
			"unable to connect apiEndpoint, error code: %v, msg: %s",
			response.error,
			response.msg,
		)
	}
	return response, nil
}

func (p *MevPool) SendTransaction(ctx context.Context, tx *types.Transaction) error {
	return p.rpcClient.SendTransaction(ctx, tx)
}
