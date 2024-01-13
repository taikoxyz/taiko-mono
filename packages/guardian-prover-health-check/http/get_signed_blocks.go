package http

import (
	"math/big"
	"net/http"
	"strconv"

	echo "github.com/labstack/echo/v4"
	"github.com/labstack/gommon/log"
	guardianproverhealthcheck "github.com/taikoxyz/taiko-mono/packages/guardian-prover-health-check"
)

var (
	numBlocks uint64 = 100
)

type block struct {
	BlockHash        string `json:"blockHash"`
	Signature        string `json:"signature"`
	GuardianProverID uint64 `json:"guardianProverID"`
}

// map of blockID to signed block data
type blockResponse map[uint64][]block

// GetSignedBlocks
//
//	 returns signed block data by each guardian prover.
//
//			@Summary		Get signed blocks
//			@ID			   	get-signed-blocks
//			@Accept			json
//			@Produce		json
//			@Success		200	{object} blockResponse
//			@Router			/signedBlocks[get]
//		    @Param			start	query		string		false	"unix timestamp of starting block"

func (srv *Server) GetSignedBlocks(c echo.Context) error {
	// getSignedBlocks should rewind either startingBlockID - numBlocksToReturn if startingBlockID
	// is passed in, but it is optional, so if it is not, we should get latest and rewind from
	// there.
	var start uint64 = 0

	if c.QueryParam("start") != "" {
		var err error

		start, err = strconv.ParseUint(c.QueryParam("start"), 10, 64)
		if err != nil {
			return echo.NewHTTPError(http.StatusBadRequest, err)
		}
	}

	// if no start timestamp was provided, we can get the latest block, and return
	// defaultNumBlocksToReturn blocks signed before latest, if our guardian prover has signed them.
	if start == 0 {
		latestBlock, err := srv.ethClient.BlockByNumber(c.Request().Context(), nil)
		if err != nil {
			if err != nil {
				log.Error("Failed to get latest L2 block", "error", err)
				return echo.NewHTTPError(http.StatusInternalServerError, err)
			}
		}

		// if latestBlock is greater than the number of blocks to return, we only want to return
		// the most recent N blocks signed by this guardian prover.
		if latestBlock.NumberU64() > numBlocks {
			blockNum := latestBlock.NumberU64() - numBlocks

			block, err := srv.ethClient.BlockByNumber(
				c.Request().Context(),
				new(big.Int).SetUint64(blockNum),
			)
			if err != nil {
				log.Error("Failed to get L2 block", "error", err, "blockNum", blockNum)
				return echo.NewHTTPError(http.StatusInternalServerError, err)
			}

			start = block.NumberU64()
		}
	}

	signedBlocks, err := srv.signedBlockRepo.GetByStartingBlockID(
		guardianproverhealthcheck.GetSignedBlocksByStartingBlockIDOpts{
			StartingBlockID: start,
		},
	)

	if err != nil {
		log.Error("Failed to get latest L2 block", "error", err)
		return echo.NewHTTPError(http.StatusInternalServerError, err)
	}

	// sort signed blocks for easier to consume data
	blocks := make(blockResponse)
	// then iterate over each one and create a more easily parsable api response
	// for the frontend to consume, arranged by a mapping of block ID
	// to the signed blocks for each prover by that block ID.
	for _, v := range signedBlocks {
		b := block{
			GuardianProverID: v.GuardianProverID,
			BlockHash:        v.BlockHash,
			Signature:        v.Signature,
		}

		if _, ok := blocks[v.BlockID]; !ok {
			blocks[v.BlockID] = make([]block, 0)
		}

		blocks[v.BlockID] = append(blocks[v.BlockID], b)
	}

	return c.JSON(http.StatusOK, blocks)
}
