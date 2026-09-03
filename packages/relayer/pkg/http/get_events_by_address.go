package http

import (
	"context"
	"encoding/json"
	"html"
	"log/slog"
	"math/big"
	"net/http"
	"strconv"

	"github.com/cyberhorsey/webutils"
	"github.com/ethereum/go-ethereum/common"
	"github.com/labstack/echo/v4"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
)

type JSONData struct {
	Raw Raw `json:"Raw"`
}
type Raw struct {
	Data             string   `json:"data"`
	Topics           []string `json:"topics"`
	Address          string   `json:"address"`
	Removed          bool     `json:"removed"`
	LogIndex         string   `json:"logIndex"`
	BlockHash        string   `json:"blockHash"`
	BlockNumber      string   `json:"blockNumber"`
	TransactionHash  string   `json:"transactionHash"`
	TransactionIndex string   `json:"transactionIndex"`
}

type Stats struct {
	ProofSize        int `json:"ProofSize"`
	NumCacheOps      int `json:"NumCacheOps"`
	GasUsedInFeeCalc int `json:"GasUsedInFeeCalc"`
}

type Message struct {
	Id          int    `json:"Id"`
	To          string `json:"To"`
	Fee         int64  `json:"Fee"`
	Data        string `json:"Data"`
	From        string `json:"From"`
	Value       int64  `json:"Value"`
	GasLimit    int    `json:"GasLimit"`
	SrcOwner    string `json:"SrcOwner"`
	DestOwner   string `json:"DestOwner"`
	SrcChainId  int    `json:"SrcChainId"`
	DestChainId int    `json:"DestChainId"`
}

type DataStruct struct {
	Raw     Raw     `json:"Raw"`
	Stats   Stats   `json:"Stats"`
	Message Message `json:"Message"`
	MsgHash string  `json:"MsgHash"`
}

// GetEventsByAddress
//
//	 returns events by address
//
//			@Summary		Get events by address
//			@ID			   	get-events-by-address
//		    @Param			address	query		string		true	"address to query"
//		    @Param			msgHash	query		string		false	"msgHash to query"
//		    @Param			chainID	query		string		false	"chainID to query"
//		    @Param			eventType	query		string		false	"eventType to query"
//		    @Param			event	query		string		false	"event to query"
//			@Accept			json
//			@Produce		json
//			@Success		200	{object} paginate.Page
//			@Router			/events [get]
func (srv *Server) GetEventsByAddress(c echo.Context) error {
	chainID, _ := new(big.Int).SetString(c.QueryParam("chainID"), 10)

	address := html.EscapeString(c.QueryParam("address"))

	msgHash := html.EscapeString(c.QueryParam("msgHash"))

	eventTypeParam := html.EscapeString(c.QueryParam("eventType"))

	event := html.EscapeString(c.QueryParam("event"))

	var eventType *relayer.EventType

	if eventTypeParam != "" {
		i, err := strconv.Atoi(eventTypeParam)
		if err != nil {
			return webutils.LogAndRenderErrors(c, http.StatusUnprocessableEntity, err)
		}

		et := relayer.EventType(i)

		eventType = &et
	}

	page, err := srv.eventRepo.FindAllByAddress(
		c.Request().Context(),
		c.Request(),
		relayer.FindAllByAddressOpts{
			Address:   common.HexToAddress(address),
			MsgHash:   &msgHash,
			EventType: eventType,
			ChainID:   chainID,
			Event:     &event,
		},
	)
	if err != nil {
		return webutils.LogAndRenderErrors(c, http.StatusUnprocessableEntity, err)
	}

	// get processed message tx and claimedBy
	for i := range *page.Items.(*[]relayer.Event) {
		v := &(*page.Items.(*[]relayer.Event))[i]

		claim, err := srv.claimLog(c.Request().Context(), v.MsgHash)
		if err != nil || claim == nil {
			continue
		}

		v.ProcessedTxHash = claim.TransactionHash

		// The sender is recovered through the block the transaction was mined in, so a row
		// that carries only the hash can name the transaction but not the claimer
		if claim.TransactionIndex == "" || claim.BlockHash == "" {
			continue
		}

		ethClient := srv.clientForChain(srv.claimChainID(c.Request().Context(), v))

		tx, _, err := ethClient.TransactionByHash(
			c.Request().Context(),
			common.HexToHash(claim.TransactionHash),
		)
		if err != nil {
			continue
		}

		txIndex, err := strconv.ParseInt(claim.TransactionIndex[2:], 16, 64)
		if err != nil {
			continue
		}

		sender, err := ethClient.TransactionSender(
			c.Request().Context(),
			tx,
			common.HexToHash(claim.BlockHash),
			uint(txIndex),
		)
		if err == nil {
			v.ClaimedBy = sender.Hex()
		}
	}

	return c.JSON(http.StatusOK, page)
}

// claimLog returns the MessageStatusChanged log to read a message's claim from: newest
// first, the first fully indexed DONE row, or failing that the first DONE row that at least
// names the transaction.
//
// A message has more than one such row when the relayer claims it: the processor records
// its own claim before the destination chain's indexer stores the log, and until now that
// record carried nothing but the transaction hash. Taking the first row by id took that
// stub, and a stub cannot name the claimer, so every message the relayer claimed came back
// with neither claimer nor claim hash while every self-claim came back with both.
//
// Only DONE counts. A retried message also has a complete row for the attempt that left it
// RETRIABLE, and a recalled one has a RECALLED row mined on the source chain; neither is a
// claim, and reporting one would name the wrong transaction, chain and sender.
func (srv *Server) claimLog(ctx context.Context, msgHash string) (*Raw, error) {
	rows, err := srv.eventRepo.FindAllByEventAndMsgHash(ctx, relayer.EventNameMessageStatusChanged, msgHash)
	if err != nil {
		slog.Warn("could not read the status rows of a message", "msgHash", msgHash, "error", err)

		return nil, err
	}

	var named *Raw

	for i := len(rows) - 1; i >= 0; i-- {
		row := rows[i]
		if row.Status != relayer.EventStatusDone {
			continue
		}

		r := &JSONData{}
		if err := json.Unmarshal(row.Data, r); err != nil {
			continue
		}

		if r.Raw.TransactionHash == "" {
			continue
		}

		if r.Raw.TransactionIndex != "" && r.Raw.BlockHash != "" {
			return &r.Raw, nil
		}

		if named == nil {
			named = &r.Raw
		}
	}

	return named, nil
}

// claimChainID is the chain a message's claim was mined on: the message's destination.
// The status rows do not agree on where they are filed - the indexer files a log under the
// chain it watches, the processor files its own claim under the message's source chain, and
// the indexer's resume and reorg checks key on that column - so the message is asked, not
// the row.
func (srv *Server) claimChainID(ctx context.Context, v *relayer.Event) int64 {
	if v.Event == relayer.EventNameMessageSent {
		return v.DestChainID
	}

	sent, err := srv.eventRepo.FirstByEventAndMsgHash(ctx, relayer.EventNameMessageSent, v.MsgHash)
	if err == nil && sent != nil {
		return sent.DestChainID
	}

	return v.ChainID
}

// clientForChain is the RPC client for one of the two chains this server is configured
// with; anything that is not the source chain is taken to be the destination.
func (srv *Server) clientForChain(chainID int64) ethClient {
	if big.NewInt(chainID).Cmp(srv.srcChainID) == 0 {
		return srv.srcEthClient
	}

	return srv.destEthClient
}
