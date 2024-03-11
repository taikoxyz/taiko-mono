package flags

import "github.com/urfave/cli/v2"

// MergeFlags merges the given flag slices.
func MergeFlags(groups ...[]cli.Flag) []cli.Flag {
	var merged []cli.Flag
	for _, group := range groups {
		merged = append(merged, group...)
	}

	return merged
}
