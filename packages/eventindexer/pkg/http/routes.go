package http

func (srv *Server) configureRoutes() {
	srv.echo.GET("/healthz", srv.Health)
	srv.echo.GET("/", srv.Health)

	srv.echo.GET("/uniqueProvers", srv.GetUniqueProvers)
	srv.echo.GET("/uniqueProposers", srv.GetUniqueProposers)
	srv.echo.GET("/eventByAddress", srv.GetCountByAddressAndEventName)
	srv.echo.GET("/events", srv.GetByAddressAndEventName)
	srv.echo.GET("/assignedBlocks", srv.GetAssignedBlocksByProverAddress)
	srv.echo.GET("/nftsByAddress", srv.GetNFTBalancesByAddressAndChainID)
	srv.echo.GET("/blockProvenBy", srv.GetBlockProvenBy)
	srv.echo.GET("/blockProposedBy", srv.GetBlockProposedBy)
	srv.echo.GET("/erc20ByAddress", srv.GetERC20BalancesByAddressAndChainID)

	galaxeAPI := srv.echo.Group("/api")

	galaxeAPI.GET("/user-proposed-block", srv.UserProposedBlock)
	galaxeAPI.GET("/user-proved-block", srv.UserProvedBlock)
	galaxeAPI.GET("/user-bridged", srv.UserBridged)

	chartAPI := srv.echo.Group("/chart")

	chartAPI.GET("/chartByTask", srv.GetChartByTask)
}
