//! Common CLI flags shared across commands.

use std::path::PathBuf;

use clap::Parser;
use tracing::Level;
use url::Url;

#[derive(Parser, Clone, Debug, PartialEq, Eq)]
/// CLI flags shared by the node subcommands.
pub struct CommonArgs {
    /// HTTP(S) JSON-RPC endpoint of the operator's own L1 node.
    ///
    /// HTTP only: alloy's WebSocket client gives up after a few reconnect attempts, after which
    /// every L1 read fails until the process restarts, while an HTTP client recovers as soon as
    /// the node answers again.
    #[clap(
        long = "l1.http",
        env = "L1_HTTP",
        required = true,
        value_parser = http_url,
        help = "HTTP(S) JSON-RPC endpoint of the operator's own L1 node (WebSocket is not \
                supported: its client stops reconnecting after a longer L1 outage)"
    )]
    pub l1_http_endpoint: Url,
    /// JSON-RPC endpoint of alethia-reth (`http` or `https`).
    #[clap(
        long = "l2.http",
        env = "L2_HTTP",
        required = true,
        help = "JSON-RPC endpoint of alethia-reth (http or https)"
    )]
    pub l2_http_endpoint: Url,
    /// JWT-authenticated Engine API endpoint of alethia-reth; plain `http` only, as the JWT
    /// client speaks no TLS.
    #[clap(
        long = "l2.auth",
        env = "L2_AUTH",
        required = true,
        help = "JWT-authenticated Engine API endpoint of alethia-reth (plain http only)"
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

/// Parses `value` as a URL with the `http` or `https` scheme.
pub fn http_url(value: &str) -> Result<Url, String> {
    let url = Url::parse(value).map_err(|e| e.to_string())?;
    match url.scheme() {
        "http" | "https" => Ok(url),
        scheme => Err(format!("unsupported URL scheme `{scheme}` (want http or https)")),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::flags::test_env::{ENV_LOCK, EnvGuard};

    fn clear_l1_env() -> [EnvGuard; 2] {
        [EnvGuard::unset("L1_HTTP"), EnvGuard::unset("L1_WS")]
    }

    fn required_args() -> [&'static str; 7] {
        [
            "common",
            "--l2.http",
            "http://localhost:28545",
            "--l2.auth",
            "http://localhost:28551",
            "--jwt.secret",
            "/tmp/jwt.hex",
        ]
    }

    /// `required_args()` followed by `extra`.
    fn argv(extra: &[&'static str]) -> Vec<&'static str> {
        let mut argv = required_args().to_vec();
        argv.extend_from_slice(extra);
        argv
    }

    #[test]
    fn accepts_http_and_https_l1_endpoints() {
        let _lock = ENV_LOCK.lock().expect("env lock poisoned");
        let _clear = clear_l1_env();
        for url in ["http://localhost:8545", "https://l1.example:443/rpc"] {
            let args = CommonArgs::try_parse_from(argv(&["--l1.http", url]))
                .expect("http(s) endpoint should parse");

            assert_eq!(args.l1_http_endpoint, Url::parse(url).unwrap());
        }
    }

    #[test]
    fn requires_an_http_l1_endpoint() {
        let _lock = ENV_LOCK.lock().expect("env lock poisoned");
        let _clear = clear_l1_env();
        let err = CommonArgs::try_parse_from(argv(&[])).expect_err("--l1.http is required");
        assert_eq!(err.kind(), clap::error::ErrorKind::MissingRequiredArgument);
        assert!(err.to_string().contains("--l1.http"), "{err}");

        // A WebSocket endpoint is refused however it is given.
        let err = CommonArgs::try_parse_from(argv(&["--l1.ws", "ws://localhost:8546"]))
            .expect_err("--l1.ws is gone");
        assert_eq!(err.kind(), clap::error::ErrorKind::UnknownArgument, "{err}");
        for url in ["ws://localhost:8546", "wss://l1.example/ws"] {
            let err = CommonArgs::try_parse_from(argv(&["--l1.http", url]))
                .expect_err("a WebSocket URL is not an HTTP endpoint");
            assert_eq!(err.kind(), clap::error::ErrorKind::ValueValidation, "{url}: {err}");
            assert!(err.to_string().contains("want http or https"), "{err}");
        }
    }

    #[test]
    fn l1_ws_env_does_not_stand_in_for_l1_http() {
        let _lock = ENV_LOCK.lock().expect("env lock poisoned");
        let _clear = clear_l1_env();
        let _ws = EnvGuard::set("L1_WS", "ws://localhost:8546");
        let err = CommonArgs::try_parse_from(argv(&[])).expect_err("L1_WS is not read");
        assert_eq!(err.kind(), clap::error::ErrorKind::MissingRequiredArgument);

        let _http = EnvGuard::set("L1_HTTP", "http://localhost:8545");
        let args = CommonArgs::try_parse_from(argv(&[])).expect("L1_HTTP is read");
        assert_eq!(args.l1_http_endpoint.as_str(), "http://localhost:8545/");
    }

    /// The client reads no fork times (the app follows the activation record on L1, and
    /// alethia-reth owns its fork schedule), so the old devnet fork-time flags are gone and
    /// passing one fails startup instead of being silently ignored.
    #[test]
    fn rejects_removed_devnet_fork_time_flags() {
        let _lock = ENV_LOCK.lock().expect("env lock poisoned");
        let _clear = clear_l1_env();
        for flag in ["--devnet-unzen-timestamp", "--devnet-etna-timestamp"] {
            let err = CommonArgs::try_parse_from(argv(&["--l1.http", "http://l1:8545", flag, "5"]))
                .expect_err("removed flag must be rejected");

            assert_eq!(err.kind(), clap::error::ErrorKind::UnknownArgument, "{flag}");
        }
    }
}
