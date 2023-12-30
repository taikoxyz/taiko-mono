package http

func (srv *Server) configureRoutes() {
	srv.echo.GET("/healthz", srv.Health)
	srv.echo.GET("/", srv.Health)

	srv.echo.GET("/healthchecks", srv.GetHealthChecks)

	srv.echo.GET("/healthchecks/:id", srv.GetHealthChecksByGuardianProverID)

	srv.echo.GET("/liveness/:id", srv.GetMostRecentHealthCheckByGuardianProverID)

	srv.echo.GET("/uptime/:id", srv.GetUptimeByGuardianProverID)

	srv.echo.GET("/signedBlocks", srv.GetSignedBlocks)

	srv.echo.POST("/signedBlock", srv.PostSignedBlock)

	srv.echo.POST("/healthCheck", srv.PostHealthCheck)
}
