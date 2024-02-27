package guardianproverhealthcheck

import (
	"context"
	"net/http"
	"time"

	"github.com/morkid/paginate"
)

// Startup represents an individual startup from a guardian prover, every time
// one boots up, we should receive a startup and save it in the database.
type Startup struct {
	GuardianProverID      uint64    `json:"guardianProverID"`
	GuardianProverAddress string    `json:"guardianProverAddress"`
	L1NodeVersion         string    `json:"l1NodeVersion"`
	L2NodeVersion         string    `json:"l2NodeVersion"`
	Revision              string    `json:"revision"`
	GuardianVersion       string    `json:"guardianVersion"`
	CreatedAt             time.Time `json:"createdAt"`
}

type SaveStartupOpts struct {
	GuardianProverID      uint64
	GuardianProverAddress string
	Revision              string
	GuardianVersion       string
	L1NodeVersion         string `json:"l1NodeVersion"`
	L2NodeVersion         string `json:"l2NodeVersion"`
}

type NodeInfo struct {
	Startup
	LatestL1BlockNumber uint64 `json:"latestL1BlockNumber"`
	LatestL2BlockNumber uint64 `json:"latestL2BlockNumber"`
}

type StartupRepository interface {
	GetByGuardianProverID(
		ctx context.Context,
		req *http.Request,
		id int,
	) (paginate.Page, error)
	GetMostRecentByGuardianProverID(
		ctx context.Context,
		id int,
	) (*Startup, error)
	Save(opts SaveStartupOpts) error
}
