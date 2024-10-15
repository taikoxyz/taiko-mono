package http

import (
	"errors"
	"net/http"
	"strings"

	"github.com/cyberhorsey/webutils"
	echo "github.com/labstack/echo/v4"
	"gorm.io/gorm"
)

type getBlobResponse struct {
	Data []blobData `bson:"data" json:"data"`
}

type blobData struct {
	BlobHash   string `bson:"versionedHash" json:"versionedHash"`
	Commitment string `bson:"commitment" json:"commitment"`
	Data       string `bson:"data" json:"data"`
}

// GetBlob
//
//	 returns blob and kzg commitment by blobHash or multiple comma-separated blobHashes
//
//	@Summary	Get blob(s) and KZG commitment(s)
//	@ID			get-blob
//	@Param		blobHash	query	string	true "blobHash to query"
//	@Accept		json
//	@Produce	json
//	@Success	200	{object}	getBlobResponse
//	@Router		/getBlob [get]
func (srv *Server) GetBlob(c echo.Context) error {
	blobHashes := c.Param("blobHash")
	if blobHashes == "" {
		return webutils.LogAndRenderErrors(c, http.StatusBadRequest, errors.New("empty blobHash queryparam"))
	}

	data, err := srv.getBlobData(strings.Split(blobHashes, ","))

	if err != nil {
		return webutils.LogAndRenderErrors(c, http.StatusBadRequest, err)
	}

	response := getBlobResponse{
		Data: make([]blobData, 0),
	}

	// Convert data to the correct type
	for _, d := range data {
		response.Data = append(response.Data, blobData{
			BlobHash:   d.BlobHash,
			Commitment: d.Commitment,
			Data:       d.Data,
		},
		)
	}

	return c.JSON(http.StatusOK, response)
}

// getBlobData retrieves blob data from MySQL based on blobHashes.
func (srv *Server) getBlobData(blobHashes []string) ([]blobData, error) {
	var results []blobData

	for _, blobHash := range blobHashes {
		var result blobData

		bh, err := srv.blobHashRepo.FirstByBlobHash(blobHash)

		if err != nil {
			if err == gorm.ErrRecordNotFound {
				// Handle case where blob hash is not found
				result.BlobHash = "NOT_FOUND"
				result.Commitment = "NOT_FOUND"
				result.Data = "NOT_FOUND"
			} else {
				// Return error for other types of errors
				return nil, err
			}
		} else {
			result.BlobHash = bh.BlobHash
			result.Commitment = bh.KzgCommitment
			result.Data = bh.BlobData

			results = append(results, result)
		}
	}

	return results, nil
}
