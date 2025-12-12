use crate::error::Result;

/// Placeholder for bootstrap catch-up orchestration.
pub struct Catchup;

impl Catchup {
    pub async fn run(&self) -> Result<()> {
        Ok(())
    }
}

