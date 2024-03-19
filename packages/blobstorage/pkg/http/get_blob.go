package http

import (
	"errors"
	"net/http"
	"strings"

	"github.com/cyberhorsey/webutils"
	echo "github.com/labstack/echo/v4"
	"gorm.io/gorm"
)

type resp struct {
	Data []blobData `bson:"data" json:"data"`
}

type blobData struct {
	Blob          string `bson:"blob_hash" json:"blob_hash"`
	KzgCommitment string `bson:"kzg_commitment" json:"kzg_commitment"`
}

func (srv *Server) GetBlob(c echo.Context) error {
	blobHashes := c.QueryParam("blobHash")
	if blobHashes == "" {
		return webutils.LogAndRenderErrors(c, http.StatusBadRequest, errors.New("empty blobHash queryparam"))
	}

	data, err := srv.getBlobData(strings.Split(blobHashes, ","))
	if err != nil {
		return webutils.LogAndRenderErrors(c, http.StatusBadRequest, err)
	}

	response := resp{
		Data: make([]blobData, 0),
	}

	// Convert data to the correct type
	for _, d := range data {
		response.Data = append(response.Data, blobData{
			Blob:          d.Blob,
			KzgCommitment: d.KzgCommitment,
		},
		)
	}

	return c.JSON(http.StatusOK, response)
}

// getBlobData retrieves blob data from MongoDB based on blobHashes.
func (srv *Server) getBlobData(blobHashes []string) ([]blobData, error) {
	var results []blobData

	for _, blobHash := range blobHashes {
		var result blobData

		bh, err := srv.blobHashRepo.FirstByBlobHash(blobHash)

		if err != nil {
			if err == gorm.ErrRecordNotFound {
				// Handle case where blob hash is not found
				result.Blob = "NOT_FOUND"
				result.KzgCommitment = "NOT_FOUND"
			} else {
				// Return error for other types of errors
				return nil, err
			}
		} else {
			result.Blob = bh.BlobHash
			result.KzgCommitment = bh.KzgCommitment

			results = append(results, result)
		}
	}

	return results, nil
}
