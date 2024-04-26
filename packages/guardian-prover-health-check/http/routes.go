package http

func (srv *Server) configureRoutes() {
	srv.echo.GET("/healthz", srv.Health)
	srv.echo.GET("/", srv.Health)

	srv.echo.GET("/healthchecks", srv.GetHealthChecks)

	srv.echo.GET("/healthchecks/:address", srv.GetHealthChecksByGuardianProverAddress)

	srv.echo.GET("/liveness/:address", srv.GetMostRecentHealthCheckByGuardianProverAddress)

	srv.echo.GET("/uptime/:address", srv.GetUptimeByGuardianProverAddress)

	srv.echo.GET("/signedBlocks", srv.GetSignedBlocks)

	srv.echo.GET("/signedBlock/:address", srv.GetMostRecentSignedBlockByGuardianProverAddress)

	srv.echo.POST("/signedBlock", srv.PostSignedBlock)

	srv.echo.POST("/healthCheck", srv.PostHealthCheck)

	srv.echo.GET("/startups/:address", srv.GetStartupsByGuardianProverAddress)

	srv.echo.GET("/mostRecentStartup/:address", srv.GetMostRecentStartupByGuardianProverAddress)

	srv.echo.POST("/startup", srv.PostStartup)

	srv.echo.GET("/nodeInfo/:address", srv.GetNodeInfoByGuardianProverAddress)
}
