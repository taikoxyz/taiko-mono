package pkg

import (
	"errors"
)

var (
	ErrBlobUsed           = errors.New("blob is used")
	ErrNoBlobHashes       = errors.New("no blob hashes provided")
	ErrSidecarNotFound    = errors.New("sidecar not found")
	ErrBeaconNotFound     = errors.New("beacon client not found")
	ErrInvalidShastaBlobs = errors.New("invalid Shasta blobs")
)
