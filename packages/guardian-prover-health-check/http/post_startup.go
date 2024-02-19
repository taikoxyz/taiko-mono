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
	ProverAddress   string `json:"prover"`
	GuardianVersion string `json:"guardianVersion"`
	L1NodeVersion   string `json:"l1NodeVersion"`
	L2NodeVersion   string `json:"l2NodeVersion"`
	Revision        string `json:"revision"`
	Signature       string `json:"signature"`
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
		[]byte(req.GuardianVersion),
		[]byte(req.L1NodeVersion),
		[]byte(req.L2NodeVersion),
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
		GuardianVersion:       req.GuardianVersion,
		L1NodeVersion:         req.L1NodeVersion,
		L2NodeVersion:         req.L2NodeVersion,
		Revision:              req.Revision,
		GuardianProverAddress: req.ProverAddress,
	}); err != nil {
		return c.JSON(http.StatusBadRequest, err)
	}

	slog.Info("successful startup",
		"guardianProver", recoveredGuardianProver.Address.Hex(),
		"revision", req.Revision,
		"guardianVersion", req.GuardianVersion,
		"l1NodeVersion", req.L1NodeVersion,
		"l2NodeVersion", req.L2NodeVersion,
	)

	return c.JSON(http.StatusOK, nil)
}
