package flags

import (
	"testing"

	"github.com/stretchr/testify/require"
	"github.com/urfave/cli/v2"
)

func flagNames(flags []cli.Flag) []string {
	names := make([]string, 0, len(flags))
	for _, flag := range flags {
		names = append(names, flag.Names()...)
	}
	return names
}

func TestCommonFlagsExcludeInbox(t *testing.T) {
	names := flagNames(CommonFlags)

	require.Contains(t, names, InboxAddress.Name)
}
