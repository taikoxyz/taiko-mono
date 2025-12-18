use tracing_subscriber::{EnvFilter, fmt, layer::SubscriberExt};
use tracing_subscriber::{filter::Directive, util::SubscriberInitExt};

use crate::{
    config::{Config, LogFormat},
    errors::Result,
};

pub fn init_tracing(config: &Config) -> Result<()> {
    if tracing::dispatcher::has_been_set() {
        return Ok(());
    }

    let mut env_filter =
        EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("info"));

    // Silence verbose SQLx instrumentation unless explicitly overridden via RUST_LOG.
    let rust_log_overrides_sqlx = std::env::var("RUST_LOG")
        .ok()
        .map(|value| {
            value
                .split(',')
                .any(|part| part.trim().starts_with("sqlx="))
        })
        .unwrap_or(false);

    if !rust_log_overrides_sqlx && let Ok(directive) = "sqlx=warn".parse::<Directive>() {
        env_filter = env_filter.add_directive(directive);
    }

    match config.log_format {
        LogFormat::Pretty => {
            tracing_subscriber::registry()
                .with(env_filter)
                .with(fmt::layer().with_writer(std::io::stdout))
                .init();
        }
        LogFormat::Json => {
            tracing_subscriber::registry()
                .with(env_filter)
                .with(fmt::layer().json().with_writer(std::io::stdout))
                .init();
        }
    }

    Ok(())
}
