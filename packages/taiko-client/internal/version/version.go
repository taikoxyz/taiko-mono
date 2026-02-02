package version

// Version info.
const Version = "2.1.0" // x-release-please-version

var meta = "dev"

// Git commit/date info, set via linker flags.
var (
	GitCommit = ""
	GitDate   = ""
)

// CommitVersion returns a textual version string including Git commit/date information.
func CommitVersion() string {
	vsn := Version + "-" + meta
	if len(GitCommit) >= 8 {
		vsn += "-" + GitCommit[:8]
	}
	if (meta != "stable") && (GitDate != "") {
		vsn += "-" + GitDate
	}
	return vsn
}
