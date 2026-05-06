package http

import "github.com/cyberhorsey/errors"

var (
	ErrNoHTTPFramework = errors.Validation.NewWithKeyAndDetail(
		"ERR_NO_HTTP_ENGINE",
		"HTTP framework required",
	)
	ErrNoRewarder = errors.Validation.NewWithKeyAndDetail(
		"ERR_NO_REWARDER",
		"Rewarder is required",
	)
	ErrNoTaikoL2 = errors.Validation.NewWithKeyAndDetail(
		"ERR_NO_TAIKO_L2",
		"TaikoL2 is required",
	)
)
