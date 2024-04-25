package http

func (srv *Server) configureRoutes() {
	srv.echo.GET("/healthz", srv.Health)
	srv.echo.GET("/", srv.Health)

	srv.echo.GET("/healthchecks", srv.GetHealthChecks)

	srv.echo.GET("/healthchecks/:id", srv.GetHealthChecksByGuardianProverAddress)

	srv.echo.GET("/liveness/:id", srv.GetMostRecentHealthCheckByGuardianProverAddress)

	srv.echo.GET("/uptime/:id", srv.GetUptimeByGuardianProverAddress)

	srv.echo.GET("/signedBlocks", srv.GetSignedBlocks)

	srv.echo.GET("/signedBlock/:id", srv.GetMostRecentSignedBlockByGuardianProverAddress)

	srv.echo.POST("/signedBlock", srv.PostSignedBlock)

	srv.echo.POST("/healthCheck", srv.PostHealthCheck)

	srv.echo.GET("/startups/:id", srv.GetStartupsByGuardianProverAddress)

	srv.echo.GET("/mostRecentStartup/:id", srv.GetMostRecentStartupByGuardianProverAddress)

	srv.echo.POST("/startup", srv.PostStartup)

	srv.echo.GET("/nodeInfo/:id", srv.GetNodeInfoByGuardianProverAddress)
}
