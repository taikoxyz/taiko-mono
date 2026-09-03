package http

import (
	"context"
	"encoding/json"
	"errors"
	"html"
	"log/slog"
	"math/big"
	"net/http"
	"sort"
	"strconv"

	"github.com/cyberhorsey/webutils"
	"github.com/ethereum/go-ethereum/common"
	"github.com/labstack/echo/v4"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
)

var errNotHexQuantity = errors.New("not a 0x-prefixed hex quantity")

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

// statusRow is a MessageStatusChanged row placed where its log sits on the chain.
type statusRow struct {
	status   relayer.EventStatus
	raw      Raw
	block    uint64
	logIndex uint64
	id       int
}

// claimLog returns the MessageStatusChanged log to read a message's claim from, or nil when
// the message is not currently claimed.
//
// The latest transition decides, in the chain's own order: block number, then log index,
// which both writers record verbatim from the log. Row ids do not order transitions - the
// indexer stores the logs of one filter range from independent goroutines, so the DONE at
// block N+1 can be committed before the RETRIABLE at block N.
//
// A message has more than one such row when the relayer claims it: the processor records
// its own claim before the destination chain's indexer stores the log, and until now that
// record carried nothing but the transaction hash. Taking the first row by id took that
// stub, and a stub cannot name the claimer, so every message the relayer claimed came back
// with neither claimer nor claim hash while every self-claim came back with both. A stub
// has no position on the chain, so it is consulted only while the message has no
// positioned row at all, whichever of the two was committed first.
//
// Only a latest transition that is DONE is a claim. The chain cannot move a message on
// from DONE, so a later non-DONE row means the DONE was orphaned by a reorg of its block;
// reorg cleanup never removes status rows (it keys on block_id, which they do not set), so
// the orphaned row stays and only the order can tell. A RECALLED row anywhere means the
// message is not claimed: a recall on the source chain proves the destination recorded
// FAILED, which is terminal there, so the two chains' rows need no common order.
func (srv *Server) claimLog(ctx context.Context, msgHash string) (*Raw, error) {
	rows, err := srv.eventRepo.FindAllByEventAndMsgHash(ctx, relayer.EventNameMessageStatusChanged, msgHash)
	if err != nil {
		slog.Warn("could not read the status rows of a message", "msgHash", msgHash, "error", err)

		return nil, err
	}

	var positioned, unpositioned []statusRow

	for _, row := range rows {
		if row.Status == relayer.EventStatusRecalled {
			return nil, nil
		}

		r := &JSONData{}
		if err := json.Unmarshal(row.Data, r); err != nil || r.Raw.TransactionHash == "" {
			continue
		}

		s := statusRow{status: row.Status, raw: r.Raw, id: row.ID}

		block, err := hexQuantity(r.Raw.BlockNumber)
		if err != nil {
			unpositioned = append(unpositioned, s)

			continue
		}

		s.block = block
		// Every real log carries its index; a row without one still has its block
		s.logIndex, _ = hexQuantity(r.Raw.LogIndex)
		positioned = append(positioned, s)
	}

	candidates := positioned
	if len(candidates) == 0 {
		candidates = unpositioned
	}

	if len(candidates) == 0 {
		return nil, nil
	}

	sort.SliceStable(candidates, func(a, b int) bool {
		x, y := candidates[a], candidates[b]
		if x.block != y.block {
			return x.block < y.block
		}

		if x.logIndex != y.logIndex {
			return x.logIndex < y.logIndex
		}

		return x.id < y.id
	})

	latest := candidates[len(candidates)-1]
	if latest.status != relayer.EventStatusDone {
		return nil, nil
	}

	return &latest.raw, nil
}

// hexQuantity parses a 0x-prefixed hex quantity the way the logs carry block and log indices.
func hexQuantity(s string) (uint64, error) {
	if len(s) < 3 || s[:2] != "0x" {
		return 0, errNotHexQuantity
	}

	return strconv.ParseUint(s[2:], 16, 64)
}

// claimChainID is the chain a message's claim was mined on: the message's destination.
// Status rows are filed under the chain they were emitted on, but a row can predate that
// convention (the processor's own claim used to be filed under the message's source chain),
// so the message is asked, not the row.
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
