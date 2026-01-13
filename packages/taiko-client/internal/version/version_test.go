package version

import "testing"

var tests = []struct {
	testname  string
	meta      string
	GitCommit string
	GitDate   string
	out       string
}{
	{"default", "dev", "", "", "1.10.1-dev"},
	{"stable meta with empty gitdate gitcommit", "stable", "", "", "1.10.1-stable"},
	{"dev with gitdate", "dev", "", "2025-08-15", "1.10.1-dev-2025-08-15"},
	{"dev with short commit", "dev", "abcdefg", "2025-08-15", "1.10.1-dev-2025-08-15"},
	{"dev with commit", "dev", "abcdefgh", "2025-08-15", "1.10.1-dev-abcdefgh-2025-08-15"},
	{"stable with commit", "stable", "abcdefgh", "", "1.10.1-stable-abcdefgh"},
	{"stable with commit and date", "stable", "abcdefgh", "2025-08-15", "1.10.1-stable-abcdefgh"},
	{"long commit", "dev", "abcdefghi", "2025-08-15", "1.10.1-dev-abcdefgh-2025-08-15"},
	{"empty meta", "", "abcdefgh", "2025-08-15", "1.10.1--abcdefgh-2025-08-15"},
	{"other meta", "test", "", "2025-08-15", "1.10.1-test-2025-08-15"},
	{"gitdate with stable meta no commit", "stable", "", "2025-08-15", "1.10.1-stable"},
}

func TestCommitVersion(t *testing.T) {
	for _, test := range tests {
		t.Run(test.testname, func(t *testing.T) {
			// save
			ogMeta, ogGitCommit, ogGitDate := meta, GitCommit, GitDate
			defer func() {
				meta, GitCommit, GitDate = ogMeta, ogGitCommit, ogGitDate
			}()
			// set
			meta, GitCommit, GitDate = test.meta, test.GitCommit, test.GitDate
			// test
			vsn := CommitVersion()
			if vsn != test.out {
				t.Errorf("got %q, wanted %q", vsn, test.out)
			}
		})
	}
}
