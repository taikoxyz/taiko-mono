package http

import (
	"log/slog"
	"net/http"
	"strings"

	"github.com/ethereum/go-ethereum/common"
	echo "github.com/labstack/echo/v4"
	guardianproverhealthcheck "github.com/taikoxyz/taiko-mono/packages/guardian-prover-health-check"
)

type signedBlock struct {
	BlockID   uint64         `json:"blockID"`
	BlockHash string         `json:"blockHash"`
	Signature string         `json:"signature"`
	Prover    common.Address `json:"proverAddress"`
}

// PostSignedBlock
//
//	 post a signed block to store in the database
//
//			@Summary		Post signed block
//			@ID			   	post-signed-block
//			@Accept			json
//			@Produce		json
//			@Success		200	null
//			@Router			/signedBlock [post]

func (srv *Server) PostSignedBlock(c echo.Context) error {
	req := &signedBlock{}

	// bind incoming request
	if err := c.Bind(req); err != nil {
		slog.Error("error binding request", "error", err)

		return c.JSON(http.StatusBadRequest, err)
	}

	recoveredGuardianProver, err := guardianproverhealthcheck.SignatureToGuardianProver(
		common.HexToHash(req.BlockHash).Bytes(),
		req.Signature,
		srv.guardianProvers,
	)

	// if not, we want to return an error
	if err != nil {
		slog.Error("error recovering guardian prover", "error", err)

		return c.JSON(http.StatusBadRequest, err)
	}

	// otherwise, we can store it in the database.
	if err := srv.signedBlockRepo.Save(guardianproverhealthcheck.SaveSignedBlockOpts{
		GuardianProverID: recoveredGuardianProver.ID.Uint64(),
		BlockID:          req.BlockID,
		BlockHash:        req.BlockHash,
		Signature:        req.Signature,
		RecoveredAddress: recoveredGuardianProver.Address.Hex(),
	}); err != nil {
		// if its a duplicate entry, we just return empty response with
		// status 200 instead of an error.
		if strings.Contains(err.Error(), "Duplicate entry") {
			return c.JSON(http.StatusOK, nil)
		}

		slog.Error("error saving signed block to db", "error", err)

		return c.JSON(http.StatusBadRequest, err)
	}

	// increment signed block metric
	for _, v := range srv.guardianProvers {
		if v.Address.Hex() == recoveredGuardianProver.Address.Hex() {
			v.SignedBlockCounter.Inc()
		}
	}

	slog.Info("successful signed block", "guardianProver", recoveredGuardianProver.Address.Hex())

	return c.JSON(http.StatusOK, nil)
}
