package http

func (srv *Server) configureRoutes() {
	srv.echo.GET("/healthz", srv.Health)
	srv.echo.GET("/", srv.Health)

	srv.echo.GET("/uniqueProvers", srv.GetUniqueProvers)
	srv.echo.GET("/uniqueProposers", srv.GetUniqueProposers)
	srv.echo.GET("/eventByAddress", srv.GetCountByAddressAndEventName)
	srv.echo.GET("/events", srv.GetByAddressAndEventName)
	srv.echo.GET("/stats", srv.GetStats)
	srv.echo.GET("/assignedBlocks", srv.GetAssignedBlocksByProverAddress)
	srv.echo.GET("/nftsByAddress", srv.GetNFTBalancesByAddressAndChainID)

	galaxeAPI := srv.echo.Group("/api")

	galaxeAPI.GET("/user-proposed-block", srv.UserProposedBlock)
	galaxeAPI.GET("/user-proved-block", srv.UserProvedBlock)
	galaxeAPI.GET("/user-bridged", srv.UserBridged)
	galaxeAPI.GET("/user-swapped-on-taiko", srv.UserSwappedOnTaiko)
	galaxeAPI.GET("/user-added-liquidity", srv.UserAddedLiquidity)

	chartAPI := srv.echo.Group("/chart")

	chartAPI.GET("/chartByTask", srv.GetChartByTask)
}
