package server

import (
	"bytes"
	"encoding/hex"
	"encoding/json"
	"net/http"

	badger "github.com/dgraph-io/badger/v4"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/rlp"
	"github.com/labstack/echo/v4"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/preconfapi/builder"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/preconfapi/model"
)

// @title Taiko Preconf Server API
// @version 1.0
// @termsOfService http://swagger.io/terms/

// @contact.name API Support
// @contact.url https://community.taiko.xyz/
// @contact.email info@taiko.xyz

// @license.name MIT
// @license.url https://github.com/taikoxyz/taiko-mono/packages/taiko-client/blob/main/LICENSE.md

type buildBlocksRequest struct {
	BlockParams    []buildBlockParams `json:"blockParams"`
	CalldataOrBlob string             `json:"calldataOrBlob"`
}

type buildBlockRequest struct {
	buildBlockParams
	CalldataOrBlob string `json:"calldataOrBlob"`
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

// BuildBlock handles a query to build blocks according to our protocol, given the inputs,
// and returns an unsigned transaction to `taikol1.ProposeBlock`.
//
//	@Summary		Build builds and return an unsigned `taikol1.ProposeBlock` transaction
//	@ID			   	build
//	@Accept			json
//	@Produce		json
//	@Success		200	{object} buildBlockResponse
//	@Router			/block/build [post]
func (s *PreconfAPIServer) BuildBlock(c echo.Context) error {
	req := &buildBlockRequest{}
	if err := c.Bind(req); err != nil {
		return c.JSON(http.StatusUnprocessableEntity, err)
	}

	// default to blob
	t := req.CalldataOrBlob
	if t == "" {
		t = "blob"
	}

	tx, err := s.txBuilders[t].BuildBlockUnsigned(
		c.Request().Context(),
		builder.BuildBlockUnsignedOpts{
			L1StateBlockNumber: req.L1StateBlockNumber,
			Timestamp:          req.Timestamp,
			SignedTransactions: req.SignedTransactions,
			Coinbase:           req.Coinbase,
			ExtraData:          req.ExtraData,
		},
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

// BuildBlocks handles a query to build blocks according to our protocol, given the inputs,
// and returns an unsigned transaction to `taikol1.ProposeBlocks`.
//
//	@Summary		Build builds and return an unsigned `taikol1.ProposeBlocks` transaction
//	@ID			   	build
//	@Accept			json
//	@Produce		json
//	@Success		200	{object} buildBlockResponse
//	@Router			/blocks/build [post]
func (s *PreconfAPIServer) BuildBlocks(c echo.Context) error {
	req := &buildBlocksRequest{}
	if err := c.Bind(req); err != nil {
		return c.JSON(http.StatusUnprocessableEntity, err)
	}

	// default to blob
	t := req.CalldataOrBlob
	if t == "" {
		t = "blob"
	}

	tx, err := s.txBuilders[t].BuildBlocksUnsigned(
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

func (s *PreconfAPIServer) GetTransactionByHash(c echo.Context) error {
	hash := c.Param("hash")

	// get from badger db
	tx := &model.Transaction{}

	if err := s.db.View(func(txn *badger.Txn) error {
		item, err := txn.Get(common.HexToHash(hash).Bytes())
		if err != nil {
			return err
		}

		if item == nil {
			return nil
		}

		if err := item.Value(func(val []byte) error {
			return json.Unmarshal(val, tx)
		}); err != nil {
			return err
		}

		return nil
	}); err != nil {
		return c.JSON(http.StatusNotFound, err)
	}

	if tx == nil {
		return c.JSON(http.StatusNotFound, nil)
	}

	return c.JSON(http.StatusOK, tx)
}

func paramsToOpts(params []buildBlockParams) builder.BuildBlocksUnsignedOpts {
	opts := make([]builder.BuildBlockUnsignedOpts, 0)

	for _, p := range params {
		opts = append(opts, builder.BuildBlockUnsignedOpts{
			L1StateBlockNumber: p.L1StateBlockNumber,
			Timestamp:          p.Timestamp,
			SignedTransactions: p.SignedTransactions,
			Coinbase:           p.Coinbase,
			ExtraData:          p.ExtraData,
		})
	}

	return builder.BuildBlocksUnsignedOpts{
		BlockOpts: opts,
	}
}
