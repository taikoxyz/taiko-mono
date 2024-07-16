package server

import (
	"bytes"
	"encoding/hex"
	"log"
	"net/http"
	"strings"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/rlp"
	"github.com/labstack/echo/v4"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
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
	L1StateBlockNumber uint32   `json:"l1StateBlockNumber"`
	Timestamp          uint64   `json:"timestamp"`
	SignedTransactions []string `json:"signedTransactions"`
	Coinbase           string   `json:"coinbase"`
	ExtraData          string   `json:"extraData"`
	CalldataOrBlob     string   `json:"calldataOrBlob"`
}

type buildBlockResponse struct {
	RLPEncodedTx string `json:"rlpEncodedTx"`
}

// BuildBlock handles a query to build blocks according to our protocol, given the inputs,
// and returns an unsigned transaction to `taikol1.ProposeBlocks`.
//
//	@Summary		Build builds and return an unsigned `taikol1.ProposeBlocks` transaction
//	@ID			   	build
//	@Accept			json
//	@Produce		json
//	@Success		200	{object} buildBlockResponse
//	@Router			/blocks/build [post]
func (s *PreconfAPIServer) BuildBlocks(c echo.Context) error {
	req := &buildBlockRequest{}
	if err := c.Bind(req); err != nil {
		return c.JSON(http.StatusUnprocessableEntity, err)
	}

	txListBytes, err := signedTransactionsToTxListBytes(req.SignedTransactions)
	if err != nil {
		return c.JSON(http.StatusUnprocessableEntity, err)
	}

	// default to blob
	t := req.CalldataOrBlob
	if t == "" {
		t = "blob"
	}

	tx, err := s.txBuilders[t].BuildUnsigned(
		c.Request().Context(),
		txListBytes,
		req.L1StateBlockNumber,
		req.Timestamp,
		common.HexToAddress(req.Coinbase),
		rpc.StringToBytes32(req.ExtraData),
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
	req := &buildBlockRequest{}
	if err := c.Bind(req); err != nil {
		return c.JSON(http.StatusUnprocessableEntity, err)
	}

	txListBytes, err := signedTransactionsToTxListBytes(req.SignedTransactions)
	if err != nil {
		return c.JSON(http.StatusUnprocessableEntity, err)
	}

	// default to blob
	t := req.CalldataOrBlob
	if t == "" {
		t = "blob"
	}

	tx, err := s.txBuilders[t].BuildUnsigned(
		c.Request().Context(),
		txListBytes,
		req.L1StateBlockNumber,
		req.Timestamp,
		common.HexToAddress(req.Coinbase),
		rpc.StringToBytes32(req.ExtraData),
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

func signedTransactionsToTxListBytes(txs []string) ([]byte, error) {
	var transactions types.Transactions

	for _, signedTxHex := range txs {
		signedTxHex = strings.TrimPrefix(signedTxHex, "0x")

		rlpEncodedBytes, err := hex.DecodeString(signedTxHex)
		if err != nil {
			return nil, err
		}

		var tx types.Transaction
		if err := rlp.DecodeBytes(rlpEncodedBytes, &tx); err != nil {
			return nil, err
		}

		transactions = append(transactions, &tx)
	}

	txListBytes, err := rlp.EncodeToBytes(transactions)
	if err != nil {
		log.Fatalf("Failed to RLP encode transactions: %v", err)
	}

	return txListBytes, nil
}
