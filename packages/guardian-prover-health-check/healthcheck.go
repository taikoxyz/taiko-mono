package guardianproverhealthcheck

type HealthCheck struct {
	ID               int
	GuardianProverID uint64
	Alive            bool
	ExpectedAddress  string
	RecoveredAddress string
	SignedResponse   string
}

type SaveHealthCheckOpts struct {
	GuardianProverID uint64
	Alive            bool
	ExpectedAddress  string
	RecoveredAddress string
	SignedResponse   string
}

type HealthCheckRepository interface {
	Save(opts SaveHealthCheckOpts) error
}
