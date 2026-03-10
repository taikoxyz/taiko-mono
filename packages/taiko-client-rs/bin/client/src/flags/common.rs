//! Common CLI flags shared across commands.

use std::path::PathBuf;

use alloy_primitives::Address;
use clap::{Parser, ValueEnum};
use rpc::SubscriptionSource;
use tracing::Level;
use url::Url;

use crate::error::{CliError, Result};

/// Supported L1 transport selectors for the CLI.
#[derive(Copy, Clone, Debug, PartialEq, Eq, ValueEnum)]
pub enum L1Transport {
    /// Use the HTTP L1 endpoint.
    Http,
    /// Use the WebSocket L1 endpoint.
    Ws,
}

#[derive(Parser, Clone, Debug, PartialEq, Eq)]
/// CLI flags shared by proposer and driver-style subcommands.
pub struct CommonArgs {
    /// HTTP RPC endpoint of a L1 ethereum node.
    #[clap(long = "l1.http", env = "L1_HTTP", help = "HTTP RPC endpoint of a L1 ethereum node")]
    pub l1_http_endpoint: Option<Url>,
    /// WebSocket RPC endpoint of a L1 ethereum node.
    #[clap(long = "l1.ws", env = "L1_WS", help = "WebSocket RPC endpoint of a L1 ethereum node")]
    pub l1_ws_endpoint: Option<Url>,
    /// Transport selector for the L1 endpoint when multiple transports are configured.
    #[clap(
        long = "l1.transport",
        env = "L1_TRANSPORT",
        value_enum,
        help = "Select which L1 transport to use when multiple endpoints are configured"
    )]
    pub l1_transport: Option<L1Transport>,
    /// HTTP RPC endpoint of a L2 taiko execution engine.
    #[clap(
        long = "l2.http",
        env = "L2_HTTP",
        required = true,
        help = "HTTP RPC endpoint of a L2 taiko execution engine"
    )]
    pub l2_http_endpoint: Url,
    /// Authenticated HTTP RPC endpoint of a L2 taiko execution engine.
    #[clap(
        long = "l2.auth",
        env = "L2_AUTH",
        required = true,
        help = "Authenticated HTTP RPC endpoint of a L2 taiko-geth execution engine"
    )]
    pub l2_auth_endpoint: Url,
    /// Path to a JWT secret to use for authenticated RPC endpoints.
    #[clap(
        long = "jwt.secret",
        env = "JWT_SECRET",
        required = true,
        help = "Path to a JWT secret to use for authenticated RPC endpoints"
    )]
    pub l2_auth_jwt_secret: PathBuf,
    /// Taiko Shasta protocol Inbox contract address.
    #[clap(
        long = "shasta.inbox",
        env = "SHASTA_INBOX",
        required = true,
        help = "Taiko Shasta protocol Inbox contract address"
    )]
    pub shasta_inbox_address: Address,
    /// Verbosity level for logging.
    #[clap(
        short = 'v',
        long = "verbosity",
        env = "VERBOSITY",
        default_value = "2",
        help = "Set the minimum log level. 0 = error, 1 = warn, 2 = info, 3 = debug, 4 = trace"
    )]
    pub verbosity: u8,
    /// Enable Prometheus metrics server.
    #[clap(
        long = "metrics.enabled",
        env = "METRICS_ENABLED",
        default_value = "false",
        help = "Enable Prometheus metrics server"
    )]
    pub metrics_enabled: bool,
    /// Port for Prometheus metrics server.
    #[clap(
        long = "metrics.port",
        env = "METRICS_PORT",
        default_value = "9090",
        help = "Port for Prometheus metrics server"
    )]
    pub metrics_port: u16,
    /// Address to bind Prometheus metrics server.
    #[clap(
        long = "metrics.addr",
        env = "METRICS_ADDR",
        default_value = "0.0.0.0",
        help = "Address to bind Prometheus metrics server"
    )]
    pub metrics_addr: String,
}

impl CommonArgs {
    /// Resolve the configured L1 provider source.
    ///
    /// If both HTTP and WebSocket endpoints are configured, an explicit `l1.transport`
    /// selector is required.
    pub fn l1_provider_source(&self) -> Result<SubscriptionSource> {
        match (self.l1_transport, &self.l1_http_endpoint, &self.l1_ws_endpoint) {
            (Some(L1Transport::Http), Some(url), _) => Ok(SubscriptionSource::Http(url.clone())),
            (Some(L1Transport::Http), None, _) => Err(CliError::MissingSelectedL1Endpoint {
                transport: "http",
                flag: "--l1.http",
                env_var: "L1_HTTP",
            }),
            (Some(L1Transport::Ws), _, Some(url)) => Ok(SubscriptionSource::Ws(url.clone())),
            (Some(L1Transport::Ws), _, None) => Err(CliError::MissingSelectedL1Endpoint {
                transport: "ws",
                flag: "--l1.ws",
                env_var: "L1_WS",
            }),
            (None, Some(url), None) => Ok(SubscriptionSource::Http(url.clone())),
            (None, None, Some(url)) => Ok(SubscriptionSource::Ws(url.clone())),
            _ => Err(CliError::InvalidL1EndpointConfig),
        }
    }

    /// Convert verbosity level to tracing::Level
    pub fn log_level(&self) -> Level {
        match self.verbosity {
            0 => Level::ERROR,
            1 => Level::WARN,
            2 => Level::INFO,
            3 => Level::DEBUG,
            _ => Level::TRACE,
        }
    }
}

#[cfg(test)]
mod tests {
    use std::{env, sync::Mutex};

    use super::*;

    static ENV_LOCK: Mutex<()> = Mutex::new(());

    struct EnvGuard {
        key: &'static str,
        previous: Option<String>,
    }

    impl EnvGuard {
        fn set(key: &'static str, value: &str) -> Self {
            let previous = env::var(key).ok();
            // SAFETY: ENV_LOCK serializes these test-only process-environment mutations.
            unsafe { env::set_var(key, value) };
            Self { key, previous }
        }

        fn unset(key: &'static str) -> Self {
            let previous = env::var(key).ok();
            // SAFETY: ENV_LOCK serializes these test-only process-environment mutations.
            unsafe { env::remove_var(key) };
            Self { key, previous }
        }
    }

    impl Drop for EnvGuard {
        fn drop(&mut self) {
            // SAFETY: ENV_LOCK serializes these test-only process-environment mutations.
            unsafe {
                match &self.previous {
                    Some(value) => env::set_var(self.key, value),
                    None => env::remove_var(self.key),
                }
            }
        }
    }

    fn clear_l1_env() -> [EnvGuard; 3] {
        [EnvGuard::unset("L1_HTTP"), EnvGuard::unset("L1_WS"), EnvGuard::unset("L1_TRANSPORT")]
    }

    fn required_args() -> [&'static str; 9] {
        [
            "common",
            "--l2.http",
            "http://localhost:28545",
            "--l2.auth",
            "http://localhost:28551",
            "--jwt.secret",
            "/tmp/jwt.hex",
            "--shasta.inbox",
            "0x0000000000000000000000000000000000000000",
        ]
    }

    #[test]
    fn accepts_http_l1_endpoint() {
        let _lock = ENV_LOCK.lock().expect("env lock poisoned");
        let _clear = clear_l1_env();
        let args = CommonArgs::try_parse_from([
            required_args()[0],
            "--l1.http",
            "http://localhost:8545",
            required_args()[1],
            required_args()[2],
            required_args()[3],
            required_args()[4],
            required_args()[5],
            required_args()[6],
            required_args()[7],
            required_args()[8],
        ])
        .expect("http endpoint should parse");

        assert!(matches!(args.l1_provider_source().unwrap(), SubscriptionSource::Http(_)));
    }

    #[test]
    fn accepts_ws_l1_endpoint() {
        let _lock = ENV_LOCK.lock().expect("env lock poisoned");
        let _clear = clear_l1_env();
        let args = CommonArgs::try_parse_from([
            required_args()[0],
            "--l1.ws",
            "ws://localhost:8546",
            required_args()[1],
            required_args()[2],
            required_args()[3],
            required_args()[4],
            required_args()[5],
            required_args()[6],
            required_args()[7],
            required_args()[8],
        ])
        .expect("ws endpoint should parse");

        assert!(matches!(args.l1_provider_source().unwrap(), SubscriptionSource::Ws(_)));
    }

    #[test]
    fn accepts_both_l1_transports_with_selector() {
        let _lock = ENV_LOCK.lock().expect("env lock poisoned");
        let _clear = clear_l1_env();
        let args = CommonArgs::try_parse_from([
            required_args()[0],
            "--l1.transport",
            "http",
            "--l1.http",
            "http://localhost:8545",
            "--l1.ws",
            "ws://localhost:8546",
            required_args()[1],
            required_args()[2],
            required_args()[3],
            required_args()[4],
            required_args()[5],
            required_args()[6],
            required_args()[7],
            required_args()[8],
        ])
        .expect("selector should disambiguate dual L1 endpoints");

        assert!(matches!(args.l1_provider_source().unwrap(), SubscriptionSource::Http(_)));
    }

    #[test]
    fn rejects_selected_http_transport_without_http_endpoint() {
        let _lock = ENV_LOCK.lock().expect("env lock poisoned");
        let _clear = clear_l1_env();
        let args = CommonArgs::try_parse_from([
            required_args()[0],
            "--l1.transport",
            "http",
            "--l1.ws",
            "ws://localhost:8546",
            required_args()[1],
            required_args()[2],
            required_args()[3],
            required_args()[4],
            required_args()[5],
            required_args()[6],
            required_args()[7],
            required_args()[8],
        ])
        .expect("selector mismatch should parse before validation");

        assert!(matches!(
            args.l1_provider_source(),
            Err(CliError::MissingSelectedL1Endpoint { transport: "http", .. })
        ));
    }

    #[test]
    fn rejects_programmatic_invalid_l1_transport_state() {
        let args = CommonArgs {
            l1_http_endpoint: None,
            l1_ws_endpoint: None,
            l1_transport: None,
            l2_http_endpoint: Url::parse("http://localhost:28545").unwrap(),
            l2_auth_endpoint: Url::parse("http://localhost:28551").unwrap(),
            l2_auth_jwt_secret: "/tmp/jwt.hex".into(),
            shasta_inbox_address: "0x0000000000000000000000000000000000000000".parse().unwrap(),
            verbosity: 2,
            metrics_enabled: false,
            metrics_port: 9090,
            metrics_addr: "0.0.0.0".to_string(),
        };

        assert!(matches!(args.l1_provider_source(), Err(CliError::InvalidL1EndpointConfig)));
    }

    #[test]
    fn rejects_both_l1_transports_without_selector() {
        let _lock = ENV_LOCK.lock().expect("env lock poisoned");
        let _clear = clear_l1_env();
        let args = CommonArgs::try_parse_from([
            required_args()[0],
            "--l1.http",
            "http://localhost:8545",
            "--l1.ws",
            "ws://localhost:8546",
            required_args()[1],
            required_args()[2],
            required_args()[3],
            required_args()[4],
            required_args()[5],
            required_args()[6],
            required_args()[7],
            required_args()[8],
        ])
        .expect("dual endpoints should parse before selection");

        assert!(matches!(args.l1_provider_source(), Err(CliError::InvalidL1EndpointConfig)));
    }

    #[test]
    fn accepts_dual_l1_env_endpoints_with_transport_selector() {
        let _lock = ENV_LOCK.lock().expect("env lock poisoned");
        let _http = EnvGuard::set("L1_HTTP", "http://localhost:8545");
        let _ws = EnvGuard::set("L1_WS", "ws://localhost:8546");
        let _transport = EnvGuard::set("L1_TRANSPORT", "ws");

        let args = CommonArgs::try_parse_from(required_args()).expect("env-backed L1 config");

        assert!(matches!(args.l1_provider_source().unwrap(), SubscriptionSource::Ws(_)));
    }

    #[test]
    fn rejects_dual_l1_env_endpoints_without_transport_selector() {
        let _lock = ENV_LOCK.lock().expect("env lock poisoned");
        let _http = EnvGuard::set("L1_HTTP", "http://localhost:8545");
        let _ws = EnvGuard::set("L1_WS", "ws://localhost:8546");
        let _transport = EnvGuard::unset("L1_TRANSPORT");

        let args = CommonArgs::try_parse_from(required_args()).expect("env-backed L1 config");

        assert!(matches!(args.l1_provider_source(), Err(CliError::InvalidL1EndpointConfig)));
    }
}
