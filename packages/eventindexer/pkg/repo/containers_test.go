package repo

import (
	"context"
	"database/sql"
	"fmt"
	"os"
	"sync"
	"testing"
	"time"

	"github.com/docker/go-connections/nat"
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
			Cmd: []string{
				"--default-authentication-plugin=mysql_native_password",
				"--max_connections=50",
			},
			WaitingFor: wait.ForAll(
				// MySQL typically prints "ready for connections" twice during startup
				wait.ForLog("ready for connections").WithOccurrence(2),
				// Also actively probe SQL readiness from inside the container network
				wait.ForSQL("3306/tcp", "mysql", func(host string, port nat.Port) string {
					// Important: DSN used by the wait strategy should target the container-host
					// given by testcontainers, not 127.0.0.1. No db name is fine here.
					return fmt.Sprintf("%s:%s@tcp(%s:%s)/%s?parseTime=true&multiStatements=true&tls=false"+
						"&timeout=15s&readTimeout=30s&writeTimeout=30s",
						dbUsername, dbPassword, host, port.Port(), dbName)
				}).WithPollInterval(2*time.Second),
			).WithDeadline(3 * time.Minute),
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

		mp, err := sharedContainer.MappedPort(ctx, "3306/tcp")
		if err != nil {
			return
		}

		// DSN used by the tests (to connect from the host side)
		sharedDSN = fmt.Sprintf("%s:%s@tcp(%s:%d)/%s?parseTime=true&multiStatements=true&tls=false"+
			"&timeout=15s&readTimeout=30s&writeTimeout=30s",
			dbUsername, dbPassword, host, mp.Int(), dbName)

		// Final sanity ping with context + backoff (usually instant thanks to the wait strategy).
		backoff := time.Second
		deadline := time.Now().Add(1 * time.Minute)

		for {
			var testDB *gorm.DB

			testDB, err = gorm.Open(mysql.Open(sharedDSN), &gorm.Config{
				Logger: logger.Default.LogMode(logger.Silent),
			})

			if err == nil {
				if sqlDB, sqlErr := testDB.DB(); sqlErr == nil && sqlDB != nil {
					sqlDB.SetMaxOpenConns(1)
					sqlDB.SetMaxIdleConns(1)
					sqlDB.SetConnMaxLifetime(3 * time.Minute)

					ctxPing, cancel := context.WithTimeout(ctx, 5*time.Second)
					pingErr := sqlDB.PingContext(ctxPing)

					cancel()

					_ = sqlDB.Close()

					if pingErr == nil {
						break
					}

					// Store ping error for potential debugging
					_ = pingErr
				}
			}

			if time.Now().After(deadline) {
				return
			}

			time.Sleep(backoff)

			if backoff < 5*time.Second {
				backoff *= 2
			}
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

	// List of tables to clean (excluding goose_db_version)
	// Order matters for foreign key constraints - child tables first
	tables := []string{
		"erc20_balances", // Child table first
		"erc20_metadata", // Parent table second
		"nft_balances",
		"events",
		"transactions",
		"time_series_data",
		"accounts",
	}

	// Clean each table (use DELETE to handle foreign keys gracefully)
	for _, table := range tables {
		if _, err := sqlDB.Exec(fmt.Sprintf("DELETE FROM %s", table)); err != nil {
			// Re-enable foreign key checks even if delete fails
			_, _ = sqlDB.Exec("SET FOREIGN_KEY_CHECKS = 1")

			return fmt.Errorf("failed to clean table %s: %w", table, err)
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

	for i := 0; i < 15; i++ {
		gormDB, err = gorm.Open(mysql.Open(sharedDSN), &gorm.Config{
			Logger: logger.Default.LogMode(logger.Error),
		})
		if err == nil {
			// Test the connection immediately
			sqlDBTest, sqlErr := gormDB.DB()
			if sqlErr == nil {
				// Configure connection settings
				sqlDBTest.SetMaxOpenConns(1)
				sqlDBTest.SetMaxIdleConns(0)
				sqlDBTest.SetConnMaxLifetime(time.Minute)

				pingErr := sqlDBTest.Ping()
				if pingErr == nil {
					break
				}
			}
		}

		time.Sleep(2 * time.Second)
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
	_ = row.Scan(&version)

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
