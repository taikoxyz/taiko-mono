package repo

import (
	"context"
	"fmt"
	"testing"
	"time"

	"github.com/docker/go-connections/nat"
	"github.com/pressly/goose/v3"
	"github.com/testcontainers/testcontainers-go"
	"github.com/testcontainers/testcontainers-go/wait"
	"gorm.io/driver/mysql"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"

	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/db"
)

var (
	dbName     = "relayer"
	dbUsername = "root"
	dbPassword = "password"
)

func testMysql(t *testing.T) (db.DB, func(), error) {
	req := testcontainers.ContainerRequest{
		Image:        "mysql:latest",
		ExposedPorts: []string{"3306/tcp", "33060/tcp"},
		Env: map[string]string{
			"MYSQL_ROOT_PASSWORD": dbPassword,
			"MYSQL_DATABASE":      dbName,
		},
		WaitingFor: wait.ForListeningPort(nat.Port("3306/tcp")).WithStartupTimeout(30 * time.Second),
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
	if err := goose.Up(sqlDB, "../../migrations"); err != nil {
		t.Fatal(err)
	}

	return db.New(gormDB), closeContainer, nil
}
