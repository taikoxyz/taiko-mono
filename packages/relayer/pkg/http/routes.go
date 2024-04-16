package http

func (srv *Server) configureRoutes() {
	srv.echo.GET("/healthz", srv.Health)
	srv.echo.GET("/", srv.Health)

	srv.echo.GET("/events", srv.GetEventsByAddress)
	srv.echo.GET("/blockInfo", srv.GetBlockInfo)
	srv.echo.GET("/recommendedProcessingFees", srv.GetRecommendedProcessingFees)
}
