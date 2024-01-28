package http

import (
	"log/slog"
	"net/http"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"
	echo "github.com/labstack/echo/v4"
	guardianproverhealthcheck "github.com/taikoxyz/taiko-mono/packages/guardian-prover-health-check"
)

type startupReq struct {
	ProverAddress string `json:"prover"`
	Version       string `json:"version"`
	Revision      string `json:"revision"`
	Signature     string `json:"signature"`
}

// PostStartup
//
//	 post a health check from a guardian prover
//
//			@Summary		Post startup
//			@ID			   	post-startup
//			@Accept			json
//			@Produce		json
//			@Success		200	null
//			@Router			/startup [post]

func (srv *Server) PostStartup(c echo.Context) error {
	req := &startupReq{}

	// bind incoming request
	if err := c.Bind(req); err != nil {
		return c.JSON(http.StatusBadRequest, err)
	}

	msg := crypto.Keccak256Hash(
		common.HexToAddress(req.ProverAddress).Bytes(),
		[]byte(req.Revision),
		[]byte(req.Version),
	).Bytes()

	recoveredGuardianProver, err := guardianproverhealthcheck.SignatureToGuardianProver(
		msg,
		req.Signature,
		srv.guardianProvers,
	)

	// if not, we want to return an error
	if err != nil {
		return c.JSON(http.StatusBadRequest, err)
	}

	// otherwise, we can store it in the database.
	// expected address and recovered address will be the same until we have an auth
	// mechanism which will allow us to store health checks that ecrecover to an unexpected
	// address.
	if err := srv.startupRepo.Save(guardianproverhealthcheck.SaveStartupOpts{
		GuardianProverID:      recoveredGuardianProver.ID.Uint64(),
		Version:               req.Version,
		Revision:              req.Revision,
		GuardianProverAddress: req.ProverAddress,
	}); err != nil {
		return c.JSON(http.StatusBadRequest, err)
	}

	slog.Info("successful startup",
		"guardianProver", recoveredGuardianProver.Address.Hex(),
		"revision", req.Revision,
		"version", req.Version,
	)

	return c.JSON(http.StatusOK, nil)
}
