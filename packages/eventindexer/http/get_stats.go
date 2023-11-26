package http

import (
	"net/http"
	"time"

	"github.com/cyberhorsey/webutils"
	"github.com/labstack/echo/v4"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
)

type proofRewardStatResponse struct {
	AverageProofReward string `json:"averageProofReward"`
	FeeTokenAddress    string `json:"feeTokenAddress"`
	NumBlocksAssigned  uint64 `json:"numBlocksAssigned"`
}
type statsResponse struct {
	AverageProofTime    string                    `json:"averageProofTime"`
	NumProofs           uint64                    `json:"numProofs"`
	AverageProofRewards []proofRewardStatResponse `json:"averageProofRewards"`
}

// GetStats returns the current computed stats for the deployed network.
//
//	@Summary		Get stats
//	@ID			   	get-stats
//	@Accept			json
//	@Produce		json
//	@Success		200	{object} eventindexer.Stat
//	@Router			/stats [get]
func (srv *Server) GetStats(c echo.Context) error {
	cached, found := srv.cache.Get(CacheKeyStats)

	var statsResp *statsResponse = &statsResponse{
		AverageProofRewards: make([]proofRewardStatResponse, 0),
	}

	if found {
		statsResp = cached.(*statsResponse)
	} else {
		stats, err := srv.statRepo.FindAll(
			c.Request().Context(),
		)
		if err != nil {
			return webutils.LogAndRenderErrors(c, http.StatusUnprocessableEntity, err)
		}

		for _, s := range stats {
			if s.StatType == eventindexer.StatTypeProofTime {
				statsResp.AverageProofTime = s.AverageProofTime
				statsResp.NumProofs = s.NumProofs
			}

			if s.StatType == eventindexer.StatTypeProofReward {
				statsResp.AverageProofRewards = append(statsResp.AverageProofRewards, proofRewardStatResponse{
					AverageProofReward: s.AverageProofReward,
					FeeTokenAddress:    s.FeeTokenAddress,
					NumBlocksAssigned:  s.NumBlocksAssigned,
				})
			}
		}

		srv.cache.Set(CacheKeyStats, statsResp, 1*time.Minute)
	}

	return c.JSON(http.StatusOK, statsResp)
}
