package http

func (srv *Server) configureRoutes() {
	srv.echo.GET("/health", srv.Health)
}
