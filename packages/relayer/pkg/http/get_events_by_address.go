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
	headers := headerHashes{}

	for i := range *page.Items.(*[]relayer.Event) {
		v := &(*page.Items.(*[]relayer.Event))[i]

		claim, err := srv.claimLog(c.Request().Context(), v.MsgHash, headers)
		if err != nil || claim == nil {
			continue
		}

		v.ProcessedTxHash = claim.raw.TransactionHash

		// The sender is recovered through the block the transaction was mined in, so a row
		// that carries only the hash can name the transaction but not the claimer
		if claim.raw.TransactionIndex == "" || claim.raw.BlockHash == "" {
			continue
		}

		ethClient := srv.clientForChain(claim.chainID)

		tx, _, err := ethClient.TransactionByHash(
			c.Request().Context(),
			common.HexToHash(claim.raw.TransactionHash),
		)
		if err != nil {
			continue
		}

		txIndex, err := strconv.ParseInt(claim.raw.TransactionIndex[2:], 16, 64)
		if err != nil {
			continue
		}

		sender, err := ethClient.TransactionSender(
			c.Request().Context(),
			tx,
			common.HexToHash(claim.raw.BlockHash),
			uint(txIndex),
		)
		if err == nil {
			v.ClaimedBy = sender.Hex()
		}
	}

	return c.JSON(http.StatusOK, page)
}

// statusRow is a MessageStatusChanged row placed where its log sits on the chain it is
// filed under.
type statusRow struct {
	status   relayer.EventStatus
	raw      Raw
	chainID  int64
	block    uint64
	logIndex uint64
	id       int
}

// claim is the log a message's claim is read from, and the chain it was mined on.
type claim struct {
	raw     Raw
	chainID int64
}

// headerHashes caches, for one request, the hash of the canonical header at a height on a
// chain, so a block that several rows or messages sit in is fetched once.
type headerHashes map[string]common.Hash

// canonicalHash is the hash of the block a chain has at a height.
func (srv *Server) canonicalHash(
	ctx context.Context,
	chainID int64,
	block uint64,
	cache headerHashes,
) (common.Hash, error) {
	key := strconv.FormatInt(chainID, 10) + ":" + strconv.FormatUint(block, 10)
	if hash, ok := cache[key]; ok {
		return hash, nil
	}

	header, err := srv.clientForChain(chainID).HeaderByNumber(ctx, new(big.Int).SetUint64(block))
	if err != nil {
		return common.Hash{}, err
	}

	hash := header.Hash()
	cache[key] = hash

	return hash, nil
}

// canonical reports whether the chain a row is filed under still has the block the row
// names. Both writers file a row under the chain its log was emitted on - the indexer under
// the chain it watches, the processor under the message's destination - so that column is
// the chain to ask.
func (srv *Server) canonical(ctx context.Context, row statusRow, cache headerHashes) (bool, error) {
	hash, err := srv.canonicalHash(ctx, row.chainID, row.block, cache)
	if err != nil {
		slog.Debug("could not check a status row against its chain", "chainID", row.chainID, "error", err)

		return false, err
	}

	return hash == common.HexToHash(row.raw.BlockHash), nil
}

// claimLog returns the log to read a message's claim from, or nil when the message is not
// currently claimed.
//
// The latest canonical transition decides. Rows are walked from the latest coordinates
// down - block number, then log index, which both writers record verbatim from the log -
// and each is checked against the chain it is filed under: the block that chain has at the
// row's height must be the block the row names. Coordinates alone cannot tell a fork from a
// retry, and reorg cleanup never removes status rows (it keys on block_id, which they do not
// set), so a DONE mined on a fork the chain abandoned stays next to what the canonical fork
// recorded instead, at a lower height or at the same height under another block hash. Row
// ids do not order transitions either: the indexer stores the logs of one filter range from
// independent goroutines.
//
// A message has more than one such row when the relayer claims it: the processor records
// its own claim before the destination chain's indexer stores the log, and until now that
// record carried nothing but the transaction hash. Taking the first row by id took that
// stub, and a stub cannot name the claimer, so every message the relayer claimed came back
// with neither claimer nor claim hash while every self-claim came back with both. A stub
// has no position on the chain and nothing to check it against, so it is consulted only
// while the message has no positioned row at all, whichever of the two was committed first.
//
// A RECALLED row is emitted on the source chain and vetoes a claim while that chain still
// has the block it names: a canonical recall proves the destination recorded FAILED, which
// is terminal there, and a recall whose block the source chain replaced does not outlive
// its fork. A row the chain cannot vouch for, because the header lookup failed, settles
// nothing: it is neither a claim nor, for a recall, a veto that can be dismissed, so the
// answer is that the message is not known to be claimed.
func (srv *Server) claimLog(ctx context.Context, msgHash string, cache headerHashes) (*claim, error) {
	rows, err := srv.eventRepo.FindAllByEventAndMsgHash(ctx, relayer.EventNameMessageStatusChanged, msgHash)
	if err != nil {
		slog.Warn("could not read the status rows of a message", "msgHash", msgHash, "error", err)

		return nil, err
	}

	var transitions, stubs, recalls []statusRow

	for _, row := range rows {
		r := &JSONData{}
		if err := json.Unmarshal(row.Data, r); err != nil || r.Raw.TransactionHash == "" {
			// A recall that cannot be read cannot be checked either
			if row.Status == relayer.EventStatusRecalled {
				return nil, nil
			}

			continue
		}

		s := statusRow{status: row.Status, raw: r.Raw, chainID: row.ChainID, id: row.ID}

		block, err := hexQuantity(r.Raw.BlockNumber)
		if err != nil {
			if row.Status == relayer.EventStatusRecalled {
				return nil, nil
			}

			stubs = append(stubs, s)

			continue
		}

		s.block = block
		// Every real log carries its index; a row without one still has its block
		s.logIndex, _ = hexQuantity(r.Raw.LogIndex)

		if row.Status == relayer.EventStatusRecalled {
			recalls = append(recalls, s)
		} else {
			transitions = append(transitions, s)
		}
	}

	for _, recall := range recalls {
		vetoes, err := srv.canonical(ctx, recall, cache)
		if err != nil || vetoes {
			return nil, nil
		}
	}

	if len(transitions) == 0 {
		if len(stubs) == 0 {
			return nil, nil
		}

		sort.SliceStable(stubs, func(a, b int) bool { return stubs[a].id < stubs[b].id })

		latest := stubs[len(stubs)-1]
		if latest.status != relayer.EventStatusDone {
			return nil, nil
		}

		return &claim{raw: latest.raw, chainID: latest.chainID}, nil
	}

	sort.SliceStable(transitions, func(a, b int) bool {
		x, y := transitions[a], transitions[b]
		if x.block != y.block {
			return x.block < y.block
		}

		if x.logIndex != y.logIndex {
			return x.logIndex < y.logIndex
		}

		return x.id < y.id
	})

	for i := len(transitions) - 1; i >= 0; i-- {
		row := transitions[i]

		ok, err := srv.canonical(ctx, row, cache)
		if err != nil {
			return nil, nil
		}

		// The chain has another block at this height: this row is a fork's
		if !ok {
			continue
		}

		if row.status != relayer.EventStatusDone {
			return nil, nil
		}

		return &claim{raw: row.raw, chainID: row.chainID}, nil
	}

	return nil, nil
}

// hexQuantity parses a 0x-prefixed hex quantity the way the logs carry block and log indices.
func hexQuantity(s string) (uint64, error) {
	if len(s) < 3 || s[:2] != "0x" {
		return 0, errNotHexQuantity
	}

	return strconv.ParseUint(s[2:], 16, 64)
}

// clientForChain is the RPC client for one of the two chains this server is configured
// with; anything that is not the source chain is taken to be the destination.
func (srv *Server) clientForChain(chainID int64) ethClient {
	if big.NewInt(chainID).Cmp(srv.srcChainID) == 0 {
		return srv.srcEthClient
	}

	return srv.destEthClient
}
