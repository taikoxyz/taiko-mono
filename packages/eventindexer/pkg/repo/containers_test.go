package repo

import (
	"context"
	"fmt"
	"testing"
	"time"

	"github.com/pressly/goose/v3"
	"github.com/testcontainers/testcontainers-go"
	"github.com/testcontainers/testcontainers-go/wait"
	"gorm.io/driver/mysql"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"

	"github.com/taikoxyz/taiko-mono/packages/eventindexer/pkg/db"
)

var (
	dbName     = "indexer"
	dbUsername = "root"
	dbPassword = "password"
)

func testMysql(t *testing.T) (db.DB, func(), error) {
	req := testcontainers.ContainerRequest{
		AlwaysPullImage: true,
		Image:           "mysql:latest",
		ExposedPorts:    []string{"3306/tcp", "33060/tcp"},
		Env: map[string]string{
			"MYSQL_ROOT_PASSWORD": dbPassword,
			"MYSQL_DATABASE":      dbName,
		},
		WaitingFor: wait.ForLog("port: 3306  MySQL Community Server - GPL").WithStartupTimeout(2 * time.Minute),
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

	host, err := mysqlC.Host(ctx)
	if err != nil {
		t.Fatalf("failed to resolve mysql host: %v", err)
	}

	port, err := mysqlC.MappedPort(ctx, "3306/tcp")
	if err != nil {
		t.Fatalf("failed to map mysql port: %v", err)
	}

	// nolint: lll
	dsn := fmt.Sprintf("%s:%s@tcp(%s:%d)/%s?tls=skip-verify&parseTime=true&multiStatements=true&timeout=30s&readTimeout=30s&writeTimeout=30s",
		dbUsername, dbPassword, host, port.Int(), dbName)

	deadline := time.Now().Add(2 * time.Minute)

	var gormDB *gorm.DB

	var lastErr error

	for time.Now().Before(deadline) {
		gormDB, lastErr = gorm.Open(mysql.Open(dsn), &gorm.Config{
			Logger: logger.Default.LogMode(logger.Silent),
		})
		if lastErr != nil {
			time.Sleep(2 * time.Second)
			continue
		}

		sqlDB, dbErr := gormDB.DB()
		if dbErr != nil {
			lastErr = fmt.Errorf("failed to obtain sql.DB: %w", dbErr)

			gormDB = nil

			time.Sleep(2 * time.Second)

			continue
		}

		pingErr := sqlDB.Ping()
		if pingErr == nil {
			lastErr = nil
			break
		}

		lastErr = fmt.Errorf("mysql ping failed: %w", pingErr)

		_ = sqlDB.Close()

		gormDB = nil

		time.Sleep(2 * time.Second)
	}

	if lastErr != nil {
		t.Fatalf("failed to connect to mysql container: %v", lastErr)
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
