package repo

import (
	"context"
	"fmt"
	"testing"

	"github.com/pressly/goose/v3"
	"github.com/taikoxyz/taiko-mono/packages/guardian-prover-health-check/db"
	"github.com/testcontainers/testcontainers-go"
	"github.com/testcontainers/testcontainers-go/wait"
	"gorm.io/driver/mysql"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

var (
	dbName     = "guardianproverhealthcheck"
	dbUsername = "root"
	dbPassword = "password"
)

func testMysql(t *testing.T) (DB, func(), error) {
	req := testcontainers.ContainerRequest{
		Image:        "mysql:latest",
		ExposedPorts: []string{"3306/tcp", "33060/tcp"},
		Env: map[string]string{
			"MYSQL_ROOT_PASSWORD": dbPassword,
			"MYSQL_DATABASE":      dbName,
		},
		WaitingFor: wait.ForLog("port: 3306  MySQL Community Server - GPL"),
	}

	ctx := context.Background()

	mysqlC, err := testcontainers.GenericContainer(ctx, testcontainers.GenericContainerRequest{
		ContainerRequest: req,
		Started:          true,
	})

	if err != nil {
		t.Fatal(err)
	}

	closeContainer := func() {
		err := mysqlC.Terminate(ctx)
		if err != nil {
			t.Fatal(err)
		}
	}

	host, _ := mysqlC.Host(ctx)
	p, _ := mysqlC.MappedPort(ctx, "3306/tcp")
	port := p.Int()

	dsn := fmt.Sprintf("%s:%s@tcp(%s:%d)/%s?tls=skip-verify&parseTime=true&multiStatements=true",
		dbUsername, dbPassword, host, port, dbName)

	gormDB, err := gorm.Open(mysql.Open(dsn), &gorm.Config{
		Logger: logger.Default.LogMode(logger.Silent),
	})
	if err != nil {
		t.Fatal(err)
	}

	if err := goose.SetDialect("mysql"); err != nil {
		t.Fatal(err)
	}

	sqlDB, _ := gormDB.DB()
	if err := goose.Up(sqlDB, "../migrations"); err != nil {
		t.Fatal(err)
	}

	return db.New(gormDB), closeContainer, nil
}
