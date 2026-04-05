//! `WhitelistApi` implementation for the API service.

use super::*;

#[async_trait]
impl<P> WhitelistApi for WhitelistApiService<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Build, sign, publish, and return a preconfirmation block.
    async fn build_preconf_block(
        &self,
        request: BuildPreconfBlockRequest,
    ) -> Result<BuildPreconfBlockResponse> {
        let _guard = self.build_preconf_lock.lock().await;
        self.build_service.build_and_publish(request).await
    }

    /// Return runtime status for the whitelist preconfirmation driver.
    async fn get_status(&self) -> Result<WhitelistStatus> {
        self.get_status_snapshot().await
    }

    /// Subscribe to end-of-sequencing websocket notifications.
    fn subscribe_end_of_sequencing(&self) -> broadcast::Receiver<EndOfSequencingNotification> {
        self.subscribe_end_of_sequencing_notifications()
    }
}
