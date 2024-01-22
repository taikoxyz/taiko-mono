package flags

import "github.com/urfave/cli/v2"

var (
	QueueUsername = &cli.StringFlag{
		Name:     "queue.username",
		Usage:    "Queue connection username",
		Required: true,
		Category: commonCategory,
		EnvVars:  []string{"QUEUE_USER"},
	}
	QueuePassword = &cli.StringFlag{
		Name:     "queue.password",
		Usage:    "Queue connection password",
		Required: true,
		Category: commonCategory,
		EnvVars:  []string{"QUEUE_PASSWORD"},
	}
	QueueHost = &cli.StringFlag{
		Name:     "queue.host",
		Usage:    "Queue connection host",
		Required: true,
		Category: commonCategory,
		EnvVars:  []string{"QUEUE_HOST"},
	}
	QueuePort = &cli.Uint64Flag{
		Name:     "queue.port",
		Usage:    "Queue connection port",
		Required: true,
		Category: commonCategory,
		EnvVars:  []string{"QUEUE_PORT"},
	}
)

var QueueFlags = []cli.Flag{
	QueueUsername,
	QueuePassword,
	QueueHost,
	QueuePort,
}
