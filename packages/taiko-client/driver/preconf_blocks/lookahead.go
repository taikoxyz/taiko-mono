package preconfblocks

import (
	"time"

	"github.com/ethereum/go-ethereum/common"
)

// Lookahead represents the lookahead information in the current beacon consensus.
type Lookahead struct {
	CurrOperator common.Address
	NextOperator common.Address
	UpdatedAt    time.Time
}
