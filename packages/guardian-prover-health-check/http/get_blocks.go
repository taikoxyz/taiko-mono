package http

import (
	"encoding/json"
	"io"
	"net/http"

	"github.com/ethereum/go-ethereum/common"
	echo "github.com/labstack/echo/v4"
)

type signedBlock struct {
	BlockID   uint64         `json:"blockID"`
	BlockHash string         `json:"blockHash"`
	Signature string         `json:"signature"`
	Prover    common.Address `json:"proverAddress"`
}

type guardianProverInfo struct {
	GuardianProverID uint64 `json:"guardianProverID"`
	signedBlocks     []signedBlock
}

type block struct {
	BlockHash        string `json:"blockHash"`
	Signature        string `json:"signature"`
	GuardianProverID uint64 `json:"guardianProverID"`
}

// map of blockID to guardianProverInfo
type blockInfo map[uint64][]block

// GetBlocks
//
//	 returns signed block data by each guardian prover.
//
//			@Summary		Get signed blocks
//			@ID			   	get-blocks
//			@Accept			json
//			@Produce		json
//			@Success		200	{object} []guardianproverhealthcheck.GuardianProver
//			@Router			/blocks [get]

func (srv *Server) GetBlocks(c echo.Context) error {
	signedBlocks := []guardianProverInfo{}
	// call each guardian prover and get their most recently signed blocks.
	for _, g := range srv.guardianProvers {
		r := []signedBlock{}

		resp, err := http.Get(g.Endpoint.String() + "/signedBlocks")
		if err != nil {
			return c.JSON(http.StatusBadRequest, err)
		}

		b, err := io.ReadAll(resp.Body)
		if err != nil {
			return c.JSON(http.StatusBadRequest, err)
		}

		if err := json.Unmarshal(b, &r); err != nil {
			return c.JSON(http.StatusBadRequest, err)
		}

		signedBlocks = append(signedBlocks, guardianProverInfo{
			GuardianProverID: g.ID.Uint64(),
			signedBlocks:     r,
		})
	}

	blocks := make(blockInfo)
	// then iterate over each one and create a more easily parsable api response
	// for the frontend to consume.
	for _, v := range signedBlocks {
		for _, sb := range v.signedBlocks {
			b := block{
				GuardianProverID: v.GuardianProverID,
				BlockHash:        sb.BlockHash,
				Signature:        sb.Signature,
			}

			if _, ok := blocks[sb.BlockID]; !ok {
				blocks[sb.BlockID] = make([]block, 0)
			}

			blocks[sb.BlockID] = append(blocks[sb.BlockID], b)
		}
	}

	return c.JSON(http.StatusOK, blocks)
}
