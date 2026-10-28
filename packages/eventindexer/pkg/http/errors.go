package http

import "github.com/cyberhorsey/errors"

var (
	ErrNoHTTPFramework = errors.Validation.NewWithKeyAndDetail(
		"ERR_NO_HTTP_ENGINE",
		"HTTP framework required",
	)
)
