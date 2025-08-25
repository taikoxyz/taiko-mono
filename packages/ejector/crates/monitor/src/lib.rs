use alloy::{
    primitives::Address,
    providers::{Provider, ProviderBuilder, WsConnect},
    transports::http::reqwest::Url,
};
use eyre::Result;
use futures_util::StreamExt;
use std::{
    sync::Arc,
    time::{Duration, Instant},
};
use tokio::{
    sync::Mutex,
    time::{interval, sleep},
};
use tracing::{debug, error, info, warn};

use ::beacon::BeaconClient;
use ::bindings::TaikoWrapper;
use ::utils::{
    eject::eject_operator,
    lookahead::{Responsibility, responsibility_for_slot},
};

pub struct Monitor {
    beacon_client: BeaconClient,
    l1_signer: alloy::signers::local::PrivateKeySigner,
    l2_ws_url: Url,
    l1_http_url: Url,
    target_block_time: Duration,
    eject_after: Duration,
    taiko_wrapper_address: Address,
    whitelist_address: Address,
    handover_slots: u64,
    min_operators: u64,
}

impl Monitor {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        beacon_client: BeaconClient,
        l1_signer: alloy::signers::local::PrivateKeySigner,
        l2_ws_url: Url,
        l1_http_url: Url,
        target_block_time_secs: u64,
        eject_after_n_slots_missed: u64,
        taiko_wrapper_address: Address,
        whitelist_address: Address,
        handover_slots: u64,
        min_operators: u64,
    ) -> Self {
        let target_block_time = Duration::from_secs(target_block_time_secs);
        let eject_after = target_block_time * eject_after_n_slots_missed as u32;

        Self {
            beacon_client,
            l1_signer,
            l2_ws_url,
            l1_http_url,
            target_block_time,
            eject_after,
            taiko_wrapper_address,
            whitelist_address,
            handover_slots,
            min_operators,
        }
    }

    // run starts a loop to watch for new blocks and run a callback on eject time reached.
    // it will update per epoch and handle reconnections, as well as check if preconfs are enabled
    // before starting the ejector. It will however monitor the block stream regardless.
    pub async fn run(&self) -> Result<()> {
        info!("Running block watcher at {}", self.l2_ws_url);

        let last_seen = Arc::new(Mutex::new(Instant::now()));
        let tick = self.target_block_time;
        let max = self.eject_after;
        let last_seen_for_watch = last_seen.clone();

        let l1_http_url = self.l1_http_url.clone();
        let taiko_wrapper_address = self.taiko_wrapper_address;
        let whitelist_address = self.whitelist_address;
        let signer = self.l1_signer.clone();

        let slots_per_epoch = self.beacon_client.slots_per_epoch;
        let handover_slots = self.handover_slots;

        // get current operator responsibility
        let mut prev_resp = self.responsibility_now();

        let beacon_client = self.beacon_client.clone();

        // we only eject if we have at least min_operators in the whitelist.
        // that way in case of an error with the ejector we don't eject down to 0 operators.
        let min_operators = self.min_operators;

        // watchdog task
        let _watchdog = tokio::spawn(async move {
            let mut ticker = interval(tick);
            loop {
                ticker.tick().await;

                // log out epoch and slots
                let curr_epoch = beacon_client.current_epoch();
                let curr_slot = beacon_client.current_slot();
                let slot_in_epoch = beacon_client.slot_in_epoch();
                let curr_resp = responsibility_for_slot(curr_slot, slots_per_epoch, handover_slots);

                info!(
                    "Current epoch: {}, slot: {}, slot in epoch {}, responsibility {:?}",
                    curr_epoch, curr_slot, slot_in_epoch, curr_resp
                );

                if curr_resp != prev_resp {
                    *last_seen_for_watch.lock().await = Instant::now();
                    tracing::info!(
                        "Preconf responsibility changed to {:?} (epoch {}). Reset timer.",
                        curr_resp.lookahead,
                        curr_resp.epoch
                    );
                    prev_resp = curr_resp;
                }

                match are_preconfs_enabled(&l1_http_url, taiko_wrapper_address).await {
                    Ok(false) => {
                        // zero out the last seen
                        *last_seen_for_watch.lock().await = Instant::now();
                        debug!("Preconfs are disabled, skipping block watch and resetting timer");
                        continue;
                    }
                    Err(e) => {
                        // should rarely happen, l1 rpc error only
                        warn!("preconfs check error: {e:?}; skipping eject this tick");
                        // don't reset timer; just skip the eject decision below
                        continue;
                    }
                    Ok(true) => {}
                }

                let elapsed = last_seen_for_watch.lock().await.elapsed();
                if elapsed >= max {
                    warn!("Max time reached without new blocks: {:?}", elapsed);

                    if let Err(e) = eject_operator(
                        l1_http_url.clone(),
                        signer.clone(),
                        whitelist_address,
                        curr_resp.lookahead,
                        min_operators,
                    )
                    .await
                    {
                        error!("Error during eject action: {:?}", e);
                    }
                    *last_seen_for_watch.lock().await = Instant::now();
                }
            }
        });

        // reconnect loop backoff params
        let mut backoff = Duration::from_secs(1);
        let max_backoff = Duration::from_secs(30);

        loop {
            info!("Connecting to block stream...");
            match ProviderBuilder::new().connect_ws(WsConnect::new(self.l2_ws_url.clone())).await {
                Ok(provider) => {
                    info!("Connected to block stream at {}", self.l2_ws_url);
                    metrics::inc_ws_reconnections();
                    // sanity
                    match provider.get_block_number().await {
                        Ok(bn) => info!("WS get_block_number() = {bn}"),
                        Err(e) => warn!("WS RPC get_block_number failed: {e}"),
                    }

                    match provider.subscribe_blocks().await {
                        Ok(sub) => {
                            let mut stream = sub.into_stream();
                            info!("Subscribed to block stream at {}", self.l2_ws_url);

                            loop {
                                match stream.next().await {
                                    Some(header) => {
                                        // number/hash are often Option<_> → use {:?}
                                        info!(
                                            "New block header: number={:?} hash={:?}, coinbase={:?}",
                                            header.number, header.hash, header.beneficiary
                                        );

                                        metrics::inc_l2_blocks();
                                        *last_seen.lock().await = Instant::now();
                                        backoff = Duration::from_secs(1); // reset after good event
                                    }
                                    None => {
                                        warn!("Block stream ended unexpectedly, reconnecting...");
                                        break; // exit inner loop to reconnect
                                    }
                                }
                            }
                        }
                        Err(e) => {
                            warn!("Failed to subscribe to block stream: {e}, will reconnect...");
                        }
                    }
                }
                Err(e) => {
                    warn!("Failed to connect to block stream: {e}. Retrying in {:?}...", backoff);
                }
            }

            warn!("Reconnecting after {:?}", backoff);
            sleep(backoff).await;
            if backoff < max_backoff {
                backoff = std::cmp::min(max_backoff, backoff * 2);
            }
        }
    }

    fn responsibility_now(&self) -> Responsibility {
        let slot = self.beacon_client.current_slot();
        responsibility_for_slot(slot, self.beacon_client.slots_per_epoch, self.handover_slots)
    }
}

pub async fn are_preconfs_enabled(
    l1_http_url: &Url,
    taiko_wrapper_address: Address,
) -> Result<bool> {
    let provider = ProviderBuilder::new().connect_http(l1_http_url.clone());

    let taiko_wrapper = TaikoWrapper::new(taiko_wrapper_address, provider);

    let preconf_router = taiko_wrapper.preconfRouter().call().await?;

    Ok(!preconf_router.is_zero())
}
