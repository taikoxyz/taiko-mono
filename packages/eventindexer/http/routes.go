package http

func (srv *Server) configureRoutes() {
	srv.echo.GET("/healthz", srv.Health)
	srv.echo.GET("/", srv.Health)

	srv.echo.GET("/uniqueProvers", srv.GetUniqueProvers)
	srv.echo.GET("/uniqueProposers", srv.GetUniqueProposers)
	srv.echo.GET("/eventByAddress", srv.GetCountByAddressAndEventName)
}
