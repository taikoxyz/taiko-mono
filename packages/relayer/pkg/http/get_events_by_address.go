package http

import (
	"encoding/json"
	"html"
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

		msgProcessedEvent, err := srv.eventRepo.FirstByEventAndMsgHash(
			c.Request().Context(),
			relayer.EventNameMessageStatusChanged,
			v.MsgHash,
		)
		if err != nil {
			continue
		}

		if msgProcessedEvent == nil {
			continue
		}

		r := &JSONData{}

		if err := json.Unmarshal(msgProcessedEvent.Data, r); err != nil {
			return webutils.LogAndRenderErrors(c, http.StatusUnprocessableEntity, err)
		}

		if r.Raw.TransactionIndex == "" || r.Raw.TransactionHash == "" {
			continue
		}

		var ethClient ethClient

		if new(big.Int).SetInt64(msgProcessedEvent.ChainID).Cmp(srv.srcChainID) == 0 {
			ethClient = srv.srcEthClient
		} else {
			ethClient = srv.destEthClient
		}

		tx, _, err := ethClient.TransactionByHash(
			c.Request().Context(),
			common.HexToHash(r.Raw.TransactionHash),
		)
		if err != nil {
			return webutils.LogAndRenderErrors(c, http.StatusUnprocessableEntity, err)
		}

		txIndex, err := strconv.ParseInt(r.Raw.TransactionIndex[2:], 16, 64)
		if err != nil {
			return webutils.LogAndRenderErrors(c, http.StatusUnprocessableEntity, err)
		}

		sender, err := ethClient.TransactionSender(
			c.Request().Context(),
			tx,
			common.HexToHash(r.Raw.BlockHash),
			uint(txIndex),
		)
		if err == nil {
			v.ClaimedBy = sender.Hex()
		}

		v.ProcessedTxHash = r.Raw.TransactionHash
	}

	return c.JSON(http.StatusOK, page)
}
