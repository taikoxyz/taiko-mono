package utils

import "golang.org/x/exp/constraints"

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
