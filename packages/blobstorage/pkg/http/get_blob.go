package http

import (
	"errors"
	"net/http"

	"github.com/cyberhorsey/webutils"
	echo "github.com/labstack/echo/v4"
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
	blobHash := c.Param("blobHash")
	if blobHash == "" {
		return webutils.LogAndRenderErrors(c, http.StatusBadRequest, errors.New("empty blobHash queryparam"))
	}

	data, err := srv.getBlobData(blobHash)

	if err != nil {
		return webutils.LogAndRenderErrors(c, http.StatusBadRequest, err)
	}

	return c.JSON(http.StatusOK, blobData{
		BlobHash:   data.BlobHash,
		Commitment: data.Commitment,
		Data:       data.Data,
	})
}

// getBlobData retrieves blob data from MySQL based on blobHashes.
func (srv *Server) getBlobData(blobHash string) (*blobData, error) {
	bh, err := srv.blobHashRepo.FirstByBlobHash(blobHash)
	if err != nil {
		return nil, err
	}

	return &blobData{
		BlobHash:   bh.BlobHash,
		Commitment: bh.KzgCommitment,
		Data:       bh.BlobData,
	}, nil
}
