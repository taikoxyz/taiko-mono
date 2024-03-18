package http

import (
	"log/slog"
	"net/http"

	"github.com/ethereum/go-ethereum/crypto"
	echo "github.com/labstack/echo/v4"
	guardianproverhealthcheck "github.com/taikoxyz/taiko-mono/packages/guardian-prover-health-check"
)

var (
	msg = crypto.Keccak256Hash([]byte("HEART_BEAT")).Bytes()
)

type healthCheckReq struct {
	ProverAddress      string `json:"prover"`
	HeartBeatSignature string `json:"heartBeatSignature"`
	LatestL1Block      uint64 `json:"latestL1Block"`
	LatestL2Block      uint64 `json:"latestL2Block"`
}

// PostHealthCheck
//
//	 post a health check from a guardian prover
//
//			@Summary		Post healthcheck
//			@ID			   	post-health-check
//			@Accept			json
//			@Produce		json
//			@Success		200	null
//			@Router			/healthCheck [post]

func (srv *Server) PostHealthCheck(c echo.Context) error {
	req := &healthCheckReq{}

	// bind incoming request
	if err := c.Bind(req); err != nil {
		slog.Error("error binding incoming heartbeat req",
			"error", err, "signature", req.HeartBeatSignature,
		)

		return c.JSON(http.StatusBadRequest, err)
	}

	recoveredGuardianProver, err := guardianproverhealthcheck.SignatureToGuardianProver(
		msg,
		req.HeartBeatSignature,
		srv.guardianProvers,
	)

	// if not, we want to return an error
	if err != nil {
		slog.Error("error recovering guardian prover",
			"error", err, "signature", req.HeartBeatSignature,
		)

		return c.JSON(http.StatusBadRequest, err)
	}

	// otherwise, we can store it in the database.
	// expected address and recovered address will be the same until we have an auth
	// mechanism which will allow us to store health checks that ecrecover to an unexpected
	// address.
	if err := srv.healthCheckRepo.Save(guardianproverhealthcheck.SaveHealthCheckOpts{
		GuardianProverID: recoveredGuardianProver.ID.Uint64(),
		Alive:            true,
		ExpectedAddress:  recoveredGuardianProver.Address.Hex(),
		RecoveredAddress: recoveredGuardianProver.Address.Hex(),
		SignedResponse:   req.HeartBeatSignature,
		LatestL1Block:    req.LatestL1Block,
		LatestL2Block:    req.LatestL2Block,
	}); err != nil {
		slog.Error("error saving health check",
			"error", err,
			"signature", req.HeartBeatSignature,
		)

		return c.JSON(http.StatusBadRequest, err)
	}

	// increment health check metric
	for _, v := range srv.guardianProvers {
		if v.Address.Hex() == recoveredGuardianProver.Address.Hex() {
			v.HealthCheckCounter.Inc()
		}
	}

	slog.Info("successful health check",
		"id", recoveredGuardianProver.ID.Uint64(),
		"guardianProver", recoveredGuardianProver.Address.Hex(),
		"latestL1Block", req.LatestL1Block,
		"latestL2Block", req.LatestL2Block,
	)

	return c.JSON(http.StatusOK, nil)
}
