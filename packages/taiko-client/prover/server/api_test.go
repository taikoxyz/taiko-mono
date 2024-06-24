package server

import (
	"encoding/json"
	"io"
	"net/http"
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
