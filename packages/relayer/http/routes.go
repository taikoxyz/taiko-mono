package http

func (srv *Server) configureRoutes() {
	srv.echo.GET("/healthz", srv.Health)
}
