package server

import (
	"bytes"
	"encoding/hex"
	"net/http"

	"github.com/ethereum/go-ethereum/rlp"
	"github.com/labstack/echo/v4"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/preconfapi/builder"
)

// @title Taiko Proposer Server API
// @version 1.0
// @termsOfService http://swagger.io/terms/

// @contact.name API Support
// @contact.url https://community.taiko.xyz/
// @contact.email info@taiko.xyz

// @license.name MIT
// @license.url https://github.com/taikoxyz/taiko-mono/packages/taiko-client/blob/main/LICENSE.md

type buildBlockRequest struct {
	BlockParams    []buildBlockParams `json:"blockParams"`
	CalldataOrBlob string             `json:"calldataOrBlob"`
}
type buildBlockParams struct {
	L1StateBlockNumber uint32   `json:"l1StateBlockNumber"`
	Timestamp          uint64   `json:"timestamp"`
	SignedTransactions []string `json:"signedTransactions"`
	Coinbase           string   `json:"coinbase"`
	ExtraData          string   `json:"extraData"`
}

type buildBlockResponse struct {
	RLPEncodedTx string `json:"rlpEncodedTx"`
}

// BuildBlock handles a query to build a block according to our protocol, given the inputs,
// and returns an unsigned transaction to `taikol1.ProposeBlock`.
//
//	@Summary		Build a block and return an unsigned `taikol1.ProposeBlock` transaction
//	@ID			   	build
//	@Accept			json
//	@Produce		json
//	@Success		200	{object} BuildBlockResponse
//	@Router			/block/build [get]
func (s *PreconfAPIServer) BuildBlock(c echo.Context) error {
	req := &buildBlockRequest{}
	if err := c.Bind(req); err != nil {
		return c.JSON(http.StatusUnprocessableEntity, err)
	}

	tx, err := s.txBuilders[req.CalldataOrBlob].BuildUnsigned(
		c.Request().Context(),
		paramsToOpts(req.BlockParams),
	)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, err)
	}

	// RLP encode the transaction
	var rlpEncodedTx bytes.Buffer
	if err := rlp.Encode(&rlpEncodedTx, tx); err != nil {
		return c.JSON(http.StatusInternalServerError, err)
	}

	hexEncodedTx := hex.EncodeToString(rlpEncodedTx.Bytes())

	return c.JSON(http.StatusOK, buildBlockResponse{RLPEncodedTx: hexEncodedTx})
}

func paramsToOpts(params []buildBlockParams) builder.BuildUnsignedOpts {
	opts := make([]builder.BlockOpts, 0)

	for _, p := range params {
		opts = append(opts, builder.BlockOpts{
			L1StateBlockNumber: p.L1StateBlockNumber,
			Timestamp:          p.Timestamp,
			SignedTransactions: p.SignedTransactions,
			Coinbase:           p.Coinbase,
			ExtraData:          p.ExtraData,
		})
	}

	return builder.BuildUnsignedOpts{
		BlockOpts: opts,
	}
}
