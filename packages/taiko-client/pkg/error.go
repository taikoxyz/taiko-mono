package pkg

import (
	"errors"
)

var (
	ErrBlobUsed        = errors.New("blob is used")
	ErrBlobUnused      = errors.New("blob is not used")
	ErrSidecarNotFound = errors.New("sidecar not found")
	ErrBeaconNotFound  = errors.New("beacon client not found")
)
