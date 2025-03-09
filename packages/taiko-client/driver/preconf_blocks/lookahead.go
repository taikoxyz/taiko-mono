package preconfblocks

import (
	"time"

	"github.com/ethereum/go-ethereum/common"
)

type Lookahead struct {
	CurrOperator common.Address
	NextOperator common.Address
	UpdatedAt    time.Time
}
