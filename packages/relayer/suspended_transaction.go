package relayer

import (
	"context"
	"net/http"

	"github.com/morkid/paginate"
)

type SuspendedTransaction struct {
	ID           int    `json:"id"`
	MessageID    int    `json:"messageID"`
	SrcChainID   int    `json:"srcChainID"`
	DestChainID  int    `json:"destChainID"`
	Suspended    bool   `json:"suspended"`
	MsgHash      string `json:"msgHash"`
	MessageOwner string `json:"messageOwner"`
}

type SuspendTransactionOpts struct {
	MessageID    int
	SrcChainID   int
	DestChainID  int
	Suspended    bool
	MsgHash      string
	MessageOwner string
}

type SuspendedTransactionRepository interface {
	Save(ctx context.Context, opts SuspendTransactionOpts) (*SuspendedTransaction, error)
	Find(
		ctx context.Context,
		req *http.Request,
	) (paginate.Page, error)
}
