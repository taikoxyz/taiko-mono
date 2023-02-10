package cli

import (
	"os"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
	"github.com/taikoxyz/taiko-mono/packages/relayer/mock"
)

var dummyEcdsaKey = "8da4ef21b864d2cc526dbdb2a120bd2874c36c9d0a1fb7f8c63d7f7a8b41de8f"
var dummyAddress = "0x63FaC9201494f0bd17B9892B9fae4d52fe3BD377"

func Test_loadAndValidateEnvVars(t *testing.T) {
	for _, envVar := range envVars {
		os.Setenv(envVar, "valid")
	}

	assert.Equal(t, loadAndValidateEnv(), nil)
}

func Test_loadAndValidateEnvVars_missing(t *testing.T) {
	for _, envVar := range envVars {
		os.Setenv(envVar, "valid")
	}

	for _, envVar := range envVars {
		os.Setenv(envVar, "")

		err := loadAndValidateEnv()

		assert.NotEqual(t, err, nil)
		assert.Equal(t, true, strings.Contains(err.Error(), envVar))
		os.Setenv(envVar, "valid")
	}
}

func Test_openDBConnection(t *testing.T) {
	tests := []struct {
		name    string
		opts    relayer.DBConnectionOpts
		wantErr error
	}{
		{
			"success",
			relayer.DBConnectionOpts{
				Name:     "name",
				Password: "password",
				Host:     "host",
				Database: "database",
				OpenFunc: func(dsn string) (relayer.DB, error) {
					db, cancel, err := testMysql(t)
					if err != nil {
						return nil, err
					}

					defer cancel()

					return db, nil
				},
			},
			nil,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, err := openDBConnection(tt.opts)
			assert.Equal(t, tt.wantErr, err)
		})
	}
}

func Test_makeIndexers(t *testing.T) {
	db, cancel, err := testMysql(t)
	if err != nil {
		t.Fatal(err)
	}

	defer cancel()

	dbFunc := func(t *testing.T) relayer.DB {
		return db
	}

	tests := []struct {
		name         string
		layer        relayer.Layer
		dbFunc       func(*testing.T) relayer.DB
		envFunc      func() func()
		wantIndexers int
		wantErr      error
	}{
		{
			"successL1",
			relayer.L1,
			dbFunc,
			func() func() {
				os.Setenv("L1_RPC_URL", "https://l1rpc.a1.taiko.xyz")
				os.Setenv("L2_RPC_URL", "https://l2rpc.a1.taiko.xyz")
				os.Setenv("L1_BRIDGE_ADDRESS", dummyAddress)
				os.Setenv("L2_BRIDGE_ADDRESS", dummyAddress)
				os.Setenv("L1_TAIKO_ADDRESS", dummyAddress)
				os.Setenv("L2_TAIKO_ADDRESS", dummyAddress)
				os.Setenv("RELAYER_ECDSA_KEY", dummyEcdsaKey)

				return func() {
					os.Setenv("L1_RPC_URL", "")
					os.Setenv("L2_RPC_URL", "")
					os.Setenv("L1_BRIDGE_ADDRESS", "")
					os.Setenv("L2_BRIDGE_ADDRESS", "")
					os.Setenv("L1_TAIKO_ADDRESS", "")
					os.Setenv("L2_TAIKO_ADDRESS", "")
					os.Setenv("RELAYER_ECDSA_KEY", "")
				}
			},
			1,
			nil,
		},
		{
			"successL2",
			relayer.L2,
			dbFunc,
			func() func() {
				os.Setenv("L1_RPC_URL", "https://l1rpc.a1.taiko.xyz")
				os.Setenv("L2_RPC_URL", "https://l2rpc.a1.taiko.xyz")
				os.Setenv("L1_BRIDGE_ADDRESS", dummyAddress)
				os.Setenv("L2_BRIDGE_ADDRESS", dummyAddress)
				os.Setenv("L1_TAIKO_ADDRESS", dummyAddress)
				os.Setenv("L2_TAIKO_ADDRESS", dummyAddress)
				os.Setenv("RELAYER_ECDSA_KEY", dummyEcdsaKey)

				return func() {
					os.Setenv("L1_RPC_URL", "")
					os.Setenv("L2_RPC_URL", "")
					os.Setenv("L1_BRIDGE_ADDRESS", "")
					os.Setenv("L2_BRIDGE_ADDRESS", "")
					os.Setenv("L1_TAIKO_ADDRESS", "")
					os.Setenv("L2_TAIKO_ADDRESS", "")
					os.Setenv("RELAYER_ECDSA_KEY", "")
				}
			},
			1,
			nil,
		},
		{
			"successBoth",
			relayer.Both,
			dbFunc,
			func() func() {
				os.Setenv("L1_RPC_URL", "https://l1rpc.a1.taiko.xyz")
				os.Setenv("L2_RPC_URL", "https://l2rpc.a1.taiko.xyz")
				os.Setenv("L1_BRIDGE_ADDRESS", dummyAddress)
				os.Setenv("L2_BRIDGE_ADDRESS", dummyAddress)
				os.Setenv("L1_TAIKO_ADDRESS", dummyAddress)
				os.Setenv("L2_TAIKO_ADDRESS", dummyAddress)
				os.Setenv("RELAYER_ECDSA_KEY", dummyEcdsaKey)

				return func() {
					os.Setenv("L1_RPC_URL", "")
					os.Setenv("L2_RPC_URL", "")
					os.Setenv("L1_BRIDGE_ADDRESS", "")
					os.Setenv("L2_BRIDGE_ADDRESS", "")
					os.Setenv("L1_TAIKO_ADDRESS", "")
					os.Setenv("L2_TAIKO_ADDRESS", "")
					os.Setenv("RELAYER_ECDSA_KEY", "")
				}
			},
			2,
			nil,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			reset := tt.envFunc()
			if reset != nil {
				defer reset()
			}

			indexers, cancel, err := makeIndexers(tt.layer, tt.dbFunc(t), relayer.ProfitableOnly(true))
			if cancel != nil {
				defer cancel()
			}

			if tt.wantErr != nil {
				assert.EqualError(t, tt.wantErr, err.Error())
			} else {
				assert.Nil(t, err)
				assert.Equal(t, tt.wantIndexers, len(indexers))
			}
		})
	}
}

func Test_newHTTPServer(t *testing.T) {
	db, cancel, err := testMysql(t)
	if err != nil {
		t.Fatal(err)
	}

	defer cancel()

	srv, err := newHTTPServer(db, &mock.EthClient{}, &mock.EthClient{})
	assert.Nil(t, err)
	assert.NotNil(t, srv)
}

func Test_newHTTPServer_nilDB(t *testing.T) {
	_, err := newHTTPServer(nil, &mock.EthClient{}, &mock.EthClient{})
	assert.NotNil(t, err)
}
