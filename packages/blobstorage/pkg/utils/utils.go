package utils

import (
	"time"

	"golang.org/x/exp/constraints"
)

const (
	DefaultTimeout = 1 * time.Minute
)

// Min return the minimum value of two integers.
func Min[T constraints.Integer](a, b T) T {
	if a < b {
		return a
	}
	return b
}

// Max return the maximum value of two integers.
func Max[T constraints.Integer](a, b T) T {
	if a > b {
		return a
	}
	return b
}
