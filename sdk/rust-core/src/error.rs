#[derive(Debug, thiserror::Error, uniffi::Error)]
pub enum TraceletError {
    #[error("Database error: {0}")]
    Database(String),
    #[error("Network error: {0}")]
    Network(String),
    #[error("Configuration error: {0}")]
    Config(String),
}
