package server

import (
	"encoding/json"
	"io"
	"net/http"
	"strings"
	"time"

	"github.com/ethereum/go-ethereum/common"

	"github.com/taikoxyz/taiko-client/bindings/encoding"
)

func (s *ProverServerTestSuite) TestGetStatusSuccess() {
	res := s.sendReq("/status")
	s.Equal(http.StatusOK, res.StatusCode)

	status := new(Status)

	defer res.Body.Close()
	b, err := io.ReadAll(res.Body)
	s.Nil(err)
	s.Nil(json.Unmarshal(b, &status))

	s.Equal(s.s.minOptimisticTierFee.Uint64(), status.MinOptimisticTierFee)
	s.Equal(s.s.minSgxTierFee.Uint64(), status.MinSgxTierFee)
	s.Equal(uint64(s.s.maxExpiry.Seconds()), status.MaxExpiry)
	s.NotEmpty(status.Prover)
}

func (s *ProverServerTestSuite) TestProposeBlockSuccess() {
	data, err := json.Marshal(CreateAssignmentRequestBody{
		FeeToken: (common.Address{}),
		TierFees: []encoding.TierFee{
			{Tier: encoding.TierOptimisticID, Fee: common.Big256},
			{Tier: encoding.TierSgxID, Fee: common.Big256},
		},
		Expiry:   uint64(time.Now().Add(time.Minute).Unix()),
		BlobHash: common.BigToHash(common.Big1),
	})
	s.Nil(err)
	res, err := http.Post(s.testServer.URL+"/assignment", "application/json", strings.NewReader(string(data)))
	s.Nil(err)
	s.Equal(http.StatusOK, res.StatusCode)
	defer res.Body.Close()
	b, err := io.ReadAll(res.Body)
	s.Nil(err)
	s.Contains(string(b), "signedPayload")
}
