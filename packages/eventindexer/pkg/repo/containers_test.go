package repo

import (
	"context"
	"database/sql"
	"fmt"
	"os"
	"sync"
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

	// Package-level variables for container reuse
	sharedContainer testcontainers.Container
	sharedDSN       string
	containerMutex  sync.Mutex
	setupOnce       sync.Once
)

// TestMain sets up and tears down the shared container
func TestMain(m *testing.M) {
	code := m.Run()

	// Cleanup the container after all tests
	if sharedContainer != nil {
		ctx := context.Background()
		_ = sharedContainer.Terminate(ctx)
	}

	os.Exit(code)
}

// setupSharedContainer initializes the shared MySQL container once
func setupSharedContainer() error {
	var err error
	setupOnce.Do(func() {
		req := testcontainers.ContainerRequest{
			Image:        "mysql:8.0.36",
			ExposedPorts: []string{"3306/tcp"},
			Env: map[string]string{
				"MYSQL_ROOT_PASSWORD": dbPassword,
				"MYSQL_DATABASE":      dbName,
			},
			WaitingFor: wait.ForAll(
				wait.ForLog("MySQL Community Server - GPL"),
				wait.ForLog("ready for connections"),
			).WithStartupTimeout(2 * time.Minute),
		}

		ctx := context.Background()

		sharedContainer, err = testcontainers.GenericContainer(ctx, testcontainers.GenericContainerRequest{
			ContainerRequest: req,
			Started:          true,
		})

		if err != nil {
			return
		}

		host, err := sharedContainer.Host(ctx)
		if err != nil {
			return
		}

		port, err := sharedContainer.MappedPort(ctx, "3306/tcp")
		if err != nil {
			return
		}

		sharedDSN = fmt.Sprintf("%s:%s@tcp(%s:%d)/%s?tls=skip-verify&parseTime=true&multiStatements=true",
			dbUsername, dbPassword, host, port.Int(), dbName)

		// Wait a bit more for MySQL to be fully ready
		time.Sleep(5 * time.Second)

		// Test the connection with retries
		var testDB *gorm.DB
		for i := 0; i < 10; i++ {
			testDB, err = gorm.Open(mysql.Open(sharedDSN), &gorm.Config{
				Logger: logger.Default.LogMode(logger.Silent),
			})
			if err == nil {
				sqlDB, _ := testDB.DB()
				if sqlDB != nil {
					err = sqlDB.Ping()
					if err == nil {
						sqlDB.Close()
						break
					}
				}
			}
			time.Sleep(2 * time.Second)
		}
	})
	return err
}

// runMigrations runs the up migrations
func runMigrations(sqlDB *sql.DB) error {
	if err := goose.SetDialect("mysql"); err != nil {
		return err
	}
	return goose.Up(sqlDB, "../../migrations")
}

// cleanDatabase truncates all tables to reset data while keeping schema
func cleanDatabase(sqlDB *sql.DB) error {
	// Disable foreign key checks temporarily
	if _, err := sqlDB.Exec("SET FOREIGN_KEY_CHECKS = 0"); err != nil {
		return err
	}

	// List of tables to truncate (excluding goose_db_version)
	tables := []string{
		"events",
		"nft_balances",
		"transactions",
		"time_series_data",
		"accounts",
		"erc20_metadata",
		"erc20_balances",
	}

	// Truncate each table
	for _, table := range tables {
		if _, err := sqlDB.Exec(fmt.Sprintf("TRUNCATE TABLE %s", table)); err != nil {
			// Re-enable foreign key checks even if truncate fails
			sqlDB.Exec("SET FOREIGN_KEY_CHECKS = 1")
			return fmt.Errorf("failed to truncate table %s: %w", table, err)
		}
	}

	// Re-enable foreign key checks
	if _, err := sqlDB.Exec("SET FOREIGN_KEY_CHECKS = 1"); err != nil {
		return err
	}

	return nil
}

// testMysql provides a clean database for each test
func testMysql(t *testing.T) (db.DB, func(), error) {
	// Ensure the shared container is set up
	if err := setupSharedContainer(); err != nil {
		t.Fatal("Failed to setup shared container:", err)
	}

	// Lock to ensure thread-safe access when multiple tests run in parallel
	containerMutex.Lock()
	defer containerMutex.Unlock()

	// Try to connect with retries
	var gormDB *gorm.DB
	var err error
	for i := 0; i < 5; i++ {
		gormDB, err = gorm.Open(mysql.Open(sharedDSN), &gorm.Config{
			Logger: logger.Default.LogMode(logger.Error),
		})
		if err == nil {
			break
		}
		time.Sleep(time.Second)
	}

	if err != nil {
		t.Fatal("Failed to connect to database after retries:", err)
	}

	sqlDB, err := gormDB.DB()
	if err != nil {
		t.Fatal("Failed to get sql.DB:", err)
	}

	// Check if we need to run migrations (first test only)
	var version int64
	row := sqlDB.QueryRow("SELECT MAX(version_id) FROM goose_db_version")
	row.Scan(&version)

	if version == 0 {
		// First test - run migrations to set up schema
		if err := runMigrations(sqlDB); err != nil {
			t.Fatal("Failed to run migrations:", err)
		}
	} else {
		// Subsequent tests - just clean the data
		if err := cleanDatabase(sqlDB); err != nil {
			t.Fatal("Failed to clean database:", err)
		}
	}

	// Return cleanup function that closes the DB connection
	cleanup := func() {
		// We don't close the container anymore, just close the DB connection
		sqlDB.Close()
	}

	return db.New(gormDB), cleanup, nil
}
