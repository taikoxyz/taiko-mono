use thiserror::Error;

#[derive(Debug, Error)]
pub enum BlobIndexerError {
    #[error("configuration error: {0}")]
    Configuration(String),
    #[error("database error: {0}")]
    Database(#[from] sqlx::Error),
    #[error("migration error: {0}")]
    Migration(#[from] sqlx::migrate::MigrateError),
    #[error("http client error: {0}")]
    HttpClient(#[from] reqwest::Error),
    #[error("serde error: {0}")]
    Serde(#[from] serde_json::Error),
    #[error("time error: {0}")]
    Time(#[from] chrono::ParseError),
    #[error("invalid data: {0}")]
    InvalidData(String),
    #[error("task join error: {0}")]
    Join(#[from] tokio::task::JoinError),
    #[error("io error: {0}")]
    Io(#[from] std::io::Error),
}

pub type Result<T> = std::result::Result<T, BlobIndexerError>;
