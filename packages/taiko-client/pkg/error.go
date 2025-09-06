package pkg

import (
	"errors"
)

var (
	ErrBlobUsed           = errors.New("blob is used")
	ErrBlobUnused         = errors.New("blob is not used")
	ErrSidecarNotFound    = errors.New("sidecar not found")
	ErrBlobSizeTooSmall   = errors.New("blob size too small")
	ErrBeaconNotFound     = errors.New("beacon client not found")
	ErrInvalidShastaBlobs = errors.New("invalid Shasta blobs")
)
