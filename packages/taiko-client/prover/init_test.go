package prover

func (s *ProverTestSuite) TestInitUsesShastaSubmitterOnly() {
	s.NotNil(s.p.proofSubmitter)
}
