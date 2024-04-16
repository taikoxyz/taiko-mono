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
	BlobHash      string `bson:"blob_hash" json:"blob_hash"`
	KzgCommitment string `bson:"kzg_commitment" json:"kzg_commitment"`
	Blob          string `bson:"blob" json:"blob"`
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
	blobHashes := c.QueryParam("blobHash")
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
			BlobHash:      d.BlobHash,
			KzgCommitment: d.KzgCommitment,
			Blob:          d.Blob,
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
				result.KzgCommitment = "NOT_FOUND"
				result.Blob = "NOT_FOUND"
			} else {
				// Return error for other types of errors
				return nil, err
			}
		} else {
			result.BlobHash = bh.BlobHash
			result.KzgCommitment = bh.KzgCommitment
			result.Blob = bh.BlobData

			results = append(results, result)
		}
	}

	return results, nil
}
