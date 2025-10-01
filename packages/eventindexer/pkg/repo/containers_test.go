package repo

// var (
// 	dbName     = "indexer"
// 	dbUsername = "root"
// 	dbPassword = "password"
// )

// func testMysql(t *testing.T) (db.DB, func(), error) {
// 	req := testcontainers.ContainerRequest{
// 		Image:        "mysql:latest",
// 		ExposedPorts: []string{"3306/tcp"},
// 		Env: map[string]string{
// 			"MYSQL_ROOT_PASSWORD": dbPassword,
// 			"MYSQL_DATABASE":      dbName,
// 		},
// 		WaitingFor: wait.ForLog("port: 3306  MySQL Community Server - GPL"),
// 	}

// 	ctx := context.Background()

// 	mysqlC, err := testcontainers.GenericContainer(ctx, testcontainers.GenericContainerRequest{
// 		ContainerRequest: req,
// 		Started:          true,
// 	})

// 	if err != nil {
// 		t.Fatal(err)
// 	}

// 	closeContainer := func() {
// 		err := mysqlC.Terminate(ctx)
// 		if err != nil {
// 			t.Fatal(err)
// 		}
// 	}

// 	host, _ := mysqlC.Host(ctx)
// 	port, _ := mysqlC.MappedPort(ctx, "3306/tcp")

// 	dsn := fmt.Sprintf("%s:%s@tcp(%s:%d)/%s?tls=skip-verify&parseTime=true&multiStatements=true",
// 		dbUsername, dbPassword, host, port.Int(), dbName)

// 	gormDB, err := gorm.Open(mysql.Open(dsn), &gorm.Config{
// 		Logger: logger.Default.LogMode(logger.Silent),
// 	})
// 	if err != nil {
// 		t.Fatal(err)
// 	}

// 	if err := goose.SetDialect("mysql"); err != nil {
// 		t.Fatal(err)
// 	}

// 	sqlDB, _ := gormDB.DB()
// 	if err := goose.Up(sqlDB, "../../migrations"); err != nil {
// 		t.Fatal(err)
// 	}

// 	return db.New(gormDB), closeContainer, nil
// }
