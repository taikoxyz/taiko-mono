package http

func (srv *Server) configureRoutes() {
	srv.echo.GET("/healthz", srv.Health)
	srv.echo.GET("/", srv.Health)

	srv.echo.GET("/healthchecks", srv.GetHealthChecks)

	srv.echo.GET("/healthchecks/:id", srv.GetHealthChecksByGuardianProverID)

	srv.echo.GET("/liveness/:id", srv.GetMostRecentHealthCheckByGuardianProverID)

	srv.echo.GET("/uptime/:id", srv.GetUptimeByGuardianProverID)

	srv.echo.GET("/signedBlocks", srv.GetSignedBlocks)

	srv.echo.GET("/signedBlock/:id", srv.GetMostRecentSignedBlockByGuardianProverID)

	srv.echo.POST("/signedBlock", srv.PostSignedBlock)

	srv.echo.POST("/healthCheck", srv.PostHealthCheck)

	srv.echo.GET("/startups/:id", srv.GetStartupsByGuardianProverID)

	srv.echo.GET("/mostRecentStartup/:id", srv.GetMostRecentStartupByGuardianProverID)

	srv.echo.POST("/startup", srv.PostStartup)

	srv.echo.GET("/nodeInfo/:id", srv.GetNodeInfoByGuardianProverID)
}
